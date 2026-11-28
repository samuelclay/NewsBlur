from datetime import timedelta
from urllib.parse import parse_qs, urlsplit

from django.contrib.auth.models import User
from django.test import Client, TestCase, override_settings
from django.utils import timezone
from django.utils.html import escape
from oauth2_provider.models import Application

from apps.oauth.access import SELF_SERVICE_LAUNCH
from apps.oauth.models import ApplicationExemption, ApplicationWebsite
from apps.profile.models import Profile


class Test_ApplicationRegistration(TestCase):
    url = "/account/applications/register/"
    fields = {
        "name": "Research & Development",
        "website": "https://company.example",
        "redirect_uri": "https://company.example/callback",
    }

    def setUp(self):
        self.owner = User.objects.create_user("company-owner")
        self.reader = User.objects.create_user("free-reader")
        Profile.objects.filter(user=self.reader).update(is_premium=False, is_premium_trial=False)
        self.client.force_login(self.owner)

    def set_pro(self, **kwargs):
        Profile.objects.filter(user=self.owner).update(
            is_premium=True, is_pro=True, is_premium_trial=False, **kwargs
        )

    def test_registration_requires_current_pro_and_a_valid_callback(self):
        self.assertEqual(self.client.post(self.url, self.fields).status_code, 403)
        self.set_pro(premium_expire=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.client.post(self.url, self.fields).status_code, 403)
        self.set_pro(premium_expire=None)
        self.assertEqual(
            self.client.post(self.url, self.fields, HTTP_ORIGIN="https://other.example").status_code, 403
        )
        for uri in [
            "http://company.example/callback",
            "https://company.example/#fragment",
            "https://*.example",
        ]:
            self.assertEqual(
                self.client.post(self.url, {**self.fields, "redirect_uri": uri}).status_code, 400
            )
        self.assertFalse(Application.objects.filter(user=self.owner).exists())

    def test_edit_form_requires_current_pro_or_an_exemption_and_preserves_credentials(self):
        app = Application.objects.create(
            name="Reader",
            user=self.owner,
            redirect_uris="https://reader.example/original",
            authorization_grant_type=Application.GRANT_AUTHORIZATION_CODE,
            client_type=Application.CLIENT_CONFIDENTIAL,
        )
        url = f"/account/applications/{app.pk}/update/"
        self.assertEqual(self.client.get(url).status_code, 403)
        self.set_pro(premium_expire=None)
        self.assertEqual(self.client.get(url).status_code, 200)
        self.set_pro(premium_expire=timezone.now() - timedelta(seconds=1))
        ApplicationExemption.objects.create(application=app)
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, 'name="client_secret"')
        self.assertNotContains(response, 'name="authorization_grant_type"')

        updated = {"name": "Reader 2", "redirect_uris": "https://reader.example/callback"}
        response = self.client.post(url, {**updated, "redirect_uris": "http://reader.example/callback"})
        self.assertTrue(response.context["form"].errors.get("redirect_uris"))
        original_credentials = (app.client_id, app.client_secret, app.authorization_grant_type)
        response = self.client.post(url, {**updated, "authorization_grant_type": Application.GRANT_IMPLICIT})
        self.assertEqual(response.status_code, 302)
        app.refresh_from_db()
        self.assertEqual((app.name, app.redirect_uris), (updated["name"], updated["redirect_uris"]))
        self.assertEqual(
            (app.client_id, app.client_secret, app.authorization_grant_type), original_credentials
        )

        # The exemption covers this application only: not new registrations, and not other accounts.
        self.assertEqual(self.client.post(self.url, self.fields).status_code, 403)
        self.assertEqual(list(Application.objects.filter(user=self.owner)), [app])
        self.client.force_login(self.reader)
        taken = {"name": "Taken", "redirect_uris": "https://taken.example/callback"}
        self.assertEqual(self.client.post(url, taken).status_code, 404)
        app.refresh_from_db()
        self.assertEqual((app.name, app.redirect_uris), (updated["name"], updated["redirect_uris"]))

    def test_owner_sees_distinct_connections_and_reader_traffic_for_only_their_apps(self):
        from unittest.mock import patch
        from uuid import uuid4

        import redis
        from django.conf import settings
        from oauth2_provider.models import AccessToken

        from apps.oauth import traffic

        url = "/account/applications/usage/"
        self.set_pro(premium_expire=None)
        app = Application.objects.create(user=self.owner, name="Owner's reader")
        other = Application.objects.create(user=self.reader, name="Other reader")
        expired_user = User.objects.create_user("expired-reader")
        future = timezone.now() + timedelta(days=1)
        past = timezone.now() - timedelta(days=1)
        for token, user, expires in [
            ("first", self.reader, future),
            ("second", self.reader, future),
            ("publisher", self.owner, future),
            ("expired", expired_user, past),
        ]:
            AccessToken.objects.create(application=app, token=token, user=user, expires=expires)

        api = Client()
        self.assertEqual(api.get(url).status_code, 403)
        prefix = f"test:oauth:owner:{uuid4().hex}"
        with patch.object(traffic, "REQUESTS_KEY", prefix), patch.object(
            traffic, "LAST_USED_KEY", prefix + ":last_used"
        ):
            connection = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
            self.addCleanup(
                connection.delete,
                prefix,
                traffic.LAST_USED_KEY,
                traffic.readers_key(app.pk, int(traffic.time.time()) // 86400),
            )
            for token in ["first", "second"]:
                self.assertEqual(
                    api.get("/oauth/user/info/", HTTP_AUTHORIZATION="Bearer " + token).status_code, 200
                )
            apps = self.client.get(url).json()["applications"]
            self.assertEqual([row["id"] for row in apps], [app.id])
            self.assertIsNone(apps[0]["website"])
            self.assertEqual(apps[0]["client_id"], app.client_id)
            self.assertNotIn("client_secret", apps[0])
            self.assertEqual(apps[0]["connected"], 2)
            self.assertEqual(apps[0]["usage"]["requests"], 2)
            self.assertEqual(apps[0]["usage"]["readers"], 1)
            self.assertIsNotNone(apps[0]["usage"]["last_used"])
            self.assertFalse(apps[0]["paused"])
            # The exemption only decides paused; its row id stays out of the response on every plan.
            self.assertNotIn("applicationexemption__id", apps[0])
            self.assertEqual(api.get(url, HTTP_AUTHORIZATION="Bearer publisher").status_code, 403)
            self.client.force_login(self.reader)
            rows = self.client.get(url).json()["applications"]
            self.assertEqual([(row["id"], row["paused"]) for row in rows], [(other.pk, True)])
            ApplicationExemption.objects.create(application=other)
            self.assertFalse(self.client.get(url).json()["applications"][0]["paused"])
            with patch("apps.oauth.applications.application_usage", side_effect=redis.ConnectionError()):
                row = self.client.get(url).json()["applications"][0]
                self.assertIsNone(row["usage"])
                self.assertEqual(row["connected"], 0)

    def test_free_reader_can_preview_before_registration_without_granting_access(self):
        url = "/account/applications/preview/"
        self.client.force_login(self.reader)
        preview = self.client.get(url, self.fields)
        self.assertTemplateUsed(preview, "oauth2_provider/authorize.html")
        self.assertContains(preview, escape(self.fields["name"]))
        self.assertContains(preview, self.fields["website"])
        self.assertEqual(self.client.post(url, {"allow": "Authorize"}).status_code, 405)
        self.assertFalse(Application.objects.filter(user=self.reader).exists())

    def test_only_first_party_ownerless_clients_can_issue_tokens(self):
        from oauth2_provider.models import AccessToken

        api = Client()
        for client_id, expected in [("newsblur-cli", 200), ("unowned-reader", 403)]:
            app, _ = Application.objects.get_or_create(client_id=client_id)
            token = AccessToken.objects.create(
                application=app,
                user=self.reader,
                token="test-" + client_id,
                expires=timezone.now() + timedelta(days=1),
            )
            response = api.get("/oauth/user/info/", HTTP_AUTHORIZATION="Bearer " + token.token)
            self.assertEqual(response.status_code, expected)

    def test_free_reader_can_authorize_while_the_owner_has_pro_or_staff_exempt_the_application(self):
        self.set_pro(premium_expire=None)
        response = self.client.post(self.url, {**self.fields, "user": self.reader.pk})
        self.assertEqual(response.status_code, 201, response.content)
        credentials = response.json()
        app = Application.objects.get(client_id=credentials["client_id"])
        self.assertEqual(app.user, self.owner)
        self.assertNotEqual(app.client_secret, credentials["client_secret"])
        self.assertEqual(ApplicationWebsite.objects.get(application=app).website, self.fields["website"])
        auth = {
            "client_id": app.client_id,
            "response_type": "code",
            "redirect_uri": self.fields["redirect_uri"],
            "scope": "read",
            "state": "test-state",
        }
        self.client.force_login(self.reader)
        self.assertContains(self.client.get("/oauth/authorize/", auth), escape(app.name))

        def authorize():
            response = self.client.post("/oauth/authorize/", {**auth, "allow": "true"})
            self.assertEqual(response.status_code, 302)
            return parse_qs(urlsplit(response.url).query)["code"][0]

        def exchange(code):
            return self.client.post(
                "/oauth/token/",
                {
                    **credentials,
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": auth["redirect_uri"],
                },
            )

        tokens = exchange(authorize()).json()
        unused_code = authorize()
        bearer = {"HTTP_AUTHORIZATION": "Bearer " + tokens["access_token"]}
        api = Client()
        self.assertEqual(api.get("/oauth/user/info/", **bearer).json()["data"]["id"], self.reader.pk)
        self.set_pro(premium_expire=timezone.now() - timedelta(seconds=1))
        for url in ["/oauth/authorize/", "/account/authorize/", "/account/ifttt/v1/oauth2/authorize"]:
            self.assertContains(self.client.get(url, auth), "Premium Pro", status_code=401)
        self.assertIn("Premium Pro", exchange(unused_code).json()["error_description"])
        refresh = self.client.post(
            "/account/token/",
            {**credentials, "grant_type": "refresh_token", "refresh_token": tokens["refresh_token"]},
        )
        self.assertIn("Premium Pro", refresh.json()["error_description"])
        self.assertContains(api.get("/reader/feeds", **bearer), "Premium Pro", status_code=403)
        self.set_pro(premium_expire=timezone.now() + timedelta(days=1))
        self.assertEqual(api.get("/oauth/user/info/", **bearer).json()["data"]["id"], self.reader.pk)
        self.set_pro(premium_expire=timezone.now() - timedelta(seconds=1))
        # Registering before self-service launched no longer keeps an application working on its own.
        Application.objects.filter(pk=app.pk).update(created=SELF_SERVICE_LAUNCH - timedelta(days=1))
        self.assertEqual(api.get("/oauth/user/info/", **bearer).status_code, 403)

        staff = Client()
        staff.force_login(User.objects.create_superuser("oauth-staff", "oauth-staff@example.com", "staff"))
        added = staff.post("/admin/oauth/applicationexemption/add/", {"application": app.pk})
        self.assertEqual(added.status_code, 302)
        self.assertEqual(api.get("/oauth/user/info/", **bearer).json()["data"]["id"], self.reader.pk)
        self.assertEqual(exchange(authorize()).status_code, 200)
        code_issued_while_exempt = authorize()
        refresh = self.client.post(
            "/account/token/",
            {**credentials, "grant_type": "refresh_token", "refresh_token": tokens["refresh_token"]},
        )
        self.assertEqual(refresh.status_code, 200)
        # Refreshing revoked the first access token.
        bearer = {"HTTP_AUTHORIZATION": "Bearer " + refresh.json()["access_token"]}
        self.assertEqual(api.get("/oauth/user/info/", **bearer).json()["data"]["id"], self.reader.pk)

        User.objects.filter(pk=self.owner.pk).update(is_active=False)
        self.assertContains(api.get("/reader/feeds", **bearer), "Premium Pro", status_code=403)
        self.assertContains(self.client.get("/oauth/authorize/", auth), "Premium Pro", status_code=401)
        User.objects.filter(pk=self.owner.pk).update(is_active=True)
        self.assertEqual(api.get("/oauth/user/info/", **bearer).json()["data"]["id"], self.reader.pk)

        exemption = ApplicationExemption.objects.get(application=app)
        removed = staff.post(f"/admin/oauth/applicationexemption/{exemption.pk}/delete/", {"post": "yes"})
        self.assertEqual(removed.status_code, 302)
        self.assertContains(api.get("/reader/feeds", **bearer), "Premium Pro", status_code=403)
        self.assertIn("Premium Pro", exchange(code_issued_while_exempt).json()["error_description"])


class Test_ApplicationExemptions(TestCase):
    def test_backfill_exempts_pre_launch_applications_once(self):
        from django.apps import apps

        from apps.oauth.access import exempt_existing_applications

        owner = User.objects.create_user("legacy-publisher")
        old = Application.objects.create(name="Old reader", user=owner)
        new = Application.objects.create(name="New reader", user=owner)
        first_party, _ = Application.objects.get_or_create(client_id="newsblur-cli")
        Application.objects.filter(pk__in=[old.pk, first_party.pk]).update(
            created=SELF_SERVICE_LAUNCH - timedelta(microseconds=1)
        )
        Application.objects.filter(pk=new.pk).update(created=SELF_SERVICE_LAUNCH)
        for _ in range(2):
            exempt_existing_applications(apps, "default")
        exempted = ApplicationExemption.objects.filter(application__in=[old, new, first_party]).values_list(
            "application_id", flat=True
        )
        self.assertEqual(list(exempted), [old.pk])

    def test_deleting_an_exempt_application_outside_the_orm_removes_its_exemption(self):
        from django.db import connection

        owner = User.objects.create_user("retired-publisher")
        app = Application.objects.create(name="Retired reader", user=owner)
        ApplicationExemption.objects.create(application=app)
        # A release that predates ApplicationExemption deletes the application without collecting its
        # exemption, so the database has to cascade (oauth.0004_applicationexemption).
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM oauth2_provider_application WHERE id = %s", [app.pk])
        # Postgres checks deferred foreign keys at commit, which a TestCase never reaches.
        connection.check_constraints()
        self.assertFalse(ApplicationExemption.objects.filter(application_id=app.pk).exists())

    # Rendering the admin needs collectstatic's manifest, which test runs don't build.
    @override_settings(STATICFILES_STORAGE="django.contrib.staticfiles.storage.StaticFilesStorage")
    def test_staff_find_exemptions_by_owner_or_application_name(self):
        owner = User.objects.create_user("exempt-publisher")
        app = Application.objects.create(name="Unread for Mac", user=owner)
        first_party, _ = Application.objects.get_or_create(client_id="newsblur-cli")
        exemption = ApplicationExemption.objects.create(application=app)
        ApplicationExemption.objects.create(application=first_party)
        staff = Client()
        staff.force_login(User.objects.create_superuser("oauth-staff", "oauth-staff@example.com", "staff"))
        url = "/admin/oauth/applicationexemption/"
        self.assertEqual(len(staff.get(url).context["cl"].result_list), 2)
        for query in [owner.username, app.name]:
            self.assertEqual(list(staff.get(url, {"q": query}).context["cl"].result_list), [exemption])
