from django.core import mail
from django.test import TestCase, override_settings
from rest_framework.test import APIClient


class CoreTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_health_config_and_schema(self):
        self.assertEqual(self.client.get("/api/v1/health/").json(), {"status": "ok"})
        self.assertTrue(self.client.get("/api/v1/config/public/").json()["guestAccess"])
        self.assertEqual(self.client.get("/api/v1/schema/").status_code, 200)

    def test_guest_is_server_issued_and_revocable(self):
        guest = self.client.post("/api/v1/auth/guest/").json()
        self.assertFalse(guest["verified"])
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {guest['token']}")
        self.assertEqual(self.client.get("/api/v1/account/me/").json()["id"], guest["id"])
        self.assertEqual(self.client.post("/api/v1/auth/logout/").status_code, 204)
        self.assertEqual(self.client.get("/api/v1/account/me/").status_code, 401)

    @override_settings(EMAIL_VERIFICATION_ENABLED=True)
    def test_email_proof_is_single_use_and_restores_same_account(self):
        accounts = []
        for _ in range(2):
            self.assertEqual(self.client.post("/api/v1/auth/email/start/", {"email": "reader@example.org"}).status_code, 202)
            token = mail.outbox[-1].body.split()[-1]
            response = self.client.post("/api/v1/auth/email/verify/", {"token": token})
            self.assertEqual(response.status_code, 200)
            self.assertTrue(response.json()["verified"])
            accounts.append(response.json()["id"])
            self.assertEqual(self.client.post("/api/v1/auth/email/verify/", {"token": token}).status_code, 400)
        self.assertEqual(accounts[0], accounts[1])
