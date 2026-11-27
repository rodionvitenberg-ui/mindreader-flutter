"""On-chain Solana Mainnet RPC verification for USDC (SPL) and SOL transfers."""

from __future__ import annotations

import json
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone as dt_timezone

from django.conf import settings

from apps.core.api import Problem

from .models import ProOrder

LAMPORTS_PER_SOL = 1_000_000_000
MICRO_USDC_PER_USD = 1_000_000

_BASE58_SIG = re.compile(r"^[1-9A-HJ-NP-Za-km-z]{64,100}$")
_EXPLORER_TX_URL = re.compile(
    r"https?://(?:www\.)?(?:solscan\.io|explorer\.solana\.com|solana\.fm)/tx/([1-9A-HJ-NP-Za-km-z]{64,100})",
    re.IGNORECASE,
)
_MEMO_TOKEN_RE = re.compile(r"\bTTPRO-[A-Z0-9]{6,24}\b")

_SOL_PRICE_CACHE: tuple[float, float] = (0.0, 0.0)  # (monotonic_ts, usd_price)
_SOL_PRICE_TTL_SECONDS = 60.0


@dataclass(frozen=True)
class VerifiedSolanaTransfer:
    tx_signature: str
    payer_wallet: str
    received_atomic: int
    block_time: datetime | None


def extract_solana_signature(raw: str) -> str:
    """Normalizes a raw base58 signature or extracts it from a Solscan / Explorer URL."""
    cleaned = (raw or "").strip()
    match = _EXPLORER_TX_URL.search(cleaned)
    if match:
        return match.group(1)
    # Strip accidental trailing query/fragment if user pasted partial path.
    cleaned = cleaned.split("?")[0].split("#")[0].rstrip("/")
    if "/" in cleaned:
        tail = cleaned.rsplit("/", 1)[-1]
        if _BASE58_SIG.fullmatch(tail):
            return tail
    return cleaned


def is_valid_solana_signature(signature: str) -> bool:
    return bool(_BASE58_SIG.fullmatch(extract_solana_signature(signature)))


def fetch_sol_usd_price() -> float:
    """Fetches a cached (60s TTL) live SOL/USD spot rate with Kraken fallback."""
    global _SOL_PRICE_CACHE
    now_mono = time.monotonic()
    cached_ts, cached_usd = _SOL_PRICE_CACHE
    if cached_usd > 0 and (now_mono - cached_ts) < _SOL_PRICE_TTL_SECONDS:
        return cached_usd

    sources = (
        (
            "https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd",
            lambda d: float(d["solana"]["usd"]),
        ),
        (
            "https://api.kraken.com/0/public/Ticker?pair=SOLUSD",
            lambda d: float(next(iter(d["result"].values()))["c"][0]),
        ),
    )
    for url, parser in sources:
        try:
            req = urllib.request.Request(
                url,
                headers={"Accept": "application/json", "User-Agent": "TarotTree/1.0"},
            )
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                usd = parser(data)
                if 5.0 <= usd <= 100_000.0:
                    _SOL_PRICE_CACHE = (now_mono, usd)
                    return usd
        except (OSError, ValueError, KeyError, TypeError, StopIteration):
            continue
    return float(settings.SOLANA_FALLBACK_SOL_USD)


def _rpc_get_transaction(signature: str) -> dict | None:
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "getTransaction",
        "params": [
            signature,
            {
                "encoding": "jsonParsed",
                "maxSupportedTransactionVersion": 0,
                "commitment": "confirmed",
            },
        ],
    }).encode("utf-8")
    req = urllib.request.Request(
        settings.SOLANA_RPC_URL,
        data=payload,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except (OSError, ValueError) as exc:
        raise Problem("solana_rpc_unavailable", 503, "Could not reach Solana RPC. Try again shortly.") from exc
    if "error" in body and body["error"]:
        raise Problem("solana_rpc_error", 502, "Solana RPC rejected the transaction query.")
    return body.get("result")


def _extract_account_keys(tx_result: dict) -> list[str]:
    message = (tx_result.get("transaction") or {}).get("message") or {}
    keys = message.get("accountKeys") or []
    out: list[str] = []
    for entry in keys:
        if isinstance(entry, str):
            out.append(entry)
        elif isinstance(entry, dict) and isinstance(entry.get("pubkey"), str):
            out.append(entry["pubkey"])
    # Include Solana v0 Address Lookup Table (ALT) loaded addresses in canonical order.
    loaded = (tx_result.get("meta") or {}).get("loadedAddresses") or {}
    for bucket in ("writable", "readonly"):
        for addr in loaded.get(bucket) or []:
            if isinstance(addr, str):
                out.append(addr)
    return out


def _extract_memo_tokens(tx_result: dict) -> set[str]:
    """Collects any TTPRO-... reference memos present in logs or spl-memo instructions."""
    found: set[str] = set()
    meta = tx_result.get("meta") or {}
    for line in meta.get("logMessages") or []:
        if isinstance(line, str):
            found.update(_MEMO_TOKEN_RE.findall(line.upper()))

    message = (tx_result.get("transaction") or {}).get("message") or {}
    for ix in message.get("instructions") or []:
        if not isinstance(ix, dict):
            continue
        parsed = ix.get("parsed")
        if isinstance(parsed, str):
            found.update(_MEMO_TOKEN_RE.findall(parsed.upper()))
        elif isinstance(parsed, dict):
            memo_val = parsed.get("memo")
            if isinstance(memo_val, str):
                found.update(_MEMO_TOKEN_RE.findall(memo_val.upper()))
    return found


def _received_usdc_atomic(meta: dict, destination: str, mint: str) -> int:
    pre_by_index: dict[int, int] = {}
    for bal in meta.get("preTokenBalances") or []:
        if bal.get("mint") == mint and bal.get("owner") == destination:
            idx = bal.get("accountIndex")
            amt = ((bal.get("uiTokenAmount") or {}).get("amount")) or "0"
            if isinstance(idx, int):
                pre_by_index[idx] = int(amt)
    received = 0
    for bal in meta.get("postTokenBalances") or []:
        if bal.get("mint") == mint and bal.get("owner") == destination:
            idx = bal.get("accountIndex")
            amt = ((bal.get("uiTokenAmount") or {}).get("amount")) or "0"
            if isinstance(idx, int):
                delta = int(amt) - pre_by_index.get(idx, 0)
                if delta > 0:
                    received += delta
    return received


def _received_sol_lamports(meta: dict, keys: list[str], destination: str) -> int:
    pre = meta.get("preBalances") or []
    post = meta.get("postBalances") or []
    received = 0
    for i, key in enumerate(keys):
        if key == destination and i < len(pre) and i < len(post):
            delta = int(post[i]) - int(pre[i])
            if delta > 0:
                received += delta
    return received


def verify_solana_transfer(
    order: ProOrder,
    tx_signature: str,
    *,
    rpc_fetcher=None,
) -> VerifiedSolanaTransfer:
    sig = extract_solana_signature(tx_signature)
    if not _BASE58_SIG.fullmatch(sig):
        raise Problem("invalid_tx_signature", 400, "Invalid Solana transaction signature format.")

    fetcher = rpc_fetcher or _rpc_get_transaction
    result = fetcher(sig)
    if not result:
        raise Problem(
            "tx_not_found",
            404,
            "Transaction not confirmed on Solana yet. Wait a few seconds and try again.",
        )

    meta = result.get("meta") or {}
    if meta.get("err") is not None:
        raise Problem("tx_failed_onchain", 400, "This Solana transaction failed on-chain.")

    raw_bt = result.get("blockTime")
    if not isinstance(raw_bt, (int, float)):
        raise Problem(
            "tx_block_time_missing",
            400,
            "Transaction timestamp is not available yet. Wait a moment and try again.",
        )
    block_time = datetime.fromtimestamp(int(raw_bt), tz=dt_timezone.utc)

    # Strictly reject historical transactions (replay protection) and post-expiry transfers.
    earliest_allowed = order.created_at - timedelta(seconds=120)
    latest_allowed = order.expires_at + timedelta(seconds=300)
    if block_time < earliest_allowed:
        raise Problem(
            "tx_too_old",
            400,
            "This Solana transaction predates the checkout order and cannot be applied.",
        )
    if block_time > latest_allowed:
        raise Problem(
            "order_expired",
            410,
            "This transaction was confirmed after the order window expired. Please contact support or start a new order.",
        )

    # If the transaction carries an order memo, enforce it matches this order.
    memos = _extract_memo_tokens(result)
    expected_memo = (order.reference_memo or "").strip().upper()
    if memos and expected_memo and expected_memo not in memos:
        raise Problem(
            "tx_memo_mismatch",
            400,
            "This Solana transaction memo belongs to a different order.",
        )
    if getattr(settings, "PRO_REQUIRE_SOLANA_MEMO", False) and expected_memo and expected_memo not in memos:
        raise Problem(
            "tx_memo_required",
            400,
            "Transaction is missing the required order reference memo.",
        )

    keys = _extract_account_keys(result)
    payer = keys[0] if keys else ""
    dest = order.destination_wallet

    if order.asset == ProOrder.Asset.USDC:
        received = _received_usdc_atomic(meta, dest, settings.SOLANA_USDC_MINT)
        min_required = int(order.expected_amount_atomic)
    elif order.asset == ProOrder.Asset.SOL:
        received = _received_sol_lamports(meta, keys, dest)
        # Allow a tiny 1% rounding tolerance for SOL transfers.
        min_required = int(order.expected_amount_atomic * 0.99)
    else:
        raise Problem("unsupported_asset", 400, "Order is not payable with Solana.")

    if received < min_required:
        raise Problem(
            "insufficient_payment",
            400,
            "Transfer amount to the Tarot Tree wallet is lower than the order total.",
        )

    return VerifiedSolanaTransfer(
        tx_signature=sig,
        payer_wallet=payer,
        received_atomic=received,
        block_time=block_time,
    )
