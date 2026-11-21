import os
from tempfile import TemporaryDirectory
from unittest.mock import patch

from django.contrib.auth.models import Permission, User
from django.test import TestCase, override_settings
from django.urls import reverse

from apps.ai_gateway.models import Provider
from apps.entitlements.models import Grant

from .test_store import deck_fixture, package_fixture


class AdminTests(TestCase):
    def setUp(self):
        self.client.force_login(User.objects.create_superuser(username="admin", password=None))

    @patch.dict(os.environ, {"AI_ORACLE_ALLOWED_HOSTS": "inference.example.test",
                             "AI_CREDENTIAL_ORACLE_TEST": "private-test-value"})
    def test_operator_can_edit_provider_and_reference_without_seeing_secret(self):
        response = self.client.post(reverse("admin:ai_gateway_provider_add"), {
            "name": "oracle", "capability": "oracle", "protocol": "openai_chat",
            "endpoint": "https://inference.example.test/complete", "model": "initial",
            "credential_ref": "AI_CREDENTIAL_ORACLE_TEST", "enabled": "on", "priority": 10,
            "connect_timeout": 1, "inference_timeout": 5, "retries": 0, "concurrency_limit": 2,
            "daily_request_limit": 30, "max_cost_per_request": 0,
            "_save": "Save",
        })
        self.assertEqual(response.status_code, 302, getattr(response, "context", ""))
        provider = Provider.objects.get()
        form = self.client.get(reverse("admin:ai_gateway_provider_change", args=[provider.pk]))
        self.assertContains(form, "AI_CREDENTIAL_ORACLE_TEST")
        self.assertNotContains(form, "private-test-value")
        public = self.client.get("/api/v1/config/public/")
        self.assertNotContains(public, "AI_CREDENTIAL_ORACLE_TEST")

    def test_operator_uploads_validated_version_and_can_inspect_manifest_assets(self):
        temp = self.enterContext(TemporaryDirectory())
        self.enterContext(override_settings(MEDIA_ROOT=temp))
        deck = deck_fixture()
        release = package_fixture(deck)
        add = self.client.post(reverse("admin:catalog_deckversion_add"), {
            "deck": deck.pk, "version": "1.0.0", "min_app_version": "1.0.0",
            "package": release.package.file, "incomplete": "on", "published": "on",
            "assets-TOTAL_FORMS": "0", "assets-INITIAL_FORMS": "0",
            "assets-MIN_NUM_FORMS": "0", "assets-MAX_NUM_FORMS": "0", "_save": "Save",
        })
        self.assertEqual(add.status_code, 302)
        version = deck.versions.get()
        self.assertEqual(version.card_count, 1)
        view = self.client.get(reverse("admin:catalog_deckversion_change", args=[version.pk]))
        self.assertContains(view, "lenormand:0")

    def test_staff_without_add_permission_cannot_grant_entitlements(self):
        staff = User.objects.create_user(username="catalogue", is_staff=True)
        staff.user_permissions.add(Permission.objects.get(codename="view_grant"))
        self.client.force_login(staff)
        self.assertEqual(self.client.post(reverse("admin:entitlements_grant_add"), {}).status_code, 403)
        self.assertFalse(Grant.objects.exists())
