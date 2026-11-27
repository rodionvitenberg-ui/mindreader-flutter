import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from django.conf import settings
from django.core import mail
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import Principal
from apps.payments.models import ProLedgerEntry, ProOrder, ProReceipt

VALID_SIG_1 = "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d8f8z8a8b8c8d8e8f8g8h8i8j8k8m"
VALID_SIG_2 = "4eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d8f8z8a8b8c8d8e8f8g8h8i8j8k8n"


def _now_ts(offset_seconds: int = 0) -> int:
    return int(timezone.now().timestamp()) + offset_seconds


def _mock_usdc_tx(
    destination: str,
    usdc_mint: str,
    micro_usdc: int,
    payer: str = "PayerWallet111111111111111111111111",
    block_time: int | None = None,
    memo: str | None = None,
):
    logs = [f'Program log: Memo (len {len(memo)}): "{memo}"'] if memo else []
    return {
        "blockTime": block_time if block_time is not None else _now_ts(),
        "meta": {
            "err": None,
            "logMessages": logs,
            "preTokenBalances": [
                {"accountIndex": 1, "mint": usdc_mint, "owner": destination, "uiTokenAmount": {"amount": "1000000"}},
            ],
            "postTokenBalances": [
                {
                    "accountIndex": 1,
                    "mint": usdc_mint,
                    "owner": destination,
                    "uiTokenAmount": {"amount": str(1000000 + micro_usdc)},
                },
            ],
        },
        "transaction": {"message": {"accountKeys": [{"pubkey": payer}, {"pubkey": destination}]}},
    }


def _mock_sol_tx(
    destination: str,
    lamports: int,
    payer: str = "PayerWallet222222222222222222222222",
    block_time: int | None = None,
    via_alt: bool = False,
):
    if via_alt:
        return {
            "blockTime": block_time if block_time is not None else _now_ts(),
            "meta": {
                "err": None,
                "preBalances": [5_000_000_000, 1_000_000_000],
                "postBalances": [5_000_000_000 - lamports - 5000, 1_000_000_000 + lamports],
                "loadedAddresses": {"writable": [destination], "readonly": []},
            },
            "transaction": {"message": {"accountKeys": [payer]}},
        }
    return {
        "blockTime": block_time if block_time is not None else _now_ts(),
        "meta": {
            "err": None,
            "preBalances": [5_000_000_000, 1_000_000_000],
            "postBalances": [5_000_000_000 - lamports - 5000, 1_000_000_000 + lamports],
        },
        "transaction": {"message": {"accountKeys": [payer, destination]}},
    }


class ProSubscriptionsTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_pro_solana_usdc_flow_receipt_owner_alert_jsonl_and_registration_claim(self):
        with tempfile.TemporaryDirectory() as tmp:
            ledger_file = Path(tmp) / "pro_ledger.jsonl"
            with override_settings(
                PRO_LEDGER_BACKUP_PATH=ledger_file,
                PRO_OWNER_NOTIFY_EMAIL="owner@tarottree.test",
                DEFAULT_FROM_EMAIL="noreply@tarottree.test",
            ):
                # 1. Public config exposes live Early Supporter offer ($4.99 vs $6.99, $39.99 annual, 100 slots).
                cfg = self.client.get("/api/v1/config/public/").json()
                self.assertEqual(cfg["proOffer"]["earlySupporterTotal"], 100)
                self.assertEqual(cfg["proOffer"]["earlySupporterRemaining"], 100)
                self.assertEqual(cfg["proOffer"]["earlyMonthlyMinor"], 499)
                self.assertEqual(cfg["proOffer"]["standardMonthlyMinor"], 699)
                self.assertEqual(cfg["proOffer"]["annualMinor"], 3999)

                # 2. User pays on website BEFORE ever registering in the app.
                create_res = self.client.post(
                    "/api/v1/payments/pro/checkout/",
                    {"email": "Alice@Example.com", "plan": "early_monthly", "asset": "USDC", "locale": "ru"},
                    format="json",
                )
                self.assertEqual(create_res.status_code, 201)
                order = create_res.json()
                self.assertEqual(order["email"], "alice@example.com")
                self.assertEqual(order["priceMinorUsd"], 499)
                self.assertEqual(order["expectedAmountAtomic"], 4_990_000)

                # 2b. Historical transaction predating the order is rejected (replay protection).
                old_tx = _mock_usdc_tx(
                    settings.PRO_SOLANA_WALLET,
                    settings.SOLANA_USDC_MINT,
                    4_990_000,
                    block_time=_now_ts(-3600),
                )
                with patch("apps.payments.solana._rpc_get_transaction", return_value=old_tx):
                    old_res = self.client.post(
                        "/api/v1/payments/pro/solana/verify/",
                        {"orderId": order["id"], "txSignature": VALID_SIG_1},
                        format="json",
                    )
                self.assertEqual(old_res.status_code, 400)
                self.assertEqual(old_res.json()["code"], "tx_too_old")

                # 2c. Transaction carrying a different order's memo is rejected.
                wrong_memo_tx = _mock_usdc_tx(
                    settings.PRO_SOLANA_WALLET,
                    settings.SOLANA_USDC_MINT,
                    4_990_000,
                    memo="TTPRO-OTHERORDER1",
                )
                with patch("apps.payments.solana._rpc_get_transaction", return_value=wrong_memo_tx):
                    memo_res = self.client.post(
                        "/api/v1/payments/pro/solana/verify/",
                        {"orderId": order["id"], "txSignature": VALID_SIG_1},
                        format="json",
                    )
                self.assertEqual(memo_res.status_code, 400)
                self.assertEqual(memo_res.json()["code"], "tx_memo_mismatch")

                # 3. Verify on-chain Solana USDC payment pasting a full Solscan URL!
                mock_tx = _mock_usdc_tx(
                    settings.PRO_SOLANA_WALLET,
                    settings.SOLANA_USDC_MINT,
                    4_990_000,
                    memo=order["referenceMemo"],
                )
                with self.captureOnCommitCallbacks(execute=True):
                    with patch("apps.payments.solana._rpc_get_transaction", return_value=mock_tx):
                        verify_res = self.client.post(
                            "/api/v1/payments/pro/solana/verify/",
                            {"orderId": order["id"], "txSignature": f"https://solscan.io/tx/{VALID_SIG_1}?cluster=mainnet"},
                            format="json",
                        )
                self.assertEqual(verify_res.status_code, 200)
                verified = verify_res.json()
                self.assertEqual(verified["status"], "paid")
                receipt_number = verified["receipt"]["receiptNumber"]
                self.assertEqual(verified["receipt"]["earlySupporterSlot"], 1)
                self.assertTrue(receipt_number.startswith("TT-PRO-"))
                self.assertTrue(verified["receipt"]["emailSent"])

                # Unauthenticated order detail masks email PII.
                detail_res = self.client.get(f"/api/v1/payments/pro/orders/{order['id']}/")
                self.assertEqual(detail_res.status_code, 200)
                self.assertIn("***@example.com", detail_res.json()["email"])

                # 4. Both subscriber receipt email AND separate owner notification email were sent.
                self.assertEqual(len(mail.outbox), 2)
                self.assertEqual(mail.outbox[0].to, ["alice@example.com"])
                self.assertIn(receipt_number, mail.outbox[0].body)
                self.assertIn("#1 из 100", mail.outbox[0].body)
                self.assertEqual(mail.outbox[1].to, ["owner@tarottree.test"])
                self.assertIn("alice@example.com", mail.outbox[1].body)

                # 5. Durable append-only JSONL mirror contains the record (written on_commit).
                lines = ledger_file.read_text(encoding="utf-8").strip().splitlines()
                self.assertEqual(len(lines), 1)
                backup_entry = json.loads(lines[0])
                self.assertEqual(backup_entry["email"], "alice@example.com")
                self.assertEqual(backup_entry["earlySupporterSlot"], 1)
                self.assertEqual(backup_entry["txSignature"], VALID_SIG_1)
                self.assertEqual(ProLedgerEntry.objects.count(), 1)
                self.assertEqual(ProReceipt.objects.count(), 1)

                # 6. Replay of the same tx signature on a second order is rejected (409).
                second_order = self.client.post(
                    "/api/v1/payments/pro/checkout/",
                    {"email": "bob@example.com", "plan": "early_monthly", "asset": "USDC"},
                    format="json",
                ).json()
                replay_tx = _mock_usdc_tx(settings.PRO_SOLANA_WALLET, settings.SOLANA_USDC_MINT, 4_990_000)
                with patch("apps.payments.solana._rpc_get_transaction", return_value=replay_tx):
                    replay_res = self.client.post(
                        "/api/v1/payments/pro/solana/verify/",
                        {"orderId": second_order["id"], "txSignature": VALID_SIG_1},
                        format="json",
                    )
                self.assertEqual(replay_res.status_code, 409)

                # 7a. Attacker attempting to hijack Alice's paid PRO email without receiptNumber is rejected (403)!
                hijack = self.client.post(
                    "/api/v1/auth/register/",
                    {"name": "Attacker", "email": "alice@example.com", "password": "StrongPassword!42"},
                    format="json",
                )
                self.assertEqual(hijack.status_code, 403)
                self.assertEqual(hijack.json()["code"], "pro_claim_required")

                # 7b. Legitimate Alice registers with her receiptNumber from the receipt email -> PRO unlocks!
                reg = self.client.post(
                    "/api/v1/auth/register/",
                    {
                        "name": "Alice",
                        "email": "alice@example.com",
                        "password": "StrongPassword!42",
                        "receiptNumber": receipt_number,
                    },
                    format="json",
                )
                self.assertEqual(reg.status_code, 201)
                reg_data = reg.json()
                self.assertTrue(reg_data["isPro"])
                self.assertTrue(reg_data["emailConfirmed"])
                self.assertEqual(reg_data["proPlan"], "early_monthly")
                self.assertEqual(reg_data["earlySupporterSlot"], 1)

                me = self.client.get("/api/v1/account/me/", HTTP_AUTHORIZATION=f"Bearer {reg_data['token']}")
                self.assertEqual(me.status_code, 200)
                self.assertTrue(me.json()["isPro"])
                self.assertEqual(me.json()["earlySupporterSlot"], 1)

                # Remaining Early Supporter slots decremented to 99.
                self.assertEqual(self.client.get("/api/v1/payments/pro/offer/").json()["earlySupporterRemaining"], 99)

                # 8. Delete Account (Google Play requirement) revokes token & scrubs PII while preserving financial receipt.
                del_res = self.client.delete("/api/v1/account/me/", HTTP_AUTHORIZATION=f"Bearer {reg_data['token']}")
                self.assertEqual(del_res.status_code, 204)
                after_del = self.client.get("/api/v1/account/me/", HTTP_AUTHORIZATION=f"Bearer {reg_data['token']}")
                self.assertEqual(after_del.status_code, 401)
                self.assertEqual(ProReceipt.objects.count(), 1)

    def test_pro_solana_sol_annual_v0_alt_and_slot_cap_fallback_for_both_plans(self):
        with tempfile.TemporaryDirectory() as tmp:
            with override_settings(
                PRO_LEDGER_BACKUP_PATH=Path(tmp) / "pro_ledger.jsonl",
                PRO_EARLY_SUPPORTER_LIMIT=1,
            ):
                # Annual SOL checkout takes the only Early Supporter slot (#1).
                with patch("apps.payments.pro_service.fetch_sol_usd_price", return_value=200.0):
                    annual = self.client.post(
                        "/api/v1/payments/pro/checkout/",
                        {"email": "first@example.com", "plan": "annual", "asset": "SOL"},
                        format="json",
                    ).json()
                self.assertEqual(annual["priceMinorUsd"], 3999)
                lamports = annual["expectedAmountAtomic"]

                # Underpayment fails with 400.
                under_tx = _mock_sol_tx(settings.PRO_SOLANA_WALLET, int(lamports * 0.5))
                with patch("apps.payments.solana._rpc_get_transaction", return_value=under_tx):
                    bad = self.client.post(
                        "/api/v1/payments/pro/solana/verify/",
                        {"orderId": annual["id"], "txSignature": VALID_SIG_2},
                        format="json",
                    )
                self.assertEqual(bad.status_code, 400)

                # Full SOL payment via Solana v0 Address Lookup Table succeeds and takes slot #1.
                good_tx = _mock_sol_tx(settings.PRO_SOLANA_WALLET, lamports, via_alt=True)
                with self.captureOnCommitCallbacks(execute=True):
                    with patch("apps.payments.solana._rpc_get_transaction", return_value=good_tx):
                        ok = self.client.post(
                            "/api/v1/payments/pro/solana/verify/",
                            {"orderId": annual["id"], "txSignature": VALID_SIG_2},
                            format="json",
                        )
                self.assertEqual(ok.status_code, 200)
                self.assertEqual(ok.json()["receipt"]["earlySupporterSlot"], 1)

                # Next monthly checkout sees 0 slots remaining and falls back to standard $6.99!
                next_monthly = self.client.post(
                    "/api/v1/payments/pro/checkout/",
                    {"email": "second@example.com", "plan": "early_monthly", "asset": "USDC"},
                    format="json",
                ).json()
                self.assertEqual(next_monthly["plan"], ProOrder.Plan.MONTHLY)
                self.assertEqual(next_monthly["priceMinorUsd"], 699)

                # Next annual checkout sees 0 slots remaining and falls back to standard $59.99!
                next_annual = self.client.post(
                    "/api/v1/payments/pro/checkout/",
                    {"email": "third@example.com", "plan": "annual", "asset": "USDC"},
                    format="json",
                ).json()
                self.assertEqual(next_annual["plan"], ProOrder.Plan.ANNUAL)
                self.assertEqual(next_annual["priceMinorUsd"], 5999)
                self.assertTrue(Principal.objects.filter(verified_email="first@example.com", is_pro=True).exists())
