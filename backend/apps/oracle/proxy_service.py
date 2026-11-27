"""Server-side Oracle LLM completion and language-independent Cloud STT proxy.

Keeps every AI/STT API key strictly on the server so the Flutter Web PWA bundle
never ships credentials. Routes Oracle text through `ai_gateway` when an enabled
Oracle Provider exists in the database, falling back to `settings.ORACLE_LLM_*`.
"""

from __future__ import annotations

import base64
import json
import re
import shutil
import subprocess
import urllib.error
import urllib.request
import uuid

from django.conf import settings

from apps.ai_gateway.models import Capability, Provider
from apps.ai_gateway.routing import generate as gateway_generate
from apps.core.api import Problem

DEFAULT_ORACLE_PERSONA = (
    "You are the Tarot Tree oracle: calm, restrained, contextual and symbolic. "
    "You speak in grounded psychological language — reflective insight, never "
    "fortune-teller kitsch, never mysticism, never hard predictions. You NEVER "
    "give categorical medical, financial or legal predictions or advice. When an "
    "answer will be spoken aloud, keep it shorter than a written answer — concise "
    "enough to be read in one breath."
)

TRANSCRIPTION_PROMPT = (
    "Transcribe the spoken audio accurately with automatic language detection. "
    "The speaker may speak Russian, English, another language, or switch between "
    "languages mid-sentence. Always write each phrase in its original spoken "
    "language and native script (never translate and never transliterate Cyrillic "
    "into Latin). Add natural capitalization, commas, periods, dashes, and "
    "question marks. Gently remove meaningless hesitation fillers (such as \"um\", "
    "\"uh\", \"эээ\", \"эм\") while preserving the speaker's exact meaning and "
    "authentic phrasing. Output ONLY the clean transcribed text with no quotes, "
    "labels, or commentary. If the audio contains only silence or background noise "
    "with no intelligible speech, return an empty string."
)

_WHITESPACE_RE = re.compile(r"\s+")


def sanitize_transcript(raw: str) -> str:
    text = (raw or "").strip()
    if text.startswith("```") and text.endswith("```") and len(text) >= 6:
        text = text[3:-3].strip()
    if len(text) >= 2 and (
        (text.startswith('"') and text.endswith('"'))
        or (text.startswith("«") and text.endswith("»"))
    ):
        text = text[1:-1].strip()
    return _WHITESPACE_RE.sub(" ", text).strip()


def _http_post_json(url: str, headers: dict[str, str], payload: dict, *, timeout: float) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "TarotTree-Backend/1.0",
            **headers,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise Problem("provider_quota_exhausted", 429, "AI provider rate limit reached.") from None
        if exc.code in {401, 403}:
            raise Problem("provider_auth_error", 502, "AI provider rejected credentials.") from None
        raise Problem("provider_error", 502, f"AI provider error (HTTP {exc.code}).") from None
    except (OSError, ValueError) as exc:
        raise Problem("provider_timeout", 504, "AI provider could not be reached in time.") from exc


def complete_oracle_prompt(
    *,
    prompt: str,
    system_prompt: str | None = None,
    temperature: float = 0.7,
    max_tokens: int = 1600,
) -> tuple[str, str]:
    """Completes a single Oracle prompt via ai_gateway or env-configured OpenAI-compat LLM."""
    sys_text = (system_prompt or "").strip() or DEFAULT_ORACLE_PERSONA
    messages = [
        {"role": "system", "content": sys_text},
        {"role": "user", "content": prompt},
    ]

    # Priority 1: Admin-configured AI Gateway provider (supports leases, failover, spending caps).
    if Provider.objects.filter(capability=Capability.ORACLE, enabled=True).exists():
        text, provider_name = gateway_generate(messages)
        return text.replace("```", "").strip(), provider_name

    # Priority 2: Direct env-configured OpenAI-compatible LLM (Gemini Flash / DeepSeek / OpenAI).
    url = (settings.ORACLE_LLM_URL or "").strip()
    api_key = (settings.ORACLE_LLM_API_KEY or "").strip()
    model = (settings.ORACLE_LLM_MODEL or "gemini-2.5-flash").strip()
    if not url or not api_key:
        raise Problem(
            "oracle_unconfigured",
            503,
            "Oracle AI provider is not configured on the server.",
        )

    data = _http_post_json(
        url,
        {"Authorization": f"Bearer {api_key}"},
        {
            "model": model,
            "stream": False,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": messages,
        },
        timeout=settings.ORACLE_LLM_TIMEOUT,
    )
    try:
        content = data["choices"][0]["message"]["content"]
    except (TypeError, IndexError, KeyError):
        raise Problem("provider_invalid_response", 502, "Unexpected response from Oracle AI.") from None
    if not isinstance(content, str) or not content.strip():
        raise Problem("provider_invalid_response", 502, "Empty response from Oracle AI.")
    return content.replace("```", "").strip(), f"env:{model}"


def _encode_multipart(fields: dict[str, str], file_field: str, filename: str, mime_type: str, data: bytes) -> tuple[bytes, str]:
    boundary = f"----TarotTreeSTT{uuid.uuid4().hex}"
    parts: list[bytes] = []
    for k, v in fields.items():
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{k}"\r\n\r\n'
            f"{v}\r\n".encode("utf-8")
        )
    safe_name = re.sub(r'[^A-Za-z0-9._-]', "_", filename or "voice_note.m4a")
    parts.append(
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="{file_field}"; filename="{safe_name}"\r\n'
        f"Content-Type: {mime_type or 'application/octet-stream'}\r\n\r\n".encode("utf-8")
        + data
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def _transcribe_whisper(audio_bytes: bytes, *, mime_type: str, filename: str) -> tuple[str, str]:
    url = (settings.STT_API_URL or "").strip()
    key = (settings.STT_API_KEY or settings.ORACLE_LLM_API_KEY or "").strip()
    model = (settings.STT_API_MODEL or "whisper-large-v3").strip()
    body, content_type = _encode_multipart(
        {
            "model": model,
            "response_format": "json",
            "temperature": "0",
            "prompt": "Punctuate naturally with periods, commas, dashes, and question marks.",
        },
        "file",
        filename,
        mime_type,
        audio_bytes,
    )
    headers = {
        "Content-Type": content_type,
        "Accept": "application/json",
        "User-Agent": "TarotTree-Backend/1.0",
    }
    if key:
        headers["Authorization"] = f"Bearer {key}"
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=settings.STT_TIMEOUT) as resp:
            decoded = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise Problem("provider_quota_exhausted", 429, "STT rate limit reached.") from None
        if exc.code in {401, 403}:
            raise Problem("provider_auth_error", 502, "STT provider rejected credentials.") from None
        raise Problem("provider_error", 502, f"STT provider error (HTTP {exc.code}).") from None
    except (OSError, ValueError) as exc:
        raise Problem("provider_timeout", 504, "STT provider timed out.") from exc

    text = decoded.get("text") if isinstance(decoded, dict) else None
    if not isinstance(text, str):
        raise Problem("provider_invalid_response", 502, "Unexpected STT response shape.")
    return sanitize_transcript(text), f"whisper:{model}"


def _transcribe_gemini_native(audio_bytes: bytes, *, mime_type: str) -> tuple[str, str]:
    api_key = (settings.ORACLE_LLM_API_KEY or "").strip()
    raw_model = (settings.ORACLE_LLM_MODEL or "gemini-2.5-flash").strip()
    model = raw_model[len("models/"):] if raw_model.startswith("models/") else raw_model
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    data = _http_post_json(
        url,
        {"x-goog-api-key": api_key},
        {
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {
                            "inline_data": {
                                "mime_type": mime_type or "audio/mp4",
                                "data": base64.b64encode(audio_bytes).decode("ascii"),
                            }
                        },
                        {"text": TRANSCRIPTION_PROMPT},
                    ],
                }
            ],
            "generationConfig": {"temperature": 0.0, "maxOutputTokens": 1024},
        },
        timeout=settings.STT_TIMEOUT,
    )
    candidates = data.get("candidates") if isinstance(data, dict) else None
    if isinstance(candidates, list) and candidates:
        parts = ((candidates[0] or {}).get("content") or {}).get("parts")
        if isinstance(parts, list):
            joined = "".join(p.get("text", "") for p in parts if isinstance(p, dict) and isinstance(p.get("text"), str))
            return sanitize_transcript(joined), f"gemini:{model}"
    raise Problem("provider_invalid_response", 502, "Unexpected Gemini STT response.")


def _transcribe_openai_audio_chat(audio_bytes: bytes, *, mime_type: str) -> tuple[str, str]:
    url = (settings.ORACLE_LLM_URL or "").strip()
    api_key = (settings.ORACLE_LLM_API_KEY or "").strip()
    model = (settings.ORACLE_LLM_MODEL or "gemini-2.5-flash").strip()
    lower = (mime_type or "").lower()
    fmt = "ogg" if ("ogg" in lower or "opus" in lower) else "wav" if "wav" in lower else "mp4"
    data = _http_post_json(
        url,
        {"Authorization": f"Bearer {api_key}"} if api_key else {},
        {
            "model": model,
            "temperature": 0.0,
            "max_tokens": 1024,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": TRANSCRIPTION_PROMPT},
                        {
                            "type": "input_audio",
                            "input_audio": {
                                "data": base64.b64encode(audio_bytes).decode("ascii"),
                                "format": fmt,
                            },
                        },
                    ],
                }
            ],
        },
        timeout=settings.STT_TIMEOUT,
    )
    try:
        content = data["choices"][0]["message"]["content"]
    except (TypeError, IndexError, KeyError):
        raise Problem("provider_invalid_response", 502, "Unexpected STT response.") from None
    if not isinstance(content, str):
        raise Problem("provider_invalid_response", 502, "Unexpected STT response.")
    return sanitize_transcript(content), f"audio-chat:{model}"


def _is_deepseek_asr_url(url: str) -> bool:
    lower = (url or "").lower()
    return "deepseek.com" in lower and "/tools/asr" in lower


def _maybe_convert_to_wav_for_deepseek(audio_bytes: bytes, mime_type: str, filename: str) -> tuple[bytes, str, str]:
    """DeepSeek ASR accepts WAV (16-bit PCM) or Ogg Opus. Convert AAC/M4A in-memory via ffmpeg if available."""
    lower_mime = (mime_type or "").lower()
    lower_name = (filename or "").lower()
    if any(t in lower_mime for t in ("ogg", "opus", "wav")) or lower_name.endswith((".ogg", ".opus", ".wav")):
        return audio_bytes, mime_type, filename
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return audio_bytes, mime_type, filename
    try:
        proc = subprocess.run(
            [
                ffmpeg, "-hide_banner", "-loglevel", "error",
                "-i", "pipe:0",
                "-ac", "1", "-ar", "16000", "-sample_fmt", "s16",
                "-f", "wav", "pipe:1",
            ],
            input=audio_bytes,
            capture_output=True,
            timeout=10,
            check=True,
        )
        if proc.stdout:
            return proc.stdout, "audio/wav", "voice_note.wav"
    except (subprocess.SubprocessError, OSError):
        pass
    return audio_bytes, mime_type, filename


def _transcribe_deepseek_asr(
    audio_bytes: bytes,
    *,
    mime_type: str,
    filename: str,
    url: str = "https://api.deepseek.com/v1/tools/asr",
) -> tuple[str, str]:
    """DeepSeek native Speech-to-Text (`POST /v1/tools/asr`, multipart `file` only, auto language)."""
    key = (settings.STT_API_KEY or settings.ORACLE_LLM_API_KEY or settings.VISION_VLM_API_KEY or "").strip()
    if not key:
        raise Problem("stt_unconfigured", 503, "DeepSeek API key is not configured for ASR.")
    conv_bytes, conv_mime, conv_name = _maybe_convert_to_wav_for_deepseek(audio_bytes, mime_type, filename)
    body, content_type = _encode_multipart({}, "file", conv_name, conv_mime, conv_bytes)
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": content_type,
            "Accept": "application/json",
            "Authorization": f"Bearer {key}",
            "User-Agent": "TarotTree-Backend/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=settings.STT_TIMEOUT) as resp:
            decoded = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise Problem("provider_quota_exhausted", 429, "STT rate limit reached.") from None
        if exc.code in {401, 403}:
            raise Problem("provider_auth_error", 502, "DeepSeek ASR rejected credentials.") from None
        raise Problem("provider_error", 502, f"DeepSeek ASR error (HTTP {exc.code}).") from None
    except (OSError, ValueError) as exc:
        raise Problem("provider_timeout", 504, "DeepSeek ASR timed out.") from exc

    text = decoded.get("text") if isinstance(decoded, dict) else None
    if not isinstance(text, str):
        raise Problem("provider_invalid_response", 502, "Unexpected DeepSeek ASR response shape.")
    return sanitize_transcript(text), "deepseek:asr"


def transcribe_audio_bytes(
    audio_bytes: bytes,
    *,
    mime_type: str = "audio/mp4",
    filename: str = "voice_note.m4a",
) -> tuple[str, str]:
    """Transcribes audio in-memory with zero disk retention."""
    if not audio_bytes:
        raise Problem("empty_audio", 400, "Audio payload is empty.")
    if len(audio_bytes) > settings.STT_MAX_UPLOAD_BYTES:
        raise Problem("request_too_large", 413, "Audio upload exceeds the maximum size.")

    explicit_stt = (settings.STT_API_URL or "").strip()
    if explicit_stt:
        if _is_deepseek_asr_url(explicit_stt):
            return _transcribe_deepseek_asr(audio_bytes, mime_type=mime_type, filename=filename, url=explicit_stt)
        return _transcribe_whisper(audio_bytes, mime_type=mime_type, filename=filename)

    llm_url = (settings.ORACLE_LLM_URL or "").strip()
    llm_key = (settings.ORACLE_LLM_API_KEY or "").strip()
    if not llm_url or not llm_key:
        raise Problem("stt_unconfigured", 503, "Cloud speech transcription is not configured on the server.")

    if "api.deepseek.com" in llm_url.lower():
        return _transcribe_deepseek_asr(audio_bytes, mime_type=mime_type, filename=filename)
    if "generativelanguage.googleapis.com" in llm_url:
        return _transcribe_gemini_native(audio_bytes, mime_type=mime_type)
    return _transcribe_openai_audio_chat(audio_bytes, mime_type=mime_type)
