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

    @override_settings(EMAIL_VERIFICATION_ENABLED=True)
    def test_password_register_login_and_optional_email_confirm(self):
        reg = self.client.post(
            "/api/v1/auth/register/",
            {"name": "Luna", "email": "luna@example.org", "password": "strongpassword123"},
            format="json",
        )
        self.assertEqual(reg.status_code, 201)
        body = reg.json()
        self.assertTrue(body["verified"])
        self.assertFalse(body["emailConfirmed"])
        self.assertEqual(body["email"], "luna@example.org")
        self.assertEqual(body["name"], "Luna")

        # Duplicate email is rejected with 409.
        dup = self.client.post(
            "/api/v1/auth/register/",
            {"name": "Luna 2", "email": "LUNA@example.org", "password": "strongpassword123"},
            format="json",
        )
        self.assertEqual(dup.status_code, 409)

        # Wrong password fails with 401.
        bad = self.client.post(
            "/api/v1/auth/login/",
            {"email": "luna@example.org", "password": "wrongpassword"},
            format="json",
        )
        self.assertEqual(bad.status_code, 401)

        # Correct password returns same account id.
        ok = self.client.post(
            "/api/v1/auth/login/",
            {"email": "luna@example.org", "password": "strongpassword123"},
            format="json",
        )
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(ok.json()["id"], body["id"])
        self.assertEqual(ok.json()["name"], "Luna")

        # Post-factum optional email confirmation flips emailConfirmed to True.
        self.assertEqual(
            self.client.post("/api/v1/auth/email/start/", {"email": "luna@example.org"}).status_code,
            202,
        )
        code = mail.outbox[-1].body.split()[-1]
        confirmed = self.client.post("/api/v1/auth/email/verify/", {"token": code})
        self.assertEqual(confirmed.status_code, 200)
        self.assertEqual(confirmed.json()["id"], body["id"])
        self.assertTrue(confirmed.json()["emailConfirmed"])
