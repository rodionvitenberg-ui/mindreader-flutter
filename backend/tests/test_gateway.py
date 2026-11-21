import os
from unittest.mock import patch

from django.test import TestCase

from apps.ai_gateway import routing
from apps.ai_gateway.models import Capability, Protocol, Provider, Usage
from apps.ai_gateway.transport import UpstreamError
from apps.core.api import Problem


@patch.dict(os.environ, {"AI_ALLOWED_HOSTS": "inference.example.test"})
class GatewayTests(TestCase):
    def provider(self, name="oracle", *, capability=Capability.ORACLE, priority=10, **kwargs):
        return Provider.objects.create(
            name=name, capability=capability, model="configured", enabled=kwargs.pop("enabled", True),
            protocol=Protocol.OPENAI_CHAT if capability == Capability.ORACLE else Protocol.HTTP_VISION,
            endpoint="https://inference.example.test/api", priority=priority,
            is_paid=kwargs.pop("is_paid", False), **kwargs,
        )

    @patch("apps.ai_gateway.adapters.request_json")
    def test_switching_vision_preserves_oracle_and_missing_provider_is_explicit(self, send):
        oracle = self.provider()
        send.return_value = {"choices": [{"message": {"content": "reading"}}]}
        self.assertEqual(routing.generate([]), ("reading", oracle.name))
        with self.assertRaisesMessage(Problem, "AI service could not complete"):
            routing.recognize([{"itemId": "front"}], system="tarot")

        vision = self.provider("vision", capability=Capability.VISION)
        vision.model = "updated"
        vision.save()
        send.return_value = {"results": [{"itemId": "front"}]}
        self.assertEqual(routing.recognize(
            [{"itemId": "front", "bytes": b"image", "mimeType": "image/jpeg"}], system="tarot"
        )[1], vision.name)
        self.assertEqual(send.call_args.args[1]["model"], "updated")
        oracle.refresh_from_db()
        self.assertEqual(oracle.model, "configured")

    @patch("apps.ai_gateway.adapters.request_json", side_effect=UpstreamError("provider_timeout"))
    def test_unexpected_paid_fallback_and_quota_are_blocked(self, send):
        primary = self.provider(daily_request_limit=1)
        self.provider("paid", priority=20, is_paid=True, max_cost_per_request="0.02", daily_spending_limit="1")
        for code in ("provider_timeout", "provider_quota_exhausted"):
            with self.assertRaises(Problem) as result:
                routing.generate([])
            self.assertEqual(result.exception.get_codes(), code)
        self.assertEqual(send.call_count, 1)
        self.assertEqual(list(Usage.objects.values_list("provider_id", flat=True)), [primary.id])

    @patch("apps.ai_gateway.adapters.request_json")
    def test_unconfigured_disabled_and_rejected_endpoints_never_call_adapter(self, send):
        self.provider("missing", credential_ref="AI_CREDENTIAL_MISSING")
        self.provider("disabled", enabled=False)
        Provider.objects.filter(name="missing").update(endpoint="https://untrusted.invalid")
        with self.assertRaises(Problem) as result:
            routing.generate([])
        self.assertEqual(result.exception.get_codes(), "provider_unavailable")
        send.assert_not_called()


    @patch("apps.ai_gateway.adapters.request_json")
    def test_disabled_primary_does_not_promote_paid_fallback(self, send):
        self.provider(enabled=False)
        self.provider("paid", priority=20, is_paid=True, max_cost_per_request="0.02", daily_spending_limit="1")
        with self.assertRaises(Problem) as result:
            routing.generate([])
        self.assertEqual(result.exception.get_codes(), "provider_unavailable")
        send.assert_not_called()

    def test_no_credentials_in_transport_error_and_no_redirect(self):
        import httpx

        from apps.ai_gateway.transport import request_json

        self.provider(credential_ref="AI_CREDENTIAL_ORACLE_TEST")
        provider = Provider.objects.get()
        connection = httpx.Client
        observed = []

        def responder(request):
            observed.append((str(request.url), request.headers.get("Authorization")))
            return httpx.Response(302, headers={"Location": "https://other.example.test/leak"})

        transport = httpx.MockTransport(responder)
        with (patch.dict(os.environ, {"AI_CREDENTIAL_ORACLE_TEST": "mock-bearer"}),
              patch("apps.ai_gateway.transport.httpx.Client", side_effect=lambda **kw: connection(transport=transport, **kw))):
            with self.assertRaises(UpstreamError) as result:
                request_json(provider, {})
            self.assertEqual(str(result.exception), "provider_error")
        self.assertEqual(observed, [("https://inference.example.test/api", "Bearer mock-bearer")])
