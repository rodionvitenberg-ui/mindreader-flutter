import json
import os
import time
from urllib.parse import urlsplit, urlunsplit

import httpx
from django.conf import settings


class UpstreamError(Exception):
    def __init__(self, code, *, safe_retry=False):
        super().__init__(code)
        self.code = code
        self.safe_retry = safe_retry


def endpoint_allowed(url, capability):
    try:
        parts = urlsplit(url)
        _ = parts.port
    except ValueError:
        return False
    allowed = {
        host.strip().lower()
        for name in ("AI_ALLOWED_HOSTS", f"AI_{capability.upper()}_ALLOWED_HOSTS")
        for host in os.getenv(name, "").split(",") if host.strip()
    }
    schemes = {"https"} if settings.PRODUCTION else {"https", "http"}
    return (
        parts.scheme in schemes and parts.hostname in allowed
        and parts.username is None and parts.password is None
        and not parts.query and not parts.fragment
    )


def credentials(provider):
    if not provider.credential_ref:
        return {}
    if not provider.credential_ref.startswith("AI_CREDENTIAL_"):
        raise UpstreamError("provider_unavailable")
    value = os.getenv(provider.credential_ref)
    if not value or not value.isascii() or any(ord(c) < 33 or ord(c) == 127 for c in value):
        raise UpstreamError("provider_unavailable")
    return {"Authorization": f"Bearer {value}"}


def request_json(provider, payload=None, *, health=False):
    if not endpoint_allowed(provider.endpoint, provider.capability):
        raise UpstreamError("provider_unavailable")
    url = provider.endpoint
    if health:
        base = urlsplit(url)
        url = urlunsplit((base.scheme, base.netloc, provider.health_path, "", ""))

    timeout = httpx.Timeout(min(provider.inference_timeout, 2.0), connect=provider.connect_timeout)
    deadline = time.monotonic() + provider.connect_timeout + provider.inference_timeout
    headers = credentials(provider)
    try:
        with httpx.Client(timeout=timeout, follow_redirects=False, trust_env=False) as client:
            with client.stream("GET" if health else "POST", url, headers=headers, json=payload) as response:
                if response.status_code in (401, 403, 404):
                    raise UpstreamError("provider_unavailable")
                if response.status_code == 429:
                    raise UpstreamError("provider_busy")
                if not 200 <= response.status_code < 300:
                    raise UpstreamError("provider_error")
                if health:
                    return None
                data = bytearray()
                for chunk in response.iter_bytes(chunk_size=16384):
                    if time.monotonic() >= deadline:
                        raise UpstreamError("provider_timeout")
                    data.extend(chunk)
                    if len(data) > 1024 * 1024:
                        raise UpstreamError("provider_invalid_response")
                return json.loads(data)
    except (httpx.ConnectError, httpx.ConnectTimeout):
        raise UpstreamError("provider_unavailable", safe_retry=True) from None
    except httpx.TimeoutException:
        raise UpstreamError("provider_timeout") from None
    except httpx.HTTPError:
        raise UpstreamError("provider_error") from None
    except (ValueError, UnicodeError, RecursionError):
        raise UpstreamError("provider_invalid_response") from None
