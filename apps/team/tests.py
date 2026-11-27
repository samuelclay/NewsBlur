import copy
import datetime
import re
import smtplib
import threading
from decimal import Decimal
from unittest.mock import MagicMock, patch
from urllib.parse import urlencode

import dateutil.parser
import paypalrestsdk
import redis
import stripe
from dateutil.relativedelta import relativedelta
from django.conf import settings
from django.contrib.auth.models import User
from django.core import mail
from django.core.mail import EmailMultiAlternatives
from django.db import DatabaseError, connection, transaction
from django.test import Client, TestCase, TransactionTestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import dateformat
from mongoengine.context_managers import switch_db
from paypal.standard.ipn.models import PayPalIPN

from apps.archive_assistant.models import MArchiveAssistantUsage
from apps.ask_ai.models import MAITranscriptionUsage, MAskAIUsage
from apps.ask_ai.usage import AskAIUsageTracker, TranscriptionUsageTracker
from apps.feed_import.models import OPMLImporter
from apps.listen.models import MListenUsage
from apps.listen.usage import ListenUsageTracker
from apps.monitor.models import MLLMCost
from apps.profile import models as profile_models
from apps.profile.apple_subscriptions import apply_verified_apple_transaction
from apps.profile.models import (
    MGiftCode,
    MRedeemedCode,
    MReferral,
    PaymentHistory,
    PaypalIds,
    Profile,
    StripeIds,
    stripe_subscription_updated,
)
from apps.profile.tasks import (
    EmailNewPremium,
    EmailNewPremiumPro,
    EmailNewPremiumTrial,
    EmailReferralCredit,
    EmailStaffNotification,
    EmailStaffPremiumUpgrade,
    PremiumExpire,
)
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.reader.tasks import MaintainFeedSubscriptions
from apps.rss_feeds.models import Feed
from apps.rss_feeds.tasks import ScheduleImmediateFetches, SchedulePremiumSetup
from apps.statistics.models import MStatistics
from apps.statistics.rllm_costs import RLLMCosts
from apps.team import stripe_billing
from apps.team.billing import record_team_payment, start_comp_team
from apps.team.grants import activate_team, deactivate_team, release_team_pro
from apps.team.models import (
    Team,
    TeamActivity,
    TeamInvite,
    TeamMember,
    TeamProGrant,
    team_owner_id,
)
from apps.team.tasks import (
    EmailTeamPlanEnded,
    EmailTeamWelcome,
    SendTeamInviteEmail,
    SettleOwnPlanOnJoin,
    StopRenewalsMadeBefore,
    TeamProGrants,
)
from apps.webfeed.models import MWebFeedConfig
from utils import json_functions as json
from utils import urlnorm
from utils.llm_costs import LLMCostTracker

# apps/team/tests.py: the Profile flags of each plan, written out here so the tests don't read them from the code
# under test.
PLANS = {
    "free": dict(
        is_premium=False, is_premium_trial=False, is_archive=False, is_archive_extra=False, is_pro=False
    ),
    "trial": dict(
        is_premium=True, is_premium_trial=True, is_archive=False, is_archive_extra=False, is_pro=False
    ),
    "premium": dict(
        is_premium=True, is_premium_trial=False, is_archive=False, is_archive_extra=False, is_pro=False
    ),
    "archive": dict(
        is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=False, is_pro=False
    ),
    "archive_extra": dict(
        is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=True, is_pro=False
    ),
    "pro": dict(
        is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=False, is_pro=True
    ),
}


class TeamClientMixin:
    def setUp(self):
        super().setUp()
        # apps/team/tests.py: Celery doesn't run tasks eagerly in tests (test_settings.py's CELERY_ALWAYS_EAGER
        # isn't a name this Celery reads), so the invite email task runs in place and every other dispatch is
        # kept off the dev broker.
        self.invite_email_task = self.patch(
            SendTeamInviteEmail, "delay", side_effect=lambda invite_id: SendTeamInviteEmail(invite_id)
        )
        # apps/team/tests.py: apply runs a task's retries in place too, and get() raises what its last try raised.
        for task in (SettleOwnPlanOnJoin, EmailTeamPlanEnded, StopRenewalsMadeBefore):
            self.patch(task, "delay", side_effect=lambda task=task, **kwargs: task.apply(kwargs=kwargs).get())
        self.patch(EmailTeamWelcome, "delay", side_effect=lambda team_id: EmailTeamWelcome(team_id))
        for task in (EmailNewPremiumTrial, EmailStaffPremiumUpgrade, EmailStaffNotification):
            self.patch(task, "delay")
        self.patch(SchedulePremiumSetup, "apply_async")
        self.patch(UserSubscription, "queue_new_feeds")
        self.backfill = self.patch(UserSubscription, "schedule_fetch_archive_feeds_for_user")
        # apps/team/tests.py: a site becoming active looks up similar sites with an OpenAI embedding and an
        # Elasticsearch vector search (Feed.find_similar_feeds), which no test here may reach.
        self.patch(Feed, "find_similar_feeds", return_value=[])

    def patch(self, target, attribute, **kwargs):
        patcher = patch.object(target, attribute, **kwargs)
        self.addCleanup(patcher.stop)
        return patcher.start()

    def client_for(self, user):
        client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        if user:
            client.force_login(user)
        return client

    def post(self, user, path, **data):
        """apps/team/tests.py: also runs what the request queued with transaction.on_commit, as the commit at the
        end of a real request would. Django 3.1's TestCase never commits."""
        queued = len(connection.run_on_commit)
        response = self.client_for(user).post("/team/%s" % path, data)
        callbacks = connection.run_on_commit[queued:]
        del connection.run_on_commit[queued:]
        for _, callback in callbacks:
            callback()
        return json.decode(response.content)

    def get(self, user, path, **data):
        return json.decode(self.client_for(user).get("/team/%s" % path, data).content)

    def create_team(self, owner, name="Newsroom"):
        """apps/team/tests.py: a team started the way staff start one, as a comp whose owner gets Premium Pro."""
        team, reason = start_comp_team(owner, name, Team.PLAN_TEAM)
        self.assertIsNone(reason)
        return team

    def add_member(self, team, user, role=TeamMember.ROLE_MEMBER):
        return TeamMember.objects.create(team=team, user=user, role=role)

    def join_link_token(self, team, manager):
        self.post(manager, "join_link", team_id=team.pk)
        return team.live_join_link().token

    def invite_tokens_from_mail(self):
        """apps/team/tests.py: each invited address and the token its email's join button carries."""
        return {
            message.to[0]: re.search(r"team_invite=([\w-]+)", message.body).group(1)
            for message in mail.outbox
        }

    def while_held(self, hold, other_request, during=None):
        """apps/team/tests.py: this thread opens a transaction and runs hold(), which takes a lock or writes a
        row another request needs. other_request runs in a second thread and has to wait for it; during() runs
        before this transaction commits and lets it go. Returns during's result and other_request's."""
        other_results = []

        def in_another_request():
            try:
                other_results.append(other_request())
            finally:
                connection.close()

        other_thread = threading.Thread(target=in_another_request)
        try:
            with transaction.atomic():
                hold()
                other_thread.start()
                other_thread.join(timeout=1)
                self.assertTrue(other_thread.is_alive(), "the other request went ahead without waiting")
                held_result = during() if during else None
        finally:
            other_thread.join(timeout=10)
        return held_result, other_results[0]


class Test_TeamSeats(TeamClientMixin, TestCase):
    def setUp(self):
        super().setUp()
        self.owner = User.objects.create_user(username="owner", password="password")
        self.team = self.create_team(self.owner, "Newsroom")
        self.team.seat_limit = 3
        self.team.save()
        self.token = self.join_link_token(self.team, self.owner)

    def test_the_last_seat_is_taken_and_the_next_join_is_refused(self):
        # Pending invites hold no seat, so these never count against the limit.
        self.post(self.owner, "invite", team_id=self.team.pk, emails="one@example.com, two@example.com")

        for username in ("first", "second"):
            joiner = User.objects.create_user(username=username)
            self.assertEqual(self.post(joiner, "accept_invite", token=self.token)["code"], 1)

        late = User.objects.create_user(username="late")
        response = self.post(late, "accept_invite", token=self.token)

        self.assertEqual(response["reason"], "seat_limit")
        self.assertEqual(self.team.active_members().count(), 3)
        self.assertFalse(TeamMember.objects.filter(team=self.team, user=late).exists())

    def test_a_removed_manager_loses_access_and_returns_only_by_a_new_invite(self):
        manager = User.objects.create_user(username="manager")
        self.add_member(self.team, manager, TeamMember.ROLE_MANAGER)

        response = self.post(self.owner, "remove_member", team_id=self.team.pk, user_id=manager.pk)
        self.assertEqual(response["team"]["seats_used"], 1)

        self.assertIsNone(self.get(manager, "")["team"])
        self.assertEqual(self.get(manager, "activity", team_id=self.team.pk)["reason"], "not_found")
        response = self.post(manager, "invite", team_id=self.team.pk, emails="friend@example.com")
        self.assertEqual(response["reason"], "not_found")
        self.assertEqual(self.post(manager, "accept_invite", token=self.token)["reason"], "removed_by_team")

        self.post(self.owner, "invite", team_id=self.team.pk, emails="manager@example.com")
        response = self.post(
            manager, "accept_invite", token=self.invite_tokens_from_mail()["manager@example.com"]
        )

        self.assertEqual(response["code"], 1)
        self.assertEqual(response["team"]["seats_used"], 2)
        self.assertEqual(response["team"]["role"], TeamMember.ROLE_MEMBER)
        self.assertEqual(TeamMember.objects.filter(team=self.team, user=manager).count(), 1)

    def test_a_removed_teammate_returns_only_by_an_invite_sent_after_the_removal(self):
        manager = User.objects.create_user(username="manager")
        reader = User.objects.create_user(username="reader")
        self.add_member(self.team, manager, TeamMember.ROLE_MANAGER)
        self.post(self.owner, "invite", team_id=self.team.pk, emails="reader@example.com")
        earlier_token = self.invite_tokens_from_mail()["reader@example.com"]
        self.post(reader, "accept_invite", token=self.token)
        self.post(manager, "remove_member", team_id=self.team.pk, user_id=reader.pk)
        # The remover's account going away doesn't make the removal a departure of the reader's own.
        manager.delete()

        self.assertEqual(self.post(reader, "accept_invite", token=self.token)["reason"], "removed_by_team")
        self.assertEqual(self.post(reader, "accept_invite", token=earlier_token)["reason"], "removed_by_team")

        mail.outbox = []
        self.post(self.owner, "invite", team_id=self.team.pk, emails="reader@example.com")
        resent_token = self.invite_tokens_from_mail()["reader@example.com"]
        self.assertEqual(self.post(reader, "accept_invite", token=resent_token)["code"], 1)


class Test_TeamConcurrentJoins(TeamClientMixin, TransactionTestCase):
    def accept_at_once(self, team, token):
        """apps/team/tests.py: two new accounts accept the same token. The first holds the team row while it
        joins, and the second, already inside its own request, has to wait for it. Returns both responses."""
        first_client = self.client_for(User.objects.create_user(username="first"))
        second_client = self.client_for(User.objects.create_user(username="second"))
        return self.while_held(
            team.lock,
            lambda: json.decode(second_client.post("/team/accept_invite", {"token": token}).content),
            lambda: json.decode(first_client.post("/team/accept_invite", {"token": token}).content),
        )

    def test_two_people_taking_the_last_seat_at_once_leaves_one_out(self):
        owner = User.objects.create_user(username="owner")
        team = self.create_team(owner, "Desk")
        team.seat_limit = 2
        team.save()

        first_response, second_response = self.accept_at_once(team, self.join_link_token(team, owner))

        self.assertEqual(first_response["code"], 1)
        self.assertEqual(second_response["reason"], "seat_limit")
        self.assertEqual(team.active_members().count(), 2)

    def test_two_people_using_one_email_invite_at_once_lets_one_in(self):
        owner = User.objects.create_user(username="owner")
        team = self.create_team(owner, "Desk")
        self.post(owner, "invite", team_id=team.pk, emails="shared@example.com")

        first_response, second_response = self.accept_at_once(
            team, self.invite_tokens_from_mail()["shared@example.com"]
        )

        self.assertEqual(first_response["code"], 1)
        self.assertEqual(second_response["reason"], "invite_used")
        self.assertEqual(team.active_members().count(), 2)

    def test_one_account_accepting_two_teams_at_once_joins_only_one(self):
        reader = User.objects.create_user(username="reader")
        alpha_owner = User.objects.create_user(username="alphaowner")
        beta_owner = User.objects.create_user(username="betaowner")
        alpha_token = self.join_link_token(self.create_team(alpha_owner, "Alpha"), alpha_owner)
        beta_token = self.join_link_token(self.create_team(beta_owner, "Beta"), beta_owner)
        beta_client = self.client_for(reader)
        beta_results = []

        def accept_beta_in_another_request():
            try:
                beta_results.append(
                    json.decode(beta_client.post("/team/accept_invite", {"token": beta_token}).content)
                )
            finally:
                connection.close()

        beta_request = threading.Thread(target=accept_beta_in_another_request)
        try:
            with transaction.atomic():
                # Alpha's join is written but not committed, so Beta's check for another team cannot see it.
                alpha_response = json.decode(
                    self.client_for(reader).post("/team/accept_invite", {"token": alpha_token}).content
                )
                beta_request.start()
                beta_request.join(timeout=1)
                self.assertTrue(
                    beta_request.is_alive(), "accept_invite let one account join two teams at once"
                )
        finally:
            beta_request.join(timeout=10)

        self.assertEqual(alpha_response["code"], 1)
        self.assertEqual(beta_results[0]["reason"], "already_on_team")
        self.assertEqual(team_owner_id(reader), alpha_owner.pk)


class Test_TeamConcurrentChanges(TeamClientMixin, TransactionTestCase):
    def request(self, user, path, **data):
        return lambda: json.decode(self.client_for(user).post("/team/%s" % path, data).content)

    def test_a_transfer_and_a_leave_at_once_keep_an_owner(self):
        owner = User.objects.create_user(username="owner")
        member = User.objects.create_user(username="member")
        team = self.create_team(owner, "Desk")
        self.add_member(team, member)

        # The member's leave passes its role check, then waits while the owner hands them the team.
        transfer_response, leave_response = self.while_held(
            team.lock,
            self.request(member, "leave", team_id=team.pk),
            self.request(owner, "transfer_ownership", team_id=team.pk, user_id=member.pk),
        )

        self.assertEqual(transfer_response["code"], 1)
        self.assertEqual(leave_response["reason"], "owner_cannot_leave")
        team.refresh_from_db()
        self.assertEqual(team.owner, member)
        self.assertEqual(team.active_members().get(role=TeamMember.ROLE_OWNER).user, member)

    def test_two_invites_to_one_address_at_once_leave_one_live_invite(self):
        owner = User.objects.create_user(username="owner")
        team = self.create_team(owner, "Desk")

        self.while_held(
            team.lock,
            self.request(owner, "invite", team_id=team.pk, emails="shared@example.com"),
            self.request(owner, "invite", team_id=team.pk, emails="shared@example.com"),
        )

        self.assertEqual(team.pending_invites().filter(email="shared@example.com").count(), 1)

    def test_two_teams_with_one_name_at_once_both_get_made(self):
        first = User.objects.create_user(username="first", is_staff=True)
        second = User.objects.create_user(username="second", is_staff=True)

        # The first team's slug is written but not committed, so the second picks the same one and waits on it.
        _, second_response = self.while_held(
            self.request(first, "create", name="Desk"), self.request(second, "create", name="Desk")
        )

        self.assertEqual(second_response["code"], 1)
        self.assertEqual(sorted(Team.objects.values_list("slug", flat=True)), ["desk", "desk-2"])


class Test_TeamRoles(TeamClientMixin, TestCase):
    def setUp(self):
        super().setUp()
        self.owner = User.objects.create_user(username="owner")
        self.manager = User.objects.create_user(username="manager")
        self.member = User.objects.create_user(username="member")
        self.other_member = User.objects.create_user(username="othermember")
        self.team = self.create_team(self.owner, "Newsroom")
        self.add_member(self.team, self.manager, TeamMember.ROLE_MANAGER)
        self.add_member(self.team, self.member)
        self.add_member(self.team, self.other_member)

    def assert_refused(self, user, path, **data):
        response = self.post(user, path, team_id=self.team.pk, **data)
        self.assertEqual(response.get("reason"), "not_allowed", path)

    def roles(self):
        return dict(self.team.active_members().values_list("user__username", "role"))

    def test_a_member_can_only_leave(self):
        self.post(self.owner, "invite", team_id=self.team.pk, emails="friend@example.com")
        pending = TeamInvite.objects.get(email="friend@example.com")
        roles_before = self.roles()

        self.assert_refused(self.member, "rename", name="Taken over")
        self.assert_refused(self.member, "invite", emails="stranger@example.com")
        self.assert_refused(self.member, "revoke_invite", invite_id=pending.pk)
        self.assert_refused(self.member, "join_link")
        self.assert_refused(self.member, "revoke_join_link")
        self.assert_refused(self.member, "remove_member", user_id=self.other_member.pk)
        self.assert_refused(self.member, "change_role", user_id=self.member.pk, role="manager")
        self.assert_refused(self.member, "transfer_ownership", user_id=self.member.pk)
        self.assertEqual(self.get(self.member, "activity", team_id=self.team.pk)["reason"], "not_allowed")

        self.team.refresh_from_db()
        self.assertEqual(self.team.name, "Newsroom")
        self.assertEqual(self.roles(), roles_before)
        self.assertEqual(list(self.team.pending_invites()), [pending])
        self.assertIsNone(self.team.live_join_link())
        self.assertEqual(self.post(self.member, "leave", team_id=self.team.pk)["code"], 1)

    def test_a_manager_runs_membership_but_not_roles_ownership_or_the_name(self):
        other_manager = User.objects.create_user(username="othermanager")
        self.add_member(self.team, other_manager, TeamMember.ROLE_MANAGER)

        response = self.post(self.manager, "invite", team_id=self.team.pk, emails="friend@example.com")
        self.assertEqual(response["code"], 1)
        response = self.post(
            self.manager, "remove_member", team_id=self.team.pk, user_id=self.other_member.pk
        )
        self.assertEqual(response["code"], 1)
        roles_before = self.roles()

        self.assert_refused(self.manager, "rename", name="Taken over")
        self.assert_refused(self.manager, "invite", emails="boss@example.com", role="manager")
        response = self.post(
            self.manager, "invite", team_id=self.team.pk, emails="boss@example.com", role="owner"
        )
        self.assertEqual(response["code"], -1)
        self.assert_refused(self.manager, "change_role", user_id=self.member.pk, role="manager")
        self.assert_refused(self.manager, "transfer_ownership", user_id=self.manager.pk)
        self.assert_refused(self.manager, "remove_member", user_id=other_manager.pk)

        self.team.refresh_from_db()
        self.assertEqual(self.team.name, "Newsroom")
        self.assertEqual(self.roles(), roles_before)
        self.assertFalse(TeamInvite.objects.filter(email="boss@example.com").exists())

    def test_the_team_always_has_exactly_one_owner(self):
        response = self.post(self.owner, "leave", team_id=self.team.pk)
        self.assertEqual(response["reason"], "owner_cannot_leave")
        self.assert_refused(self.owner, "remove_member", user_id=self.owner.pk)
        self.assert_refused(self.manager, "remove_member", user_id=self.owner.pk)
        self.assert_refused(self.owner, "change_role", user_id=self.owner.pk, role="manager")
        response = self.post(
            self.owner, "change_role", team_id=self.team.pk, user_id=self.manager.pk, role="owner"
        )
        self.assertEqual(response["code"], -1)

        owners = [username for username, role in self.roles().items() if role == TeamMember.ROLE_OWNER]
        self.assertEqual(owners, ["owner"])

    def test_the_owner_promotes_and_demotes_teammates(self):
        self.post(self.owner, "change_role", team_id=self.team.pk, user_id=self.member.pk, role="manager")
        response = self.post(
            self.owner, "change_role", team_id=self.team.pk, user_id=self.manager.pk, role="member"
        )

        self.assertEqual(response["code"], 1)
        self.assertEqual(
            self.roles(),
            {"owner": "owner", "manager": "member", "member": "manager", "othermember": "member"},
        )

    def test_transferring_ownership_hands_over_every_owner_power(self):
        response = self.post(self.owner, "transfer_ownership", team_id=self.team.pk, user_id=self.member.pk)

        roles = {member["username"]: member["role"] for member in response["team"]["members"]}
        self.assertEqual(roles["member"], TeamMember.ROLE_OWNER)
        self.assertEqual(roles["owner"], TeamMember.ROLE_MANAGER)
        self.assertEqual(list(roles.values()).count(TeamMember.ROLE_OWNER), 1)
        self.team.refresh_from_db()
        self.assertEqual(self.team.owner, self.member)
        self.assertEqual(
            {team_owner_id(user) for user in (self.owner, self.manager, self.member)}, {self.member.pk}
        )
        self.assert_refused(self.owner, "rename", name="Old owner's name")
        self.assertEqual(self.post(self.member, "rename", team_id=self.team.pk, name="Desk")["code"], 1)
        self.assertEqual(self.post(self.owner, "leave", team_id=self.team.pk)["code"], 1)

    def test_another_teams_owner_cannot_reach_into_this_team(self):
        outsider = User.objects.create_user(username="outsider")
        other_team = self.create_team(outsider, "Elsewhere")
        self.post(self.owner, "invite", team_id=self.team.pk, emails="friend@example.com")
        pending = TeamInvite.objects.get(email="friend@example.com")

        response = self.post(outsider, "revoke_invite", team_id=other_team.pk, invite_id=pending.pk)
        self.assertEqual(response["reason"], "not_found")
        response = self.post(outsider, "remove_member", team_id=other_team.pk, user_id=self.member.pk)
        self.assertEqual(response["reason"], "not_found")
        response = self.post(
            outsider, "change_role", team_id=other_team.pk, user_id=self.member.pk, role="manager"
        )
        self.assertEqual(response["reason"], "not_found")
        response = self.post(outsider, "transfer_ownership", team_id=other_team.pk, user_id=self.member.pk)
        self.assertEqual(response["reason"], "not_found")
        response = self.post(outsider, "rename", team_id=self.team.pk, name="Mine now")
        self.assertEqual(response["reason"], "not_found")

        self.assertEqual(list(self.team.pending_invites()), [pending])
        self.assertEqual(self.roles()["member"], TeamMember.ROLE_MEMBER)


class Test_TeamInvites(TeamClientMixin, TestCase):
    def setUp(self):
        super().setUp()
        self.owner = User.objects.create_user(username="owner")
        self.team = self.create_team(self.owner, "Newsroom")

    def test_an_invite_email_lets_any_account_join_once(self):
        response = self.post(
            self.owner, "invite", team_id=self.team.pk, emails="Ana@Example.com, bo@example.com"
        )
        self.assertEqual(response["code"], 1)
        tokens = self.invite_tokens_from_mail()
        self.assertEqual(set(tokens), {"ana@example.com", "bo@example.com"})

        # The account's own email doesn't have to match the invited address.
        holder = User.objects.create_user(username="holder", email="holder@elsewhere.org")
        self.assertEqual(self.post(holder, "accept_invite", token=tokens["ana@example.com"])["code"], 1)

        latecomer = User.objects.create_user(username="latecomer")
        response = self.post(latecomer, "accept_invite", token=tokens["ana@example.com"])
        self.assertEqual(response["reason"], "invite_used")

    def test_a_list_with_a_bad_address_sends_nothing(self):
        response = self.post(
            self.owner, "invite", team_id=self.team.pk, emails="good@example.com, not-an-address"
        )

        self.assertEqual(response["reason"], "invalid_email")
        self.assertEqual(response["invalid_emails"], ["not-an-address"])
        self.assertEqual(mail.outbox, [])
        self.assertFalse(TeamInvite.objects.exists())

    def test_expired_and_revoked_invites_are_refused(self):
        self.post(self.owner, "invite", team_id=self.team.pk, emails="late@example.com, revoked@example.com")
        tokens = self.invite_tokens_from_mail()
        TeamInvite.objects.filter(email="late@example.com").update(
            expire_date=datetime.datetime.now() - datetime.timedelta(minutes=1)
        )
        revoked = TeamInvite.objects.get(email="revoked@example.com")
        self.assertEqual(
            self.post(self.owner, "revoke_invite", team_id=self.team.pk, invite_id=revoked.pk)["code"], 1
        )
        joiner = User.objects.create_user(username="joiner")

        response = self.post(joiner, "accept_invite", token=tokens["late@example.com"])
        self.assertEqual(response["reason"], "invite_expired")
        response = self.post(joiner, "accept_invite", token=tokens["revoked@example.com"])
        self.assertEqual(response["reason"], "invite_revoked")
        response = self.get(None, "invite_preview", token=tokens["late@example.com"])
        self.assertEqual(response["reason"], "invite_expired")
        self.assertEqual(self.team.active_members().count(), 1)

    def test_regenerating_or_revoking_the_join_link_retires_it(self):
        old_token = self.join_link_token(self.team, self.owner)
        new_token = self.join_link_token(self.team, self.owner)
        first = User.objects.create_user(username="first")
        second = User.objects.create_user(username="second")
        third = User.objects.create_user(username="third")

        self.assertEqual(self.post(first, "accept_invite", token=old_token)["reason"], "invite_revoked")
        self.assertEqual(self.post(first, "accept_invite", token=new_token)["code"], 1)
        self.assertEqual(self.post(second, "accept_invite", token=new_token)["code"], 1)

        self.post(self.owner, "revoke_join_link", team_id=self.team.pk)
        self.assertEqual(self.post(third, "accept_invite", token=new_token)["reason"], "invite_revoked")

    def test_the_preview_is_open_before_login_but_joining_is_not(self):
        token = self.join_link_token(self.team, self.owner)

        preview = self.get(None, "invite_preview", token=token)["invite"]
        self.assertEqual(preview["team_name"], "Newsroom")
        self.assertNotIn("own_plan", preview)
        response = self.client_for(None).post("/team/accept_invite", {"token": token})
        self.assertEqual(response.status_code, 403)
        self.assertEqual(self.team.active_members().count(), 1)

    def test_a_team_cannot_send_unlimited_invite_emails(self):
        with patch.object(Team, "EMAIL_INVITES_PER_DAY", 2):
            response = self.post(
                self.owner, "invite", team_id=self.team.pk, emails="a@example.com, b@example.com"
            )
            self.assertEqual(response["code"], 1)
            response = self.post(self.owner, "invite", team_id=self.team.pk, emails="c@example.com")
            self.assertEqual(response["reason"], "invite_limit")
            response = self.post(self.owner, "invite", team_id=self.team.pk, emails="a@example.com")
            self.assertEqual(response["reason"], "invite_limit")

        self.assertEqual(len(mail.outbox), 2)

    def test_invitee_addresses_stay_out_of_the_logs(self):
        with self.assertLogs("newsblur", level="INFO") as logs:
            self.post(self.owner, "invite", team_id=self.team.pk, emails="private@example.com")
            pending = TeamInvite.objects.get(email="private@example.com")
            self.post(self.owner, "revoke_invite", team_id=self.team.pk, invite_id=pending.pk)

        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual([line for line in logs.output if "private@example.com" in line], [])
        revoked = self.get(self.owner, "activity", team_id=self.team.pk)["activities"][0]
        self.assertEqual(revoked["details"]["email"], "private@example.com")

    def test_invite_emails_are_queued_one_per_invite_once_the_invites_commit(self):
        queued = self.patch(SendTeamInviteEmail, "delay")
        commit_callbacks = len(connection.run_on_commit)

        response = self.client_for(self.owner).post(
            "/team/invite", {"team_id": self.team.pk, "emails": "ana@example.com, bo@example.com"}
        )
        self.assertEqual(json.decode(response.content)["code"], 1)
        queued.assert_not_called()
        for _, callback in connection.run_on_commit[commit_callbacks:]:
            callback()

        invite_ids = TeamInvite.objects.filter(team=self.team, kind=TeamInvite.KIND_EMAIL).values_list(
            "pk", flat=True
        )
        self.assertEqual(
            sorted(call.kwargs["invite_id"] for call in queued.call_args_list), sorted(invite_ids)
        )


class Test_TeamCreate(TeamClientMixin, TestCase):
    def test_only_staff_start_a_team_and_an_account_owns_one(self):
        reader = User.objects.create_user(username="reader")
        staff = User.objects.create_user(username="staffer", is_staff=True)

        self.assertEqual(self.post(reader, "create", name="Desk")["reason"], "not_allowed")
        response = self.post(staff, "create", name="Desk")
        self.assertEqual(response["team"]["role"], TeamMember.ROLE_OWNER)
        self.assertEqual(team_owner_id(staff), staff.pk)

        self.assertEqual(self.post(staff, "create", name="Second desk")["reason"], "already_owns_team")
        self.assertEqual(Team.objects.count(), 1)

    def test_a_team_name_and_every_invite_subject_stay_on_one_line(self):
        staff = User.objects.create_user(username="staffer", is_staff=True)

        response = self.post(staff, "create", name="Desk\r\nBcc: someone@example.com")
        self.assertEqual(response["reason"], "invalid_name")
        team = self.create_team(staff, "Desk")
        self.assertEqual(
            self.post(staff, "rename", team_id=team.pk, name="Desk\nTwo")["reason"], "invalid_name"
        )

        # A name saved with a line break before names were checked still sends a one line subject.
        Team.objects.filter(pk=team.pk).update(name="Desk\nTwo")
        self.assertEqual(self.post(staff, "invite", team_id=team.pk, emails="friend@example.com")["code"], 1)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].subject.splitlines(), [mail.outbox[0].subject])


class Test_TeamOneTeamPerAccount(TeamClientMixin, TestCase):
    def setUp(self):
        super().setUp()
        self.alpha_owner = User.objects.create_user(username="alphaowner")
        self.beta_owner = User.objects.create_user(username="betaowner")
        self.alpha = self.create_team(self.alpha_owner, "Alpha")
        self.beta = self.create_team(self.beta_owner, "Beta")
        self.alpha_link = self.join_link_token(self.alpha, self.alpha_owner)
        self.beta_link = self.join_link_token(self.beta, self.beta_owner)

    def test_a_member_joins_another_team_only_after_leaving_and_can_come_back(self):
        staffer = User.objects.create_user(username="staffer", is_staff=True)
        self.post(staffer, "accept_invite", token=self.alpha_link)

        self.assertEqual(
            self.post(staffer, "accept_invite", token=self.beta_link)["reason"], "already_on_team"
        )
        self.assertEqual(self.post(staffer, "create", name="Mine")["reason"], "already_on_team")
        self.assertEqual(self.beta.active_members().count(), 1)
        self.assertEqual(team_owner_id(staffer), self.alpha_owner.pk)

        self.post(staffer, "leave", team_id=self.alpha.pk)
        self.assertIsNone(team_owner_id(staffer))
        self.assertEqual(self.post(staffer, "accept_invite", token=self.beta_link)["code"], 1)
        self.assertEqual(team_owner_id(staffer), self.beta_owner.pk)

        self.post(staffer, "leave", team_id=self.beta.pk)
        self.assertEqual(self.post(staffer, "accept_invite", token=self.alpha_link)["code"], 1)
        self.assertEqual(team_owner_id(staffer), self.alpha_owner.pk)

    def test_an_owner_cannot_join_another_team(self):
        response = self.post(self.alpha_owner, "accept_invite", token=self.beta_link)

        self.assertEqual(response["reason"], "already_on_team")
        self.assertEqual(self.beta.active_members().count(), 1)
        self.assertEqual(team_owner_id(self.alpha_owner), self.alpha_owner.pk)


class Test_TeamLoad(TeamClientMixin, TestCase):
    def test_only_the_owner_and_managers_see_pending_invites_and_the_join_link(self):
        owner = User.objects.create_user(username="owner")
        manager = User.objects.create_user(username="manager")
        member = User.objects.create_user(username="member")
        outsider = User.objects.create_user(username="outsider")
        team = self.create_team(owner)
        self.add_member(team, manager, TeamMember.ROLE_MANAGER)
        self.add_member(team, member)
        self.post(owner, "invite", team_id=team.pk, emails="pending@example.com")
        self.join_link_token(team, owner)

        for user in (owner, manager):
            loaded = self.get(user, "")["team"]
            self.assertEqual([invite["email"] for invite in loaded["invites"]], ["pending@example.com"])
            self.assertIn("team_invite=", loaded["join_link"]["url"])
        loaded = self.get(member, "")["team"]
        self.assertNotIn("invites", loaded)
        self.assertNotIn("join_link", loaded)
        self.assertIsNone(self.get(outsider, "")["team"])


class Test_TeamActivity(TeamClientMixin, TestCase):
    def test_the_activity_log_lists_changes_newest_first_a_page_at_a_time(self):
        owner = User.objects.create_user(username="owner")
        member = User.objects.create_user(username="member")
        team = self.create_team(owner, "Newsroom")
        self.post(member, "accept_invite", token=self.join_link_token(team, owner))
        self.post(owner, "remove_member", team_id=team.pk, user_id=member.pk)

        with patch.object(TeamActivity, "PAGE_SIZE", 3):
            first_page = self.get(owner, "activity", team_id=team.pk)
            second_page = self.get(owner, "activity", team_id=team.pk, page=2)

        self.assertEqual(
            [entry["action"] for entry in first_page["activities"]],
            ["member_removed", "member_joined", "join_link_created"],
        )
        self.assertTrue(first_page["has_more"])
        self.assertEqual([entry["action"] for entry in second_page["activities"]], ["team_created"])
        self.assertFalse(second_page["has_more"])


class TeamProMixin(TeamClientMixin):
    def setUp(self):
        super().setUp()
        self.now = datetime.datetime.now()
        self.welcome_tasks = [
            self.patch(task, "delay")
            for task in (EmailNewPremium, EmailNewPremiumPro, EmailStaffPremiumUpgrade)
        ]
        for task in (EmailStaffNotification, EmailReferralCredit):
            self.patch(task, "delay")
        self.owner = User.objects.create_user(username="owner", email="owner@example.com")
        self.team = self.create_team(self.owner)
        self.token = self.join_link_token(self.team, self.owner)

    def days(self, count):
        return datetime.timedelta(days=count)

    def reader(self, username, plan="free", premium_expire=None, feeds=0):
        user = User.objects.create_user(username=username, email="%s@example.com" % username)
        Profile.objects.filter(user=user).update(premium_expire=premium_expire, **PLANS[plan])
        for number in range(feeds):
            feed = Feed.objects.create(feed_address="https://%s.example/%s" % (username, number))
            UserSubscription.objects.create(user=user, feed=feed, active=plan != "free")
        return user

    def plan_of(self, user):
        flags = Profile.objects.filter(user=user).values(*PLANS["free"]).get()
        return next((name for name, plan_flags in PLANS.items() if plan_flags == flags), flags)

    def premium_expire(self, user):
        return Profile.objects.get(user=user).premium_expire

    def muted_sites(self, user):
        return UserSubscription.objects.filter(user=user, active=False).count()

    def join(self, user, token=None):
        self.assertEqual(self.post(user, "accept_invite", token=token or self.token)["code"], 1)

    def leave(self, user, team=None):
        self.assertEqual(self.post(user, "leave", team_id=(team or self.team).pk)["code"], 1)

    def mail_to(self, user):
        return [message for message in mail.outbox if user.email in message.to[0]]

    def pay(
        self,
        user,
        paid_through,
        plan=Team.PLAN_TEAM,
        provider=Team.PROVIDER_STRIPE,
        reference="sub_team",
        paid_at=None,
    ):
        """apps/team/tests.py: a payment the provider confirmed, made at paid_at or else now."""
        return self.committed(
            record_team_payment,
            user,
            plan,
            provider,
            paid_through,
            reference,
            paid_at or datetime.datetime.now(),
        )

    def lapse(self, owner, days_ago=2):
        """apps/team/tests.py: the owner's team was paid through days_ago, and the hourly task has run since."""
        Team.objects.filter(owner=owner).update(paid_through=self.now - self.days(days_ago))
        self.committed(TeamProGrants)

    def committed(self, change, *args, **kwargs):
        """apps/team/tests.py: a change with what it queued for after its commit run in place, as the commit at the
        end of a real webhook or task would."""
        queued = len(connection.run_on_commit)
        result = change(*args, **kwargs)
        callbacks = connection.run_on_commit[queued:]
        del connection.run_on_commit[queued:]
        for _, callback in callbacks:
            callback()
        return result

    def profile_post(self, user, path, **data):
        """apps/team/tests.py: a POST to /profile/, with what it queued for after its commit run in place."""
        return self.committed(self.client_for(user).post, "/profile/%s" % path, data)

    def owned_team(self, user):
        return Team.objects.filter(owner=user).first()

    def staff_events(self):
        return [call.kwargs["event_type"] for call in EmailStaffNotification.delay.call_args_list]


class Test_TeamProSeat(TeamProMixin, TestCase):
    def test_joining_gives_pro_without_welcome_emails_or_payment_rows(self):
        expired = self.now - self.days(100)
        reader = self.reader("reader", "free", premium_expire=expired, feeds=2)

        self.join(reader)

        self.assertEqual(self.plan_of(reader), "pro")
        self.assertEqual(self.premium_expire(reader), expired)
        self.assertEqual(self.muted_sites(reader), 0)
        self.assertTrue(Profile.objects.get(user=reader).can_register_oauth_application)
        self.assertFalse(PaymentHistory.objects.filter(user=reader).exists())
        self.assertEqual(mail.outbox, [])
        for task in self.welcome_tasks:
            task.assert_not_called()

    def test_only_a_free_account_gets_its_muted_sites_back(self):
        paying = self.reader("paying", "premium", premium_expire=self.now + self.days(100), feeds=2)
        trial = self.reader("trial", "trial", premium_expire=self.now + self.days(20), feeds=2)
        free = self.reader("free", "free", feeds=2)
        for user in (paying, trial):
            UserSubscription.objects.filter(user=user, feed__feed_address__endswith="/0").update(active=False)

        for user in (paying, trial, free):
            self.join(user)
        self.assertEqual([self.muted_sites(user) for user in (paying, trial, free)], [1, 1, 0])

    def test_leaving_or_being_removed_ends_pro_at_once_with_one_email(self):
        leaver = self.reader("leaver", "free", feeds=2)
        removed = self.reader("removed", "free", feeds=2)
        for user in (leaver, removed):
            self.join(user)

        self.leave(leaver)
        self.post(self.owner, "remove_member", team_id=self.team.pk, user_id=removed.pk)

        for user in (leaver, removed):
            self.assertEqual(self.plan_of(user), "free")
            self.assertEqual(self.muted_sites(user), 2)
        TeamProGrants()
        for user in (leaver, removed):
            self.assertEqual(self.plan_of(user), "free")
            self.assertEqual(len(self.mail_to(user)), 1)

        # A second seat starts from the plan they have on their own, never from team Pro.
        self.join(leaver)
        self.leave(leaver)
        self.assertEqual(self.plan_of(leaver), "free")

    def test_leaving_returns_each_teammate_to_their_own_plan_and_says_which(self):
        paid_through = self.now + self.days(200)
        trial_end = self.now + self.days(20)
        paying = self.reader("paying", "archive", premium_expire=paid_through, feeds=2)
        trial = self.reader("trial", "trial", premium_expire=trial_end)
        ran_out = self.reader("ranout", "archive", premium_expire=self.now + self.days(5))
        readers = (paying, trial, ran_out)
        for user in readers:
            self.join(user)
        # The plan ranout paid for themselves ran out while they were on the team.
        Profile.objects.filter(user=ran_out).update(premium_expire=self.now - self.days(1))

        for user in readers:
            self.leave(user)

        self.assertEqual([self.plan_of(user) for user in readers], ["archive", "trial", "free"])
        self.assertEqual(self.premium_expire(paying), paid_through)
        self.assertEqual(self.muted_sites(paying), 0)
        [paying_email], [trial_email], [ran_out_email] = [self.mail_to(user) for user in readers]
        self.assertIn("Premium Archive", paying_email.body)
        self.assertIn(dateformat.format(trial_end, "F j, Y"), trial_email.body)
        self.assertIn("next=feedchooser", ran_out_email.body)
        self.assertNotIn("Premium Archive", ran_out_email.body)

    def test_a_failed_leave_keeps_the_seat_and_its_pro_and_sends_nothing(self):
        reader = self.reader("reader", "free")
        self.join(reader)
        queued = len(connection.run_on_commit)

        with patch.object(TeamActivity, "log", side_effect=DatabaseError("connection lost")):
            with self.assertRaises(DatabaseError):
                TeamMember.active_membership(reader).leave()
        for _, callback in connection.run_on_commit[queued:]:
            callback()

        self.assertIsNotNone(TeamMember.active_membership(reader))
        self.assertEqual(self.plan_of(reader), "pro")
        self.assertEqual(mail.outbox, [])

    def test_a_failed_grant_leaves_no_seat_without_pro(self):
        reader = self.reader("reader", "free")

        with patch("apps.team.grants.grant_team_pro", side_effect=DatabaseError("connection lost")):
            with self.assertRaises(DatabaseError):
                self.team.live_join_link().accept(reader)

        self.assertIsNone(TeamMember.active_membership(reader))


class Test_TeamProOwnPlans(TeamProMixin, TestCase):
    """A plan the teammate gets, loses or renews on their own during the seat is the one they go back to."""

    def test_a_store_expiry_during_the_seat_keeps_team_pro_and_ends_the_own_plan(self):
        reader = self.reader("reader", "premium", premium_expire=self.now + self.days(10), feeds=2)
        self.join(reader)

        Profile.objects.get(user=reader).deactivate_premium()
        self.assertEqual(self.plan_of(reader), "pro")
        self.assertEqual(self.muted_sites(reader), 0)

        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "free")

    def test_archive_gifted_during_the_seat_is_kept_after_it(self):
        reader = self.reader("reader", "trial", premium_expire=self.now + self.days(20))
        self.join(reader)
        gift = MGiftCode.objects.create(
            gifting_user_id=self.owner.pk, gift_code="TEAMGIFT", payment_amount=99, gift_tier="archive"
        )
        self.addCleanup(gift.delete)
        self.addCleanup(lambda: MRedeemedCode.objects.filter(gift_code="TEAMGIFT").delete())

        MRedeemedCode.redeem(reader, "TEAMGIFT")
        self.assertEqual(self.plan_of(reader), "pro")
        self.assertEqual(mail.outbox, [])

        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "archive")
        self.assertGreater(self.premium_expire(reader), self.now + self.days(300))

    def test_a_payment_synced_during_the_seat_is_kept_after_it(self):
        reader = self.reader("reader", "free")
        self.join(reader)
        PaymentHistory.objects.create(
            user=reader, payment_date=self.now, payment_amount=36, payment_provider="paypal"
        )

        Profile.objects.get(user=reader).setup_premium_history()
        self.assertEqual(self.plan_of(reader), "pro")

        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "premium")

    def test_an_app_store_renewal_during_the_seat_is_kept_after_it(self):
        now = self.now.replace(microsecond=0)
        reader = self.reader("reader", "premium", premium_expire=now + self.days(5))
        PaymentHistory.objects.create(
            user=reader,
            payment_date=now - self.days(360),
            payment_amount=36,
            payment_provider="ios-subscription",
            payment_identifier="2000000000001",
        )
        self.join(reader)
        purchase = now - self.days(1)
        expiration = purchase + self.days(365)

        result = apply_verified_apple_transaction(
            {
                "environment": "Production",
                "productId": "newsblur_premium_auto_renew_36",
                "transactionId": "2000000000002",
                "originalTransactionId": "2000000000001",
                "purchaseDate": int(purchase.timestamp() * 1000),
                "expiresDate": int(expiration.timestamp() * 1000),
            },
            now=now,
        )
        self.assertEqual(result["status"], "processed")
        self.assertEqual(self.plan_of(reader), "pro")

        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "premium")
        self.assertEqual(self.premium_expire(reader), expiration)

    def test_referral_credit_follows_the_teammates_own_plan(self):
        reader = self.reader("reader", "free")
        friend = User.objects.create_user(username="friend")
        self.addCleanup(lambda: MReferral.objects(referred_user_id=friend.pk).delete())
        self.join(reader)

        MReferral.create_referral(reader.pk, friend.pk, friend.username)
        MReferral.award_credit(friend.pk, 36, "premium")

        # A year of Premium credit for a $36 referral, not the two months it would buy at Pro's price.
        self.assertGreater(self.premium_expire(reader), self.now + self.days(300))
        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "premium")


class Test_TeamProPremiumExpire(TeamProMixin, TestCase):
    def test_the_nightly_expiry_leaves_teammates_and_active_team_owners_alone(self):
        trial_joiner = self.reader("trialjoiner", "trial", premium_expire=self.now - self.days(1))
        lapsed = self.reader("lapsed", "premium", premium_expire=self.now - self.days(10), feeds=1)
        long_lapsed = self.reader("longlapsed", "premium", premium_expire=self.now - self.days(40))
        for user in (trial_joiner, lapsed, long_lapsed):
            self.join(user)
        Profile.objects.filter(user=self.owner).update(
            is_premium_trial=False, premium_expire=self.now - self.days(40)
        )
        outsider = self.reader("outsider", "premium", premium_expire=self.now - self.days(40))

        PremiumExpire()

        for user, days_ago in ((trial_joiner, 1), (lapsed, 10), (long_lapsed, 40)):
            self.assertEqual(self.plan_of(user), "pro")
            self.assertEqual(self.premium_expire(user), self.now - self.days(days_ago))
        self.assertEqual(self.plan_of(self.owner), "pro")
        # Someone on no team still expires as before.
        self.assertEqual(self.plan_of(outsider), "free")
        self.assertEqual([message.to for message in mail.outbox], [["outsider <outsider@example.com>"]])

        # The plan that ran out during the seat ends with the seat, with no further 30 days.
        self.leave(lapsed)
        self.assertEqual(self.plan_of(lapsed), "free")
        self.assertEqual(self.muted_sites(lapsed), 1)

    def test_a_team_nobody_pays_for_spares_no_one(self):
        # Neither paid through a date nor a comp, like a team started before teams were billed.
        Team.objects.filter(pk=self.team.pk).update(billing_provider=None, paid_through=None)
        reader = self.reader("reader", "free", feeds=1)
        self.join(reader)
        # The owner's own trial ran out 40 days ago.
        Profile.objects.filter(user=self.owner).update(premium_expire=self.now - self.days(40))
        TeamProGrant.objects.filter(user=self.owner).update(own_trial_expire=self.now - self.days(40))

        # The hourly task lapses the team first, and the nightly expiry then reaches its owner.
        TeamProGrants()
        PremiumExpire()

        self.assertEqual(self.plan_of(self.owner), "free")
        self.assertEqual(self.plan_of(reader), "free")
        self.team.refresh_from_db()
        self.assertEqual(self.team.status, Team.STATUS_INACTIVE)


class Test_TeamProStaleProfiles(TeamProMixin, TestCase):
    """A request or task that loaded a teammate's profile before their seat began or ended, and saves the whole
    row after, leaves the plan as the seat left it."""

    def test_a_profile_saved_after_leaving_does_not_give_pro_back(self):
        # An account that never paid has no premium_expire, so nothing would ever take back a Pro written here.
        reader = self.reader("reader", "free")
        self.join(reader)
        stale_profile = Profile.objects.get(user=reader)

        self.leave(reader)
        stale_profile.save()

        self.assertEqual(self.plan_of(reader), "free")

    def test_a_profile_saved_after_joining_does_not_take_pro_away(self):
        reader = self.reader("reader", "trial", premium_expire=self.now + self.days(20))
        stale_profile = Profile.objects.get(user=reader)

        self.join(reader)
        stale_profile.save()

        self.assertEqual(self.plan_of(reader), "pro")


class Test_TeamLapse(TeamProMixin, TestCase):
    def roles(self):
        return dict(self.team.active_members().values_list("user__username", "role"))

    def test_a_lapse_ends_pro_at_once_and_a_payment_brings_it_back(self):
        free_reader = self.reader("freereader", "free", feeds=2)
        archive_reader = self.reader("archivereader", "archive", premium_expire=self.now + self.days(100))
        leaver = self.reader("leaver", "free")
        for user in (free_reader, archive_reader, leaver):
            self.join(user)
        self.post(self.owner, "change_role", team_id=self.team.pk, user_id=archive_reader.pk, role="manager")
        self.post(self.owner, "remove_member", team_id=self.team.pk, user_id=leaver.pk)
        roles = self.roles()
        Team.objects.filter(pk=self.team.pk).update(paid_through=self.now - self.days(2))
        mail.outbox = []

        self.committed(TeamProGrants)
        self.committed(TeamProGrants)

        self.team.refresh_from_db()
        self.assertEqual(self.team.status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(free_reader), "free")
        self.assertEqual(self.muted_sites(free_reader), 2)
        self.assertEqual(self.plan_of(archive_reader), "archive")
        self.assertIsNone(team_owner_id(free_reader))
        # One email each to everyone still on the team, and none to the teammate removed before the lapse.
        self.assertEqual(
            sorted(message.to[0] for message in mail.outbox),
            sorted("%s <%s>" % (user, user.email) for user in (self.owner, free_reader, archive_reader)),
        )
        self.assertEqual(self.roles(), roles)

        payment = self.pay(self.owner, self.now + self.days(30))

        self.assertTrue(payment.reactivated)
        self.assertEqual(self.plan_of(free_reader), "pro")
        self.assertEqual(self.muted_sites(free_reader), 0)
        self.assertEqual(self.plan_of(archive_reader), "pro")
        self.assertEqual(team_owner_id(free_reader), self.owner.pk)
        self.assertEqual(self.roles(), roles)

    def test_a_teammate_removed_after_the_lapse_gets_no_second_email(self):
        reader = self.reader("reader", "free", feeds=1)
        self.join(reader)
        self.committed(deactivate_team, self.team)

        self.post(self.owner, "remove_member", team_id=self.team.pk, user_id=reader.pk)

        self.assertEqual(len(self.mail_to(reader)), 1)
        self.assertFalse(TeamProGrant.objects.filter(user=reader).exists())
        self.assertEqual(self.plan_of(reader), "free")

    def test_a_failed_plan_ended_email_holds_up_no_other_teammate(self):
        readers = [self.reader(username, "free") for username in ("first", "second", "third")]
        for user in readers:
            self.join(user)
        mail.outbox = []
        send = EmailMultiAlternatives.send
        attempts = []

        def first_send_fails(message, fail_silently=False):
            attempts.append(message.to[0])
            if len(attempts) == 1:
                raise smtplib.SMTPServerDisconnected("connection lost")
            return send(message, fail_silently)

        with patch.object(EmailMultiAlternatives, "send", autospec=True, side_effect=first_send_fails):
            self.committed(deactivate_team, self.team)

        self.assertEqual(
            sorted(message.to[0] for message in mail.outbox),
            sorted("%s <%s>" % (user, user.email) for user in [self.owner] + readers),
        )

    def test_a_payment_before_the_plan_ended_email_goes_out_cancels_it(self):
        reader = self.reader("reader", "free")
        self.join(reader)
        queued = len(connection.run_on_commit)
        deactivate_team(self.team)
        plan_ended_emails = connection.run_on_commit[queued:]
        del connection.run_on_commit[queued:]

        activate_team(self.team)
        for _, send_plan_ended_email in plan_ended_emails:
            send_plan_ended_email()

        self.assertEqual(self.mail_to(reader), [])
        self.assertEqual(self.plan_of(reader), "pro")

    def test_an_inactive_team_takes_no_new_teammates(self):
        self.post(self.owner, "invite", team_id=self.team.pk, emails="invited@example.com")
        invite_token = self.invite_tokens_from_mail()["invited@example.com"]
        deactivate_team(self.team)
        reader = self.reader("reader", "trial", premium_expire=self.now + self.days(20))

        for token in (self.token, invite_token):
            self.assertEqual(self.get(None, "invite_preview", token=token)["reason"], "team_inactive")
            self.assertEqual(self.post(reader, "accept_invite", token=token)["reason"], "team_inactive")
        response = self.post(self.owner, "invite", team_id=self.team.pk, emails="another@example.com")
        self.assertEqual(response["reason"], "team_inactive")
        self.assertEqual(self.post(self.owner, "join_link", team_id=self.team.pk)["reason"], "team_inactive")

        self.assertIsNone(TeamMember.active_membership(reader))
        self.assertEqual(self.plan_of(reader), "trial")
        self.assertFalse(TeamInvite.objects.filter(email="another@example.com").exists())

    def test_deleting_the_owners_account_ends_the_team(self):
        reader = self.reader("reader", "free", feeds=1)
        self.join(reader)

        self.owner.delete()
        TeamProGrants()

        self.assertEqual(self.plan_of(reader), "free")
        self.team.refresh_from_db()
        self.assertEqual(self.team.status, Team.STATUS_INACTIVE)


class Test_TeamProRepairAtOnce(TeamProMixin, TransactionTestCase):
    def test_the_hourly_repair_leaves_alone_a_plan_released_while_it_waited(self):
        reader = self.reader("reader", "archive", premium_expire=self.now + self.days(100))
        self.join(reader)
        # A stale save took the reader's Pro, which makes them one the hourly task repairs.
        Profile.objects.filter(user=reader).update(**PLANS["premium"])

        self.while_held(lambda: release_team_pro(reader), TeamProGrants)

        self.assertEqual(self.plan_of(reader), "archive")


class Test_TeamProFeedSetup(TeamClientMixin, TransactionTestCase):
    """Real commits, so the feed setup a grant starts after it commits runs."""

    def test_joining_starts_the_archive_backfill_only_for_teammates_without_archive(self):
        owner = User.objects.create_user(username="owner")
        token = self.join_link_token(self.create_team(owner), owner)
        # The owner's own Pro started a backfill of its own.
        self.backfill.reset_mock()
        trial_reader = User.objects.create_user(username="trialreader")
        archive_reader = User.objects.create_user(username="archivereader")
        Profile.objects.filter(user=archive_reader).update(is_archive=True, is_premium_trial=False)

        for user in (trial_reader, archive_reader):
            self.assertEqual(self.post(user, "accept_invite", token=token)["code"], 1)

        self.backfill.assert_called_once_with(trial_reader.pk)


USAGE_PRICES = dict(
    STRIPE_PRICE_TEXT_CLASSIFICATION="price_text_classifier",
    STRIPE_PRICE_IMAGE_CLASSIFICATION="price_image_classifier",
)


def stripe_subscription(subscription_id, prices, created=None):
    """apps/team/tests.py: a Stripe subscription as the API returns it, with no top level plan once it has two
    items. It was made a month ago unless created says when."""
    created = created or datetime.datetime.now() - datetime.timedelta(days=30)
    items = [
        {
            "id": "si_%s_%s" % (subscription_id, index),
            "object": "subscription_item",
            "price": {"id": price, "object": "price"},
            "plan": {"id": price, "object": "plan", "active": True},
        }
        for index, price in enumerate(prices)
    ]
    return stripe.Subscription.construct_from(
        {
            "id": subscription_id,
            "object": "subscription",
            "created": int(created.timestamp()),
            "status": "active",
            "cancel_at": None,
            "cancel_at_period_end": False,
            "plan": items[0]["plan"] if len(items) == 1 else None,
            "items": {"object": "list", "data": items},
        },
        "sk_test",
    )


class FakeStripe:
    """apps/team/tests.py: Stripe's API for one customer's subscriptions. Turning off renewal shows on the
    subscription, as it would at Stripe."""

    def __init__(self, test, customer_id, subscriptions):
        self.subscriptions = subscriptions
        customer = MagicMock(id=customer_id, email=None, stripe_id=customer_id)
        test.patch(stripe.Customer, "retrieve", return_value=customer)
        test.patch(stripe.Customer, "list", return_value=[customer])
        test.patch(stripe.Charge, "list", return_value=MagicMock(data=[]))
        test.patch(
            stripe.Subscription, "list", side_effect=lambda **kwargs: MagicMock(data=list(self.subscriptions))
        )
        test.patch(stripe.Subscription, "retrieve", side_effect=self._subscription)
        self.modify = test.patch(stripe.Subscription, "modify", side_effect=self._modify)
        self.cancel = test.patch(stripe.Subscription, "cancel")
        self.delete = test.patch(stripe.Subscription, "delete")
        self.refund = test.patch(stripe.Refund, "create")

    def _subscription(self, subscription_id):
        return next(sub for sub in self.subscriptions if sub.id == subscription_id)

    def _modify(self, subscription_id, cancel_at_period_end=False, **changes):
        if cancel_at_period_end:
            subscription = self._subscription(subscription_id)
            subscription["cancel_at_period_end"] = True
            subscription["cancel_at"] = int(datetime.datetime.now().timestamp())

    def renewals_turned_off(self):
        return [(call.args[0], call.kwargs) for call in self.modify.call_args_list]


class FakePayPal:
    """apps/team/tests.py: PayPal's subscriptions API for one subscription."""

    def __init__(self, test, subscription_id):
        self.subscription_id = subscription_id
        self.status = "ACTIVE"
        self.suspends = True
        self.posts = []
        test.patch(profile_models.paypalrestsdk, "Api", return_value=self)

    def get(self, url):
        if "/transactions" in url:
            return {"transactions": []}
        return {
            "id": self.subscription_id,
            "status": self.status,
            "plan_id": "P-TEAMJOINER",
            "create_time": "2026-03-01T08:00:00Z",
        }

    def post(self, url, data):
        self.posts.append(url)
        if url.endswith("/suspend") and self.suspends:
            self.status = "SUSPENDED"
        return {}


class FakeClassicPayPal:
    """apps/team/tests.py: a subscription made through PayPal's Classic API. The REST API doesn't know it and
    answers ResourceNotFound; the Classic API reads and cancels it."""

    def __init__(self, test):
        self.status = "Active"
        self.changes = []
        test.patch(profile_models.paypalrestsdk, "Api", return_value=self)
        self.classic_api = test.patch(Profile, "paypal_classic_api", return_value=self)

    def get(self, url):
        raise paypalrestsdk.ResourceNotFound(MagicMock())

    def get_recurring_payments_profile_details(self, profileid):
        return {"PROFILEID": profileid, "STATUS": self.status, "PROFILESTARTDATE": "2019-03-01T08:00:00Z"}

    def manage_recurring_payments_profile_status(self, profileid, action, note=None):
        self.changes.append((profileid, action))
        if action == "Cancel":
            self.status = "Cancelled"


@override_settings(**USAGE_PRICES)
class Test_TeamJoinOwnPlan(TeamProMixin, TestCase):
    """What joining does to a plan the teammate pays for on their own."""

    def subscriber(self, username, plan, provider, paid_through):
        user = self.reader(username, plan, premium_expire=paid_through)
        Profile.objects.filter(user=user).update(premium_renewal=True, active_provider=provider)
        return user

    def store_subscriber(self, username, payment_provider):
        user = self.reader(username, "premium", premium_expire=self.now + self.days(335))
        PaymentHistory.objects.create(
            user=user,
            payment_date=self.now - self.days(30),
            payment_amount=36,
            payment_provider=payment_provider,
        )
        return user

    def own_plan_preview(self, user):
        return self.get(user, "invite_preview", token=self.token)["invite"]["own_plan"]

    def accept(self, user):
        response = self.post(user, "accept_invite", token=self.token)
        self.assertEqual(response["code"], 1)
        return response["own_plan"]

    def test_joining_turns_off_a_stripe_renewal_at_the_period_end_and_keeps_usage_billing(self):
        paid_through = self.now + self.days(200)
        reader = self.subscriber("reader", "archive", "stripe", paid_through)
        Profile.objects.filter(user=reader).update(stripe_id="cus_reader", is_usage_billing=True)
        StripeIds.objects.create(user=reader, stripe_id="cus_reader")
        usage_sub = stripe_subscription("sub_usage", ["price_text_classifier", "price_image_classifier"])
        archive_sub = stripe_subscription("sub_archive", [Profile.plan_to_stripe_price("archive")])
        fake_stripe = FakeStripe(self, "cus_reader", [usage_sub, archive_sub])

        # A join the team refuses changes nothing.
        Team.objects.filter(pk=self.team.pk).update(seat_limit=1)
        self.assertEqual(self.post(reader, "accept_invite", token=self.token)["reason"], "seat_limit")
        self.assertEqual(fake_stripe.renewals_turned_off(), [])
        Team.objects.filter(pk=self.team.pk).update(seat_limit=10)

        self.assertEqual(self.own_plan_preview(reader)["on_join"], "renewal_off")
        own_plan = self.accept(reader)

        self.assertEqual((own_plan["subscription"], own_plan["on_join"]), ("stripe", "renewal_off"))
        self.assertEqual(fake_stripe.renewals_turned_off(), [("sub_archive", {"cancel_at_period_end": True})])
        for refused in (fake_stripe.cancel, fake_stripe.delete, fake_stripe.refund):
            refused.assert_not_called()
        self.assertEqual(self.premium_expire(reader), paid_through)
        [email] = self.mail_to(reader)
        self.assertIn(dateformat.format(paid_through, "F j, Y"), email.body)

        # What they paid for stays theirs once the seat ends.
        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "archive")

    def test_joining_suspends_a_paypal_renewal_without_a_refund(self):
        reader = self.subscriber("reader", "premium", "paypal", self.now + self.days(300))
        Profile.objects.filter(user=reader).update(paypal_sub_id="I-TEAMJOINER")
        PaypalIds.objects.create(user=reader, paypal_sub_id="I-TEAMJOINER")
        fake_paypal = FakePayPal(self, "I-TEAMJOINER")

        own_plan = self.accept(reader)

        self.assertEqual((own_plan["subscription"], own_plan["on_join"]), ("paypal", "renewal_off"))
        self.assertEqual(fake_paypal.posts, ["/v1/billing/subscriptions/I-TEAMJOINER/suspend"])
        self.assertFalse(Profile.objects.get(user=reader).premium_renewal)
        self.assertEqual(len(self.mail_to(reader)), 1)

    def stripe_subscriber(self, username):
        user = self.subscriber(username, "archive", "stripe", self.now + self.days(200))
        Profile.objects.filter(user=user).update(stripe_id="cus_%s" % username)
        StripeIds.objects.create(user=user, stripe_id="cus_%s" % username)
        return user

    def held_join_task(self):
        """apps/team/tests.py: the next join's own plan task, kept in the queue until the test runs it."""
        held = self.patch(SettleOwnPlanOnJoin, "delay")
        return lambda: SettleOwnPlanOnJoin.apply(kwargs=held.call_args_list[0].kwargs).get()

    def test_a_join_task_turns_off_only_what_renewed_at_the_join(self):
        reader = self.stripe_subscriber("reader")
        archive_sub = stripe_subscription("sub_archive", [Profile.plan_to_stripe_price("archive")])
        fake_stripe = FakeStripe(self, "cus_reader", [archive_sub])
        run_join_task = self.held_join_task()
        self.accept(reader)
        # The join itself waits on neither Stripe nor PayPal.
        stripe.Subscription.list.assert_not_called()

        # A plan bought after joining is theirs to keep.
        fake_stripe.subscriptions.append(
            stripe_subscription(
                "sub_pro", [Profile.plan_to_stripe_price("pro")], created=self.now + self.days(1)
            )
        )
        run_join_task()

        self.assertEqual(fake_stripe.renewals_turned_off(), [("sub_archive", {"cancel_at_period_end": True})])
        self.assertEqual(len(self.mail_to(reader)), 1)

    def test_a_join_task_whose_seat_ended_first_turns_nothing_off(self):
        reader = self.stripe_subscriber("reader")
        archive_sub = stripe_subscription("sub_archive", [Profile.plan_to_stripe_price("archive")])
        fake_stripe = FakeStripe(self, "cus_reader", [archive_sub])
        run_join_task = self.held_join_task()
        self.accept(reader)
        self.leave(reader)
        fake_stripe.subscriptions.append(
            stripe_subscription(
                "sub_pro", [Profile.plan_to_stripe_price("pro")], created=self.now + self.days(1)
            )
        )
        mail.outbox = []

        run_join_task()

        self.assertEqual(fake_stripe.renewals_turned_off(), [])
        self.assertEqual(self.mail_to(reader), [])

    def test_a_renewal_stripe_or_paypal_wont_confirm_off_goes_to_staff_not_the_teammate(self):
        stripe_reader = self.stripe_subscriber("stripereader")
        fake_stripe = FakeStripe(
            self,
            "cus_stripereader",
            [stripe_subscription("sub_archive", [Profile.plan_to_stripe_price("archive")])],
        )
        fake_stripe.modify.side_effect = stripe.error.InvalidRequestError("No such subscription", None)
        paypal_reader = self.subscriber("paypalreader", "premium", "paypal", self.now + self.days(300))
        Profile.objects.filter(user=paypal_reader).update(paypal_sub_id="I-TEAMJOINER")
        PaypalIds.objects.create(user=paypal_reader, paypal_sub_id="I-TEAMJOINER")
        fake_paypal = FakePayPal(self, "I-TEAMJOINER")
        fake_paypal.suspends = False

        for user in (stripe_reader, paypal_reader):
            self.accept(user)

        for user in (stripe_reader, paypal_reader):
            self.assertEqual(self.mail_to(user), [])
        self.assertGreater(fake_stripe.modify.call_count, 1)
        self.assertGreater(len(fake_paypal.posts), 1)
        staff_notices = [call.kwargs["event_type"] for call in EmailStaffNotification.delay.call_args_list]
        self.assertEqual(staff_notices.count("team_own_plan_unconfirmed"), 2)

    def test_a_renewal_stripe_or_paypal_cant_read_goes_to_staff_after_retries_not_the_teammate(self):
        stripe_reader = self.stripe_subscriber("stripereader")
        fake_stripe = FakeStripe(
            self,
            "cus_stripereader",
            [stripe_subscription("sub_archive", [Profile.plan_to_stripe_price("archive")])],
        )
        stripe.Subscription.list.side_effect = stripe.error.APIConnectionError("timed out")
        paypal_reader = self.subscriber("paypalreader", "premium", "paypal", self.now + self.days(300))
        Profile.objects.filter(user=paypal_reader).update(paypal_sub_id="I-TEAMJOINER")
        PaypalIds.objects.create(user=paypal_reader, paypal_sub_id="I-TEAMJOINER")
        fake_paypal = FakePayPal(self, "I-TEAMJOINER")
        # A PayPal answer without the subscription's status.
        fake_paypal.get = lambda url: {"id": "I-TEAMJOINER"}

        for user in (stripe_reader, paypal_reader):
            self.accept(user)

        for user in (stripe_reader, paypal_reader):
            self.assertEqual(self.mail_to(user), [])
            self.assertEqual(self.plan_of(user), "pro")
        self.assertEqual(fake_stripe.renewals_turned_off(), [])
        self.assertGreater(stripe.Subscription.list.call_count, 1)
        staff_notices = [call.kwargs["event_type"] for call in EmailStaffNotification.delay.call_args_list]
        self.assertEqual(staff_notices.count("team_own_plan_unconfirmed"), 2)

    def classic_paypal_subscriber(self, username):
        user = self.subscriber(username, "premium", "paypal", self.now + self.days(300))
        Profile.objects.filter(user=user).update(paypal_sub_id="I-CLASSIC")
        PaypalIds.objects.create(user=user, paypal_sub_id="I-CLASSIC")
        return user

    def test_joining_cancels_a_classic_paypal_renewal_through_the_classic_api(self):
        reader = self.classic_paypal_subscriber("reader")
        classic_paypal = FakeClassicPayPal(self)

        self.accept(reader)

        self.assertEqual(classic_paypal.changes, [("I-CLASSIC", "Cancel")])
        self.assertEqual(len(self.mail_to(reader)), 1)

    def test_a_classic_paypal_renewal_paypal_cant_read_goes_to_staff_not_the_teammate(self):
        reader = self.classic_paypal_subscriber("reader")
        FakeClassicPayPal(self).classic_api.return_value = None

        self.accept(reader)

        self.assertEqual(self.mail_to(reader), [])
        staff_notices = [call.kwargs["event_type"] for call in EmailStaffNotification.delay.call_args_list]
        self.assertEqual(staff_notices, ["team_own_plan_unconfirmed"])

    def test_store_subscribers_are_told_to_cancel_in_their_own_store(self):
        ios_reader = self.store_subscriber("iosreader", "ios-subscription")
        android_reader = self.store_subscriber("androidreader", "android-archive")

        for user, store, store_domain in (
            (ios_reader, "app_store", "apps.apple.com"),
            (android_reader, "play", "play.google.com"),
        ):
            self.assertEqual(self.own_plan_preview(user)["on_join"], "cancel_in_store")
            own_plan = self.accept(user)
            self.assertEqual(own_plan["subscription"], store)
            self.assertIn(store_domain, own_plan["manage_url"])
            [email] = self.mail_to(user)
            self.assertIn(store_domain, email.body)

    def test_someone_without_a_renewing_plan_of_their_own_gets_no_email(self):
        free_reader = self.reader("freereader", "free")
        # Renewal already off: their plan runs out on its own date.
        cancelled = self.reader("cancelled", "premium", premium_expire=self.now + self.days(100))
        Profile.objects.filter(user=cancelled).update(active_provider="stripe", premium_renewal=False)
        lapsed_store = self.store_subscriber("lapsedstore", "ios-subscription")
        Profile.objects.filter(user=lapsed_store).update(premium_expire=self.now - self.days(1))

        for user in (free_reader, cancelled, lapsed_store):
            self.assertIsNone(self.own_plan_preview(user)["subscription"])
            self.join(user)

        self.assertEqual(mail.outbox, [])

    def test_a_lapsed_team_coming_back_cancels_and_emails_nothing_again(self):
        stripe_reader = self.subscriber("stripereader", "archive", "stripe", self.now + self.days(200))
        Profile.objects.filter(user=stripe_reader).update(stripe_id="cus_reader")
        StripeIds.objects.create(user=stripe_reader, stripe_id="cus_reader")
        fake_stripe = FakeStripe(
            self,
            "cus_reader",
            [stripe_subscription("sub_archive", [Profile.plan_to_stripe_price("archive")])],
        )
        ios_reader = self.store_subscriber("iosreader", "ios-subscription")
        for user in (stripe_reader, ios_reader):
            self.join(user)
        deactivate_team(self.team)
        # While the team was off, the reader turned their own renewal back on.
        Profile.objects.filter(user=stripe_reader).update(premium_renewal=True)
        mail.outbox = []

        activate_team(self.team)

        self.assertEqual(self.plan_of(stripe_reader), "pro")
        self.assertEqual(len(fake_stripe.renewals_turned_off()), 1)
        self.assertEqual(mail.outbox, [])


class Test_TeamProSeatEndsMidChange(TeamProMixin, TestCase):
    """A plan of the teammate's own that changes at the moment their seat ends is applied to the plan the seat's
    end left them on."""

    def ending_the_seat_at_the_grant_lookup(self, user):
        """apps/team/tests.py: the seat ends right after apps/profile/models.py has looked up the grant, before it
        records anything on it."""
        lookup = profile_models.team_pro_grant
        seat = TeamMember.active_membership(user)
        ended = []

        def lookup_then_seat_ends(user_id):
            grant = lookup(user_id)
            if not ended:
                ended.append(True)
                seat.leave()
            return grant

        return patch.object(profile_models, "team_pro_grant", side_effect=lookup_then_seat_ends)

    def test_a_plan_bought_as_the_seat_ends_is_applied(self):
        reader = self.reader("reader", "free", feeds=2)
        self.join(reader)
        # Loaded during the seat, as a payment webhook loads it.
        profile = Profile.objects.get(user=reader)

        with self.ending_the_seat_at_the_grant_lookup(reader):
            profile.activate_archive_extra()

        self.assertEqual(self.plan_of(reader), "archive_extra")
        self.assertEqual(self.muted_sites(reader), 0)

    def test_an_own_plan_ending_as_the_seat_ends_is_not_put_back(self):
        reader = self.reader("reader", "premium", premium_expire=self.now + self.days(100))
        self.join(reader)
        profile = Profile.objects.get(user=reader)

        with self.ending_the_seat_at_the_grant_lookup(reader):
            profile.deactivate_premium()

        self.assertEqual(self.plan_of(reader), "free")

    def test_a_credit_given_as_the_seat_ends_is_applied(self):
        reader = self.reader("reader", "free")
        self.join(reader)
        profile = Profile.objects.get(user=reader)

        with self.ending_the_seat_at_the_grant_lookup(reader):
            profile.extend_premium_by_days(365, tier="archive")

        self.assertEqual(self.plan_of(reader), "archive")

    def test_a_stripe_purchase_whose_history_sync_overlaps_the_seat_ending_is_applied(self):
        # The trial this account once had ran out long ago, so a seat ending before the purchase's paid through
        # date is synced puts it on free.
        reader = self.reader("reader", "free", premium_expire=self.now - self.days(100))
        Profile.objects.filter(user=reader).update(stripe_id="cus_reader")
        StripeIds.objects.create(user=reader, stripe_id="cus_reader")
        self.join(reader)
        FakeStripe(
            self, "cus_reader", [stripe_subscription("sub_pro", [Profile.plan_to_stripe_price("pro")])]
        )
        seat = TeamMember.active_membership(reader)
        charge = MagicMock(created=int(self.now.timestamp()), status="succeeded", amount=2900, refunded=False)

        def charges_as_the_seat_ends(**kwargs):
            seat.leave()
            return MagicMock(data=[charge])

        self.patch(stripe.Charge, "list", side_effect=charges_as_the_seat_ends)

        Profile.objects.get(user=reader).activate_pro()

        self.assertEqual(self.plan_of(reader), "pro")
        self.assertGreater(self.premium_expire(reader), self.now)


@override_settings(**USAGE_PRICES)
class Test_TeamAIFilterBilling(TeamProMixin, TestCase):
    """AI filters are pay per use on the owner's Stripe customer, against the owner's spending limit."""

    def setUp(self):
        super().setUp()
        # apps/team/tests.py: cost rows go to the test database instead of the shared analytics one.
        analytics = switch_db(MLLMCost, "default")
        analytics.__enter__()
        self.addCleanup(analytics.__exit__, None, None, None)
        self.addCleanup(lambda: MLLMCost.objects.delete())
        self.patch(RLLMCosts, "record")
        self.meter_events = self.patch(stripe.billing.MeterEvent, "create")
        Profile.objects.filter(user=self.owner).update(stripe_id="cus_owner")
        self.addCleanup(self.forget_cached_limit, self.owner)

    def forget_cached_limit(self, user):
        redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL).delete("usage_limit:%s" % user.pk)

    def turn_on_owner_billing(self, limit=None):
        Profile.objects.filter(user=self.owner).update(is_usage_billing=True, usage_billing_limit=limit)

    def at(self, fraction):
        """apps/team/tests.py: a moment between the start of this billing month and now."""
        now = datetime.datetime.utcnow()
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        return month_start + (now - month_start) * fraction

    def cost(self, user, cost_usd, timestamp, feature="story_classification"):
        MLLMCost(
            user_id=user.pk,
            provider="anthropic",
            model="claude-haiku-5-5",
            feature=feature,
            cost_usd=cost_usd,
            timestamp=timestamp,
        ).save()

    def classify(self, user, input_tokens=1_000_000):
        """apps/team/tests.py: one AI filter call, which costs $2.00 for a million input tokens."""
        LLMCostTracker.record_usage(
            provider="anthropic",
            model="claude-sonnet-5-5",
            feature="story_classification",
            input_tokens=input_tokens,
            user_id=user.pk,
        )

    def test_a_teammate_uses_ai_filters_only_once_the_owner_pays_for_them(self):
        # The teammate's own usage billing from before joining doesn't carry onto the team.
        reader = self.reader("reader", "free")
        Profile.objects.filter(user=reader).update(stripe_id="cus_reader", is_usage_billing=True)
        self.join(reader)
        self.assertFalse(Profile.objects.get(user=reader).can_use_ai_classifiers)

        self.turn_on_owner_billing()
        self.assertTrue(Profile.objects.get(user=reader).can_use_ai_classifiers)
        self.classify(reader)

        self.assertEqual(
            [call.kwargs["payload"]["stripe_customer_id"] for call in self.meter_events.call_args_list],
            ["cus_owner"],
        )
        self.assertEqual(MLLMCost.objects(user_id=reader.pk).count(), 1)
        # Only a teammate's cost row names who was billed, so the release before teams can read every other.
        self.classify(self.owner)
        self.assertEqual(
            [("billed_user_id" in row) for row in MLLMCost._get_collection().find().sort("_id", 1)],
            [True, False],
        )

        self.leave(reader)
        self.assertTrue(Profile.objects.get(user=reader).can_use_ai_classifiers)
        self.classify(reader)
        self.assertEqual(
            self.meter_events.call_args_list[-1].kwargs["payload"]["stripe_customer_id"], "cus_reader"
        )

    def test_the_owners_limit_counts_each_teammate_only_while_on_the_team(self):
        self.turn_on_owner_billing(limit=Decimal("1.00"))
        stayer = self.reader("stayer", "free")
        leaver = self.reader("leaver", "free")
        outsider = self.reader("outsider", "free")
        # A cost row written before rows named who was billed counts for the account that used it.
        self.cost(self.owner, 0.40, self.at(0.1))
        self.cost(stayer, 3.00, self.at(0.1), feature="ask_ai")
        for user in (stayer, leaver, outsider):
            self.classify(user)
        for user in (stayer, leaver):
            self.join(user)

        self.classify(stayer, input_tokens=100_000)
        self.classify(leaver, input_tokens=100_000)
        self.leave(leaver)
        self.classify(leaver)
        self.join(leaver)
        self.classify(leaver, input_tokens=50_000)

        spend, limit, reached = Profile.objects.get(user=stayer).get_usage_billing_spend()
        self.assertAlmostEqual(spend, 0.90)
        self.assertEqual((limit, reached), (1.0, False))
        self.assertAlmostEqual(Profile.objects.get(user=self.owner).get_usage_billing_spend()[0], 0.90)
        self.assertFalse(Profile.objects.get(user=stayer).is_usage_limit_reached)

        # Another teammate's use past the owner's limit stops everyone at once.
        teammate = self.reader("teammate", "free")
        self.join(teammate)
        self.classify(teammate)
        self.assertTrue(Profile.objects.get(user=stayer).is_usage_limit_reached)
        self.assertTrue(Profile.objects.get(user=self.owner).is_usage_limit_reached)

    def test_what_a_teammate_uses_off_the_team_or_while_it_is_inactive_is_their_own(self):
        self.turn_on_owner_billing()
        reader = self.reader("reader", "free")
        Profile.objects.filter(user=reader).update(stripe_id="cus_reader", is_usage_billing=True)
        self.join(reader)
        self.classify(reader, input_tokens=100_000)
        self.leave(reader)
        self.classify(reader)
        self.join(reader)
        deactivate_team(self.team)
        self.classify(reader)
        activate_team(self.team)
        self.classify(reader, input_tokens=50_000)
        self.leave(reader)

        self.assertAlmostEqual(Profile.objects.get(user=self.owner).get_usage_billing_spend()[0], 0.30)
        self.assertAlmostEqual(Profile.objects.get(user=reader).get_usage_billing_spend()[0], 4.00)

    def test_only_the_owner_turns_on_usage_billing_for_the_team(self):
        reader = self.reader("reader", "free")
        self.join(reader)
        self.patch(stripe.Subscription, "list", return_value=MagicMock(data=[]))
        checkout = self.patch(
            stripe.checkout.Session,
            "create",
            return_value=MagicMock(url="https://checkout.stripe.com/c/team"),
        )

        app_response = self.client_for(reader).post("/profile/setup_usage_billing/", {"platform": "ios"})
        self.assertEqual(json.decode(app_response.content)["reason"], "team_owner_only")
        web_response = self.client_for(reader).post("/profile/setup_usage_billing/")
        self.assertIn("usage_billing=team_owner_only", web_response["Location"])
        checkout.assert_not_called()

        owner_response = self.client_for(self.owner).post("/profile/setup_usage_billing/")
        self.assertEqual(owner_response["Location"], "https://checkout.stripe.com/c/team")


class Test_TeamProUpkeep(TeamProMixin, TestCase):
    def test_paid_counts_leave_teammates_out_and_count_them_as_seats(self):
        MStatistics.objects(key__startswith="munin:users_").delete()
        Profile.objects.filter(user=self.owner).update(**PLANS["free"])
        self.reader("subscriber", "pro", premium_expire=self.now + self.days(20))
        for username in ("first", "second", "third", "leaver"):
            self.join(self.reader(username, "free"))
        self.leave(User.objects.get(username="leaver"))
        # The owner of a team someone pays for counts as paying, not as a seat.
        self.pay(self.reader("payingowner"), self.now + self.days(31))

        body = self.client_for(None).get("/monitor/users").content.decode("utf-8")

        counts = dict(re.findall(r'users\{category="(\w+)"\} (\d+)', body))
        self.assertEqual(
            {category: counts[category] for category in ("premium", "archive", "pro", "team_seats")},
            {"premium": "2", "archive": "2", "pro": "2", "team_seats": "3"},
        )

    def test_the_hourly_task_puts_back_pro_a_trial_expiry_took_from_a_new_teammate(self):
        reader = self.reader("reader", "trial", premium_expire=self.now - self.days(1))
        outsider = self.reader("outsider", "free")
        # The nightly expiry loaded the trial before the reader joined. They join while its email goes out, and
        # it then ends the trial on the profile it loaded.
        with patch.object(Profile, "send_premium_trial_expire_email", side_effect=lambda: self.join(reader)):
            PremiumExpire()
        self.assertEqual(self.plan_of(reader), "premium")

        TeamProGrants()

        self.assertEqual([self.plan_of(user) for user in (reader, outsider)], ["pro", "free"])

    def test_leaving_keeps_whether_the_account_can_start_a_trial(self):
        never_tried = self.reader("nevertried", "free")
        Profile.objects.filter(user=never_tried).update(is_premium_trial=None)
        used_trial = self.reader("usedtrial", "free")
        trial_ran_out = self.reader("trialranout", "trial", premium_expire=self.now + self.days(5))
        readers = (never_tried, used_trial, trial_ran_out)
        for user in readers:
            self.join(user)
        TeamProGrant.objects.filter(user=trial_ran_out).update(own_trial_expire=self.now - self.days(1))

        for user in readers:
            self.leave(user)

        self.assertEqual(
            [Profile.objects.get(user=user).start_premium_trial() for user in readers], [True, False, False]
        )

    def test_a_stripe_switch_from_archive_extra_to_archive_during_the_seat_is_kept(self):
        reader = self.reader("reader", "archive_extra", premium_expire=self.now + self.days(200))
        Profile.objects.filter(user=reader).update(stripe_id="cus_reader")
        StripeIds.objects.create(user=reader, stripe_id="cus_reader")
        self.join(reader)
        archive_price = Profile.plan_to_stripe_price("archive")
        FakeStripe(self, "cus_reader", [stripe_subscription("sub_archive", [archive_price])])
        self.patch(
            stripe.Subscription, "retrieve", return_value={"status": "active", "plan": {"id": archive_price}}
        )

        stripe_subscription_updated(
            None,
            {
                "data": {
                    "object": {
                        "id": "sub_archive",
                        "customer": "cus_reader",
                        "plan": {"id": archive_price, "active": True},
                        "cancel_at": None,
                        "items": {"data": []},
                    }
                }
            },
        )
        self.assertEqual(self.plan_of(reader), "pro")

        self.leave(reader)
        self.assertEqual(self.plan_of(reader), "archive")


class TeamSitesMixin(TeamProMixin):
    """apps/team/tests.py: Premium Pro's site limit is patched down to three, so a team reaches it with a few rows.
    The owner, alexis and casey are on the team. The owner and alexis both follow "shared", alexis follows
    "followed" and has "muted" muted, and a former teammate who still pays for their own plan follows "former".
    That's two of the three sites counted, because a site counts once and only while someone on the team follows it
    actively, so one site of room is left. Casey has none yet."""

    def setUp(self):
        super().setUp()
        self.patch(Profile, "PRO_FEED_LIMIT", new=3)
        self.patch(MaintainFeedSubscriptions, "delay")
        User.objects.filter(pk=self.owner.pk).update(username="editor_in_chief")
        Profile.objects.filter(user=self.owner).update(**PLANS["pro"])
        self.shared, self.followed, self.muted, self.former, self.new, self.newer = (
            self.site(name) for name in ("shared", "followed", "muted", "former", "new", "newer")
        )
        self.follow(self.owner, self.shared)
        self.alexis = self.reader("alexis")
        self.join(self.alexis)
        self.follow(self.alexis, self.shared, self.followed)
        self.follow(self.alexis, self.muted, active=False)
        former = self.reader("formerteammate", "premium", premium_expire=self.now + self.days(30))
        self.join(former)
        self.follow(former, self.former)
        self.leave(former)
        self.casey = self.reader("casey")
        self.join(self.casey)

    def site(self, name):
        return Feed.objects.create(
            feed_address=urlnorm.normalize("https://%s.example/feed.xml" % name),
            feed_link=urlnorm.normalize("https://%s.example/" % name),
            feed_title=name,
            num_subscribers=20,
        )

    def follow(self, user, *feeds, active=True):
        for feed in feeds:
            UserSubscription.objects.create(user=user, feed=feed, active=active)

    def active_sites(self, user):
        return set(
            UserSubscription.objects.filter(user=user, active=True).values_list("feed__feed_title", flat=True)
        )

    def reader_post(self, user, path, **data):
        return json.decode(self.client_for(user).post("/reader/%s" % path, data).content)

    def add_url(self, user, feed):
        with patch("apps.reader.views.validate_public_url"), patch.object(
            Feed, "get_feed_from_url", return_value=feed
        ):
            return self.reader_post(user, "add_url", url=feed.feed_address)

    def assert_team_refusal(self, message):
        self.assertIn("Newsroom", message)
        self.assertIn("editor_in_chief", message)


class Test_TeamSiteLimit(TeamSitesMixin, TestCase):
    def test_adding_a_site_stops_at_the_teams_limit_except_for_sites_it_already_follows(self):
        self.assertEqual(self.add_url(self.casey, self.new)["code"], 1)

        refused = self.add_url(self.casey, self.newer)
        self.assertEqual(refused["code"], -1)
        self.assert_team_refusal(refused["message"])
        self.assertEqual(self.add_url(self.casey, self.followed)["code"], 1)
        self.assertEqual(self.active_sites(self.casey), {"new", "followed"})

    def test_the_owner_of_a_team_staff_started_is_held_to_its_limit(self):
        staffer = self.reader("staffer")
        User.objects.filter(pk=staffer.pk).update(is_staff=True)
        desk = Team.objects.get(pk=self.post(staffer, "create", name="Desk")["team"]["id"])
        deskmate = self.reader("deskmate")
        self.join(deskmate, self.join_link_token(desk, staffer))
        self.follow(deskmate, self.shared, self.followed, self.new)

        refused = self.add_url(staffer, self.newer)

        self.assertEqual(refused["code"], -1)
        self.assertIn("Desk", refused["message"])
        self.assertEqual(self.active_sites(staffer), set())

    def test_batch_subscribe_stops_at_the_teams_limit(self):
        self.follow(self.casey, self.new)

        response = self.reader_post(self.casey, "add_feeds", feed_ids=[self.newer.pk, self.followed.pk])

        results = {result["feed_id"]: result for result in response["results"]}
        self.assertEqual([results[feed.pk]["code"] for feed in (self.newer, self.followed)], [-1, 1])
        self.assert_team_refusal(results[self.newer.pk]["message"])
        self.assertEqual(self.active_sites(self.casey), {"new", "followed"})

    def test_unmuting_stops_at_the_teams_limit(self):
        self.follow(self.casey, self.new)
        self.follow(self.casey, self.newer, self.followed, active=False)

        refused = self.reader_post(self.casey, "set_feed_mute", feed_id=self.newer.pk, mute="false")
        unmuted = self.reader_post(self.casey, "set_feed_mute", feed_id=self.followed.pk, mute="false")

        self.assertEqual((refused["code"], unmuted["code"]), (-1, 1))
        self.assert_team_refusal(refused["message"])
        self.assertEqual(self.active_sites(self.casey), {"new", "followed"})

    def test_the_feed_chooser_swaps_sites_within_the_teams_limit(self):
        self.follow(self.casey, self.new)
        self.follow(self.casey, self.newer, self.followed, active=False)

        too_many = self.reader_post(
            self.casey, "save_feed_chooser", approved_feeds=[self.new.pk, self.newer.pk, self.followed.pk]
        )
        self.assert_team_refusal(too_many["message"])
        self.assertEqual(self.active_sites(self.casey), {"new", "followed"})

        # Letting go of "new" makes room for "newer".
        swapped = self.reader_post(
            self.casey, "save_feed_chooser", approved_feeds=[self.newer.pk, self.followed.pk]
        )
        self.assertNotIn("message", swapped)
        self.assertEqual(self.active_sites(self.casey), {"newer", "followed"})

    def test_an_opml_import_makes_active_only_what_fits(self):
        self.follow(self.casey, self.new)
        outlines = "".join(
            '<outline title="%s" type="rss" xmlUrl="%s" htmlUrl="%s" />'
            % (feed.feed_title, feed.feed_address, feed.feed_link)
            for feed in (self.newer, self.followed)
        )

        casey = User.objects.get(pk=self.casey.pk)
        OPMLImporter('<opml version="1.0"><body>%s</body></opml>' % outlines, casey).process()

        self.assertEqual(self.active_sites(self.casey), {"new", "followed"})
        self.assertTrue(UserSubscription.objects.filter(user=self.casey, feed=self.newer).exists())

    def test_turning_sites_back_on_for_an_account_with_none_active_stops_at_the_limit(self):
        self.follow(self.casey, self.new, self.newer, self.followed, active=False)
        UserSubscriptionFolders.objects.create(
            user=self.casey, folders=json.encode([self.new.pk, self.newer.pk, self.followed.pk])
        )

        UserSubscriptionFolders.objects.get(user=self.casey).auto_activate()

        self.assertEqual(self.active_sites(self.casey), {"new", "followed"})

    def test_a_web_feed_stops_at_the_teams_limit(self):
        self.follow(self.casey, self.new)
        url = "https://pages.example/news"
        self.addCleanup(lambda: MWebFeedConfig.objects(url=url).delete())

        with patch("apps.webfeed.views.validate_public_url"):
            response = json.decode(
                self.client_for(self.casey)
                .post(
                    "/webfeed/subscribe",
                    {"url": url, "variant_index": 0, "story_container_xpath": "//li", "title_xpath": ".//a"},
                )
                .content
            )

        self.assertEqual(response["code"], -1)
        self.assert_team_refusal(response["message"])
        self.assertEqual(self.active_sites(self.casey), {"new"})

    def test_timed_mutes_running_out_come_back_only_as_far_as_the_limit(self):
        self.follow(self.casey, self.new)
        self.follow(self.casey, self.newer, self.followed, active=False)
        UserSubscriptionFolders.objects.create(
            user=self.casey, folders=json.encode([self.new.pk, self.newer.pk, self.followed.pk])
        )
        fetches = self.patch(ScheduleImmediateFetches, "apply_async")

        for flat in ("true", "false"):
            UserSubscription.objects.filter(user=self.casey, feed__in=(self.newer, self.followed)).update(
                active=False, mute_expires_at=self.now - self.days(1)
            )
            fetches.reset_mock()

            response = self.client_for(self.casey).get("/reader/feeds", {"flat": flat})
            feeds = json.decode(response.content)["feeds"]

            self.assertEqual(self.active_sites(self.casey), {"new", "followed"})
            listed_active = {feed["feed_title"] for feed in feeds.values() if feed["active"]}
            self.assertEqual(listed_active, {"new", "followed"})
            scheduled = {
                feed_id for call in fetches.call_args_list for feed_id in call.kwargs["kwargs"]["feed_ids"]
            }
            self.assertNotIn(self.newer.pk, scheduled)

    def test_joining_past_the_limit_mutes_only_the_joiners_newest_sites(self):
        joiner = self.reader("joiner", "premium", premium_expire=self.now + self.days(30))
        self.follow(joiner, self.followed, self.new, self.newer)

        self.join(joiner)

        self.assertEqual(self.active_sites(joiner), {"followed", "new"})
        self.assertEqual(self.active_sites(self.alexis), {"shared", "followed"})
        self.assertEqual(self.active_sites(self.owner), {"shared"})

    def test_a_free_account_joining_gets_back_only_what_fits_oldest_first(self):
        joiner = self.reader("joiner")
        self.follow(joiner, self.newer, self.followed, self.new, active=False)

        self.join(joiner)

        self.assertEqual(self.active_sites(joiner), {"newer", "followed"})

    def test_an_account_on_no_team_keeps_the_limits_it_had(self):
        solo = self.reader("solo", "pro", premium_expire=self.now + self.days(30))
        self.follow(solo, self.shared, self.followed, self.muted)
        self.follow(solo, self.new, active=False)

        self.assertEqual(self.add_url(solo, self.newer)["code"], 1)
        unmuted = self.reader_post(solo, "set_feed_mute", feed_id=self.new.pk, mute="false")
        self.assertEqual(unmuted["code"], 1)

    def test_a_full_team_leaves_the_web_client_to_ask_the_server_about_each_site(self):
        self.follow(self.casey, self.new)
        solo = self.reader("solo", "pro", premium_expire=self.now + self.days(30))

        def limits_shown(user):
            page = self.client_for(user).get(reverse("index")).content.decode("utf-8")
            return re.findall(r"'(?:max|add)_feed_limit'\s*:\s*(\w+)", page)

        self.assertEqual(limits_shown(self.casey), limits_shown(solo))


class Test_TeamSiteLimitAtOnce(TeamSitesMixin, TransactionTestCase):
    def test_two_teammates_adding_the_last_site_at_once_leaves_one_out(self):
        def add(user, feed):
            return lambda: self.reader_post(user, "add_feeds", feed_ids=[feed.pk])

        casey_response, alexis_response = self.while_held(
            self.team.lock, add(self.alexis, self.newer), add(self.casey, self.new)
        )

        self.assertEqual(casey_response["code"], 1)
        self.assertEqual(alexis_response["code"], -1)
        self.assert_team_refusal(alexis_response["message"])
        self.assertEqual(
            self.active_sites(self.casey) | self.active_sites(self.alexis), {"shared", "followed", "new"}
        )


class Test_TeamSharedAllowances(TeamProMixin, TestCase):
    """The owner, alexis and brooke are on the team. Listen, Ask AI and the Archive Assistant each give the team
    one allowance between them, counted against the owner."""

    def setUp(self):
        super().setUp()
        for document in (MListenUsage, MAskAIUsage, MAITranscriptionUsage, MArchiveAssistantUsage):
            document.drop_collection()
            self.addCleanup(document.drop_collection)
        Profile.objects.filter(user=self.owner).update(**PLANS["pro"])
        self.alexis = self.reader("alexis")
        self.brooke = self.reader("brooke")
        for user in (self.alexis, self.brooke):
            self.join(user)
        # apps/team/tests.py: Mongo keeps milliseconds, so usage saved right after a join could read as before it.
        TeamMember.objects.filter(team=self.team).update(joined_date=self.now - datetime.timedelta(minutes=1))
        self.week_start = ListenUsageTracker(self.fresh(self.owner)).week_window()[0]

    def fresh(self, user):
        return User.objects.get(pk=user.pk)

    def at(self, fraction):
        """apps/team/tests.py: a moment between the start of the owner's Listen week and now."""
        now = datetime.datetime.utcnow()
        return self.week_start + (now - self.week_start) * fraction

    def listened(self, user, hours, at=None):
        MListenUsage(
            user_id=user.pk, kind="segment", seconds=hours * 3600, cached=False, created_at=at or self.at(1)
        ).save()

    def can_listen(self, user):
        return ListenUsageTracker(self.fresh(user)).check_segment("900:story", cached=False)

    def used(self, document, user, count):
        document.objects.insert([document(user_id=user.pk) for _ in range(count)])

    def test_listen_is_one_weekly_allowance_for_the_whole_team(self):
        outsider = self.reader("outsider", "pro", premium_expire=self.now + self.days(30))
        self.listened(outsider, 9)
        self.listened(self.owner, 4)
        self.listened(self.alexis, 5)
        self.assertTrue(self.can_listen(self.brooke)[0])

        self.listened(self.brooke, 1)

        for user in (self.owner, self.alexis, self.brooke):
            allowed, reason, message = self.can_listen(user)
            self.assertEqual((allowed, reason), (False, "cap_reached"))
        self.assertIn("Newsroom", message)
        self.assertNotIn("alexis", message)
        self.assertTrue(self.can_listen(outsider)[0])

    def test_only_listening_while_on_the_team_counts_for_it(self):
        leaver = self.reader("leaver")
        self.join(leaver)
        self.leave(leaver)
        TeamMember.objects.filter(user=leaver).update(joined_date=self.at(0.3), removed_date=self.at(0.6))
        self.listened(leaver, 9, at=self.at(0.2))
        self.listened(leaver, 2, at=self.at(0.4))
        self.listened(leaver, 9, at=self.at(0.8))

        self.assertEqual(ListenUsageTracker(self.fresh(self.alexis)).seconds_used(), 2 * 3600)

    def test_a_teammate_who_left_and_came_back_still_counts_their_first_seat(self):
        TeamMember.objects.filter(user=self.alexis).update(joined_date=self.at(0.1))
        self.leave(self.alexis)
        TeamMember.objects.filter(user=self.alexis).update(removed_date=self.at(0.4))
        self.join(self.alexis)
        TeamMember.objects.filter(user=self.alexis).update(joined_date=self.at(0.8))
        self.listened(self.alexis, 3, at=self.at(0.2))
        self.listened(self.alexis, 9, at=self.at(0.6))
        self.listened(self.alexis, 1, at=self.at(0.9))

        self.assertEqual(ListenUsageTracker(self.fresh(self.brooke)).seconds_used(), 4 * 3600)

    def test_only_a_reset_of_the_owners_starts_the_teams_week_over(self):
        self.listened(self.alexis, 10, at=self.now - datetime.timedelta(seconds=30))
        # A reset brooke had on their own before joining is not the team's.
        MListenUsage(user_id=self.brooke.pk, kind="reset", reason="manual").save()
        self.assertFalse(self.can_listen(self.brooke)[0])

        staff = User.objects.create_user(username="staffer", is_staff=True)
        self.client_for(staff).post("/listen/staff_usage", {"user_id": self.owner.pk})

        self.assertTrue(self.can_listen(self.alexis)[0])

    def test_after_the_team_lapses_each_teammate_listens_on_their_own(self):
        paying = self.reader("paying", "pro", premium_expire=self.now + self.days(30))
        self.join(paying)
        self.listened(self.alexis, 10)
        self.assertFalse(self.can_listen(paying)[0])

        deactivate_team(self.team)

        self.assertTrue(self.can_listen(paying)[0])

    def test_ask_ai_and_transcription_are_one_daily_allowance_for_the_team(self):
        self.used(MAskAIUsage, self.owner, 60)
        self.used(MAskAIUsage, self.alexis, 39)
        self.assertTrue(AskAIUsageTracker(self.fresh(self.brooke)).can_use()[0])

        self.used(MAskAIUsage, self.brooke, 1)

        allowed, message = AskAIUsageTracker(self.fresh(self.alexis)).can_use()
        self.assertFalse(allowed)
        self.assertIn("Newsroom", message)
        self.used(MAITranscriptionUsage, self.owner, 100)
        self.used(MAITranscriptionUsage, self.brooke, 10)
        self.assertTrue(TranscriptionUsageTracker(self.fresh(self.alexis)).is_over_quota())

    def test_the_archive_assistant_is_one_daily_allowance_for_the_team(self):
        self.used(MArchiveAssistantUsage, self.owner, 60)
        self.used(MArchiveAssistantUsage, self.alexis, 39)
        self.assertTrue(MArchiveAssistantUsage.can_use(self.fresh(self.brooke))[0])

        self.used(MArchiveAssistantUsage, self.brooke, 1)

        allowed, message = MArchiveAssistantUsage.can_use(self.fresh(self.alexis))
        self.assertFalse(allowed)
        self.assertIn("Newsroom", message)


class Test_TeamLookupCost(TeamProMixin, TestCase):
    """Listen, Ask AI, the Archive Assistant and adding a site run on every request of their kind. An account that
    isn't Pro is on no team, so it never looks one up, and a Pro account looks once."""

    def team_lookups(self, user, run):
        user = User.objects.get(pk=user.pk)
        with CaptureQueriesContext(connection) as queries:
            run(user)
        return len([query for query in queries.captured_queries if '"team_' in query["sql"]])

    def test_accounts_not_on_a_team_look_one_up_at_most_once(self):
        feed = Feed.objects.create(feed_address="https://desk.example/feed.xml", num_subscribers=20)
        checks = {
            "listen": lambda user: ListenUsageTracker(user).check_segment("900:story", cached=False),
            "ask_ai": lambda user: AskAIUsageTracker(user).can_use(),
            "archive_assistant": lambda user: MArchiveAssistantUsage.can_use(user),
            "add_site": lambda user: UserSubscription.add_subscription(user, feed.feed_address, folder=""),
        }
        free = self.reader("free")
        pro = self.reader("pro", "pro", premium_expire=self.now + self.days(30))

        with patch.object(Feed, "get_feed_from_url", return_value=feed):
            for name, check in checks.items():
                with self.subTest(check=name):
                    self.assertEqual(self.team_lookups(free, check), 0)
                    self.assertEqual(self.team_lookups(pro, check), 1)


class Test_TeamBilling(TeamProMixin, TestCase):
    """apps/team/billing.py: a payment for a team plan that a provider confirmed."""

    def test_the_first_payment_starts_a_team_with_the_owner_on_pro_as_their_own_plan(self):
        buyer = self.reader("buyer", "free", feeds=2)
        paid_through = self.now + self.days(31)

        payment = self.pay(buyer, paid_through)

        self.assertTrue(payment.created)
        team = self.owned_team(buyer)
        self.assertEqual((team.status, team.paid_through), (Team.STATUS_ACTIVE, paid_through))
        self.assertEqual(self.plan_of(buyer), "pro")
        self.assertEqual(self.muted_sites(buyer), 0)
        EmailNewPremiumPro.delay.assert_not_called()
        EmailStaffPremiumUpgrade.delay.assert_called_once_with(
            user_id=buyer.pk, tier=Team.PLAN_TEAM, previous_tier="free"
        )
        [welcome] = self.mail_to(buyer)
        self.assertIn("?next=team", welcome.body)

    def test_renewals_move_the_paid_period_only_forward_and_welcome_nobody_again(self):
        buyer = self.reader("buyer", "free")
        first_period = self.now + self.days(31)
        second_period = first_period + self.days(31)
        self.pay(buyer, first_period)
        mail.outbox = []

        renewal = self.pay(buyer, second_period)
        late_notice = self.pay(buyer, first_period)

        self.assertFalse(renewal.created or late_notice.created)
        self.assertEqual(self.owned_team(buyer).paid_through, second_period)
        self.assertEqual(self.premium_expire(buyer), second_period)
        self.assertEqual(mail.outbox, [])
        EmailStaffPremiumUpgrade.delay.assert_called_once()

    def test_someone_with_a_seat_on_another_team_gets_no_team_and_keeps_their_own_plan(self):
        own_paid_through = self.now + self.days(100)
        reader = self.reader("reader", "premium", premium_expire=own_paid_through)
        self.join(reader)

        payment = self.pay(reader, self.now + self.days(31))

        self.assertEqual(payment.reason, "on_team")
        self.assertIsNone(self.owned_team(reader))
        self.assertEqual(TeamProGrant.objects.get(user=reader).own_tier, TeamProGrant.TIER_PREMIUM)
        self.assertEqual(self.premium_expire(reader), own_paid_through)
        self.assertEqual(self.staff_events(), ["team_purchase_on_team"])

        # A seat on a team whose plan has lapsed is still a seat.
        deactivate_team(self.team)
        self.assertEqual(self.pay(reader, self.now + self.days(31)).reason, "on_team")
        self.assertIsNone(self.owned_team(reader))
        self.assertEqual(self.plan_of(reader), "premium")

    def test_the_hourly_task_lapses_a_team_a_day_after_its_paid_period_and_never_an_open_comp(self):
        renewing, overdue, comped = (self.reader(username) for username in ("renewing", "overdue", "comped"))
        self.pay(renewing, self.now - datetime.timedelta(hours=12))
        self.pay(overdue, self.now + self.days(31))
        Team.objects.filter(owner=overdue).update(paid_through=self.now - self.days(3))
        self.pay(comped, None, provider=Team.PROVIDER_COMP, reference="staff")

        TeamProGrants()

        self.assertEqual(
            [self.owned_team(user).status for user in (renewing, overdue, comped)],
            [Team.STATUS_ACTIVE, Team.STATUS_INACTIVE, Team.STATUS_ACTIVE],
        )

    def test_a_renewal_landing_while_the_hourly_task_lapses_the_team_keeps_it(self):
        buyer = self.reader("buyer")
        team = self.pay(buyer, self.now + self.days(31)).team
        reader = self.reader("reader")
        self.join(reader, self.join_link_token(team, buyer))
        Team.objects.filter(pk=team.pk).update(paid_through=self.now - self.days(2))

        def renewed_first(team, **kwargs):
            # The renewal commits after the task chose the team and before it locks the team's row.
            self.pay(buyer, self.now + self.days(29))
            return deactivate_team(team, **kwargs)

        with patch("apps.team.tasks.deactivate_team", side_effect=renewed_first):
            TeamProGrants()

        self.assertEqual(self.owned_team(buyer).status, Team.STATUS_ACTIVE)
        self.assertEqual(self.plan_of(reader), "pro")

    def test_only_a_comp_makes_a_team_never_lapse_and_no_payment_ends_one(self):
        comped = self.reader("comped")
        self.pay(comped, None, provider=Team.PROVIDER_COMP, reference="staff")
        paying = self.reader("paying")
        paid_through = self.now + self.days(31)
        self.pay(paying, paid_through)

        self.assertEqual(self.pay(comped, self.now + self.days(31)).reason, "comped")
        self.assertEqual(self.pay(paying, None).reason, "no_paid_through")

        comp_team = self.owned_team(comped)
        self.assertEqual((comp_team.billing_provider, comp_team.paid_through), (Team.PROVIDER_COMP, None))
        self.assertEqual(self.owned_team(paying).paid_through, paid_through)
        self.assertEqual(self.staff_events(), ["team_comp_paid", "team_payment_without_date"])

    def test_paying_in_a_second_place_bills_the_team_through_the_newest_and_tells_staff(self):
        buyer = self.reader("buyer")
        store_period = self.now + self.days(31)
        self.pay(buyer, self.now + self.days(20), reference="sub_web")

        self.pay(
            buyer,
            store_period,
            plan=Team.PLAN_TEAM_ENTERPRISE,
            provider=Team.PROVIDER_APP_STORE,
            reference="2000000000001",
        )

        team = self.owned_team(buyer)
        self.assertEqual(
            (team.plan, team.billing_provider, team.billing_reference, team.paid_through),
            (Team.PLAN_TEAM_ENTERPRISE, Team.PROVIDER_APP_STORE, "2000000000001", store_period),
        )
        self.assertEqual(self.staff_events(), ["team_paid_twice"])

    def test_an_older_payment_arriving_late_changes_nothing_a_newer_one_set(self):
        buyer = self.reader("buyer")
        web_period, web_paid_at = self.now + self.days(20), self.now - self.days(11)
        store_period, store_paid_at = self.now + self.days(31), self.now
        store_payment = dict(
            plan=Team.PLAN_TEAM_ENTERPRISE,
            provider=Team.PROVIDER_APP_STORE,
            reference="2000000000001",
            paid_at=store_paid_at,
        )
        self.pay(buyer, web_period, reference="sub_web", paid_at=web_paid_at)
        self.pay(buyer, store_period, **store_payment)
        staff_events = self.staff_events()

        # The web payment's notice again, delayed or replayed, and a repeat of the store's.
        self.pay(buyer, web_period, reference="sub_web", paid_at=web_paid_at)
        self.pay(buyer, store_period, **store_payment)

        team = self.owned_team(buyer)
        self.assertEqual(
            (team.plan, team.billing_provider, team.billing_reference, team.paid_through),
            (Team.PLAN_TEAM_ENTERPRISE, Team.PROVIDER_APP_STORE, "2000000000001", store_period),
        )
        self.assertEqual(self.staff_events(), staff_events)

    def test_a_payment_for_a_period_that_has_lapsed_brings_back_and_starts_nothing(self):
        buyer = self.reader("buyer")
        team = self.pay(buyer, self.now + self.days(31)).team
        reader = self.reader("reader")
        self.join(reader, self.join_link_token(team, buyer))
        old_period = self.now - self.days(3)
        self.lapse(buyer, days_ago=3)
        mail.outbox = []

        replay = self.pay(buyer, old_period, paid_at=self.now - self.days(34))
        self.committed(TeamProGrants)

        self.assertEqual(replay.reason, "lapsed")
        self.assertEqual(self.owned_team(buyer).status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(reader), "free")
        self.assertEqual(mail.outbox, [])

        stale = self.reader("stale")
        self.assertEqual(self.pay(stale, old_period).reason, "lapsed")
        self.assertIsNone(self.owned_team(stale))
        self.assertEqual(self.plan_of(stale), "free")
        self.assertEqual(mail.outbox, [])

    def test_an_owner_goes_back_to_a_plan_of_their_own_once_the_team_ends(self):
        lifetime = self.reader("lifetime", "archive")
        store_paid_through = self.now + self.days(200)
        store = self.reader("store", "premium", premium_expire=store_paid_through)
        gifted = self.reader("gifted", "premium")
        owners = (lifetime, store, gifted)
        for user in owners:
            self.pay(user, self.now + self.days(31))
        # Profile.setup_premium_history dates a lifetime plan from the team's payments once they sync, and that
        # date has passed by the lapse.
        Profile.objects.filter(user=lifetime).update(premium_expire=self.now - self.days(1))
        # A plan given while owning the team is still theirs after it, until it ends.
        Profile.objects.get(user=gifted).extend_premium_by_days(365, tier="archive")
        self.assertEqual([self.plan_of(user) for user in owners], ["pro", "pro", "pro"])

        for user in owners:
            self.lapse(user)

        self.assertEqual([self.plan_of(user) for user in owners], ["archive", "premium", "archive"])
        self.assertIsNone(self.premium_expire(lifetime))
        self.assertEqual(self.premium_expire(store), store_paid_through)
        self.assertGreater(self.premium_expire(gifted), self.now + self.days(364))

    def test_the_owner_of_a_lapsed_team_expires_like_any_plan_unless_the_team_comes_back(self):
        lapsed = self.reader("lapsed", "free", feeds=2)
        returning = self.reader("returning", "free")
        # Both teams were paid through 40 days ago, past the usual 30 days an expired plan is kept.
        for user in (lapsed, returning):
            self.pay(user, self.now + self.days(31))
            Profile.objects.filter(user=user).update(premium_expire=self.now - self.days(40))
            self.lapse(user, days_ago=40)
        self.assertEqual(self.plan_of(lapsed), "pro")
        self.pay(returning, self.now + self.days(31))

        PremiumExpire()

        self.assertEqual(self.plan_of(lapsed), "free")
        self.assertEqual(self.muted_sites(lapsed), 2)
        self.assertEqual(self.plan_of(returning), "pro")

        # Paying after their own account expired brings back Pro and the sites the expiry muted.
        self.pay(lapsed, self.now + self.days(31))
        self.assertEqual(self.plan_of(lapsed), "pro")
        self.assertEqual(self.muted_sites(lapsed), 0)

    def test_the_profile_payload_names_the_team_plan_and_shows_billing_to_the_owner_only(self):
        owner = self.reader("teamowner")
        paid_through = self.now + self.days(31)
        team = self.pay(owner, paid_through, plan=Team.PLAN_TEAM_ENTERPRISE).team
        member = self.reader("member")
        self.join(member, self.join_link_token(team, owner))
        solo_pro = self.reader("solopro", "pro", premium_expire=paid_through)
        free = self.reader("free")

        def payload(user):
            profile = Profile.objects.get(user=user)
            with CaptureQueriesContext(connection) as queries:
                data = profile.canonical()
            team_lookups = [query for query in queries.captured_queries if '"team_' in query["sql"]]
            return {key: value for key, value in data.items() if key.startswith("team_")}, len(team_lookups)

        owner_fields, _ = payload(owner)
        member_fields, member_lookups = payload(member)
        self.assertEqual(
            owner_fields,
            dict(
                team_plan=Team.PLAN_TEAM_ENTERPRISE,
                team_role=TeamMember.ROLE_OWNER,
                team_billing_provider=Team.PROVIDER_STRIPE,
                team_paid_through=int(paid_through.strftime("%s")),
                team_pending_plan=None,
                team_pending_owner=None,
            ),
        )
        self.assertEqual(
            member_fields,
            dict(
                team_plan=Team.PLAN_TEAM_ENTERPRISE,
                team_role=TeamMember.ROLE_MEMBER,
                team_billing_provider=None,
                team_paid_through=None,
                team_pending_plan=None,
                team_pending_owner=None,
            ),
        )
        for user in (solo_pro, free):
            self.assertEqual(set(payload(user)[0].values()), {None})
        # The AI filter billing lookup (Profile.usage_billing_profile) and the plan's.
        self.assertLessEqual(member_lookups, 2)
        self.assertEqual(payload(free)[1], 0)

    def test_a_team_owners_renewal_notice_names_the_team_plan(self):
        owner = self.reader("teamowner")
        self.pay(owner, self.now + self.days(31), plan=Team.PLAN_TEAM_ENTERPRISE)
        mail.outbox = []

        Profile.objects.get(user=owner).send_premium_renewal_notice_email(force=True)

        [notice] = mail.outbox
        self.assertIn("$129/month", notice.body)
        self.assertNotIn("$29/month", notice.body)

    def test_each_new_team_gets_a_default_name_within_the_name_rules_and_a_slug_of_its_own(self):
        owners = [self.reader(username) for username in ("samuel", "samuel.", "s" * 150)]

        for user in owners:
            self.pay(user, self.now + self.days(31))

        teams = [self.owned_team(user) for user in owners]
        self.assertEqual(len({team.slug for team in teams}), len(owners))
        for user, team in zip(owners, teams):
            self.assertIn(user.username[:20], team.name)
            self.assertEqual(self.post(user, "rename", team_id=team.pk, name=team.name)["code"], 1)

    def test_the_owners_first_rename_confirms_the_default_name(self):
        buyer = self.reader("buyer")
        team = self.pay(buyer, self.now + self.days(31)).team

        self.assertTrue(self.get(buyer, "")["team"]["name_needs_confirming"])
        self.post(buyer, "rename", team_id=team.pk, name="Desk")
        self.assertFalse(self.get(buyer, "")["team"]["name_needs_confirming"])
        # A team started with a name its owner chose has nothing to confirm.
        self.assertFalse(self.get(self.owner, "")["team"]["name_needs_confirming"])


class Test_TeamBillingAtOnce(TeamClientMixin, TransactionTestCase):
    """Real commits, so two notices of one payment can race."""

    def test_two_notices_of_one_payment_at_once_start_one_team_and_send_one_welcome(self):
        buyer = User.objects.create_user(username="buyer", email="buyer@example.com")
        paid_through = datetime.datetime.now() + datetime.timedelta(days=31)
        paid_at = datetime.datetime.now()
        first = []

        def notice():
            return record_team_payment(
                buyer, Team.PLAN_TEAM, Team.PROVIDER_STRIPE, paid_through, "sub_team", paid_at
            )

        # The first notice's team is written but not committed, so the second can't see it and waits on it.
        _, second = self.while_held(lambda: first.append(notice()), notice)

        self.assertTrue(first[0].created)
        self.assertEqual((second.reason, second.created), (None, False))
        self.assertEqual(Team.objects.filter(owner=buyer).count(), 1)
        self.assertEqual(len(mail.outbox), 1)
        EmailStaffPremiumUpgrade.delay.assert_called_once()


class FakeStripeBilling:
    """apps/team/tests.py: Stripe's records for every customer in a test: subscriptions with their latest invoice
    and any schedule, the charges, and what switching, scheduling, cancelling and refunding do there, including what
    Stripe refuses. A test that reaches Stripe's API anyway fails."""

    MONTH = 31 * 24 * 3600
    YEAR = 365 * 24 * 3600
    ANNUAL_PLANS = ("premium", "archive", "archive_extra")
    AMOUNTS = {
        "premium": 36,
        "archive": 99,
        "archive_extra": 159,
        "pro": 29,
        "team": 79,
        "team_enterprise": 129,
    }

    def __init__(self, test):
        self.subscriptions = []
        self.invoices = {}
        self.charges = []
        self.schedules = {}
        self.released = []
        test.patch(
            stripe._api_requestor._APIRequestor,
            "request_raw",
            side_effect=AssertionError("a test reached Stripe's API"),
        )
        test.patch(stripe.Customer, "retrieve", side_effect=self._customer)
        test.patch(
            stripe.Customer,
            "list",
            side_effect=lambda email: [self._customer(self.customer_id(User.objects.get(email=email)))],
        )
        test.patch(stripe.Charge, "list", side_effect=self._charges)
        test.patch(stripe.Charge, "retrieve", side_effect=self.charge)
        test.patch(stripe.Subscription, "list", side_effect=self._subscriptions)
        test.patch(stripe.Subscription, "retrieve", side_effect=self.subscription)
        self.modify = test.patch(stripe.Subscription, "modify", side_effect=self._modify)
        test.patch(stripe.Invoice, "retrieve", side_effect=self._invoice)
        test.patch(stripe.SubscriptionSchedule, "create", side_effect=self._create_schedule)
        test.patch(stripe.SubscriptionSchedule, "modify", side_effect=self._modify_schedule)
        test.patch(stripe.SubscriptionSchedule, "release", side_effect=self._release_schedule)
        test.patch(
            stripe.SubscriptionSchedule,
            "retrieve",
            side_effect=lambda schedule_id: self.schedules[schedule_id],
        )
        self.checkout = test.patch(
            stripe.checkout.Session,
            "create",
            return_value=MagicMock(url="https://checkout.stripe.com/c/pay/cs_1"),
        )
        test.patch(stripe.Refund, "create", side_effect=self.refund)

    def customer_id(self, user):
        return "cus_%s" % user.username

    def _customer(self, customer_id):
        return MagicMock(id=customer_id, email=None, stripe_id=customer_id)

    def known_customer(self, user):
        """The account paid through Stripe before, so Stripe's events find it by its customer id."""
        Profile.objects.filter(user=user).update(stripe_id=self.customer_id(user))
        StripeIds.objects.get_or_create(user=user, stripe_id=self.customer_id(user))

    def _charges(self, customer, limit=None):
        return MagicMock(
            data=[charge for charge in self.charges[::-1] if charge.customer == customer][:limit]
        )

    def _subscriptions(self, customer, **kwargs):
        # tests.py: cancel_premium_stripe passes the customer object, the others its id.
        customer_id = getattr(customer, "id", customer)
        return MagicMock(
            data=[
                sub
                for sub in self.subscriptions[::-1]
                if sub.customer == customer_id and sub.status != "canceled"
            ]
        )

    def subscription(self, subscription_id):
        return next(sub for sub in self.subscriptions if sub.id == subscription_id)

    def charge(self, charge_id):
        return next(charge for charge in self.charges if charge.id == charge_id)

    def subscribe(self, user, plan, period_end=None, invoice_status="paid", status="active", prices=None):
        """A subscription as Stripe Checkout leaves it, its first invoice paid unless told otherwise. prices gives
        it several items, as the AI filter usage billing subscription has."""
        annual = plan in self.ANNUAL_PLANS
        end = period_end or datetime.datetime.now() + datetime.timedelta(days=365 if annual else 31)
        end = int(end.timestamp())
        index = len(self.subscriptions) + 1
        prices = prices or [Profile.plan_to_stripe_price(plan)]
        subscription = stripe.Subscription.construct_from(
            {
                "id": "sub_%s" % index,
                "object": "subscription",
                "created": int((datetime.datetime.now() - datetime.timedelta(days=30)).timestamp()),
                "customer": self.customer_id(user),
                "status": status,
                "cancel_at": None,
                "cancel_at_period_end": False,
                "schedule": None,
                "current_period_start": end - (self.YEAR if annual else self.MONTH),
                "current_period_end": end,
                "items": {
                    "object": "list",
                    "data": [
                        {"id": "si_%s_%s" % (index, n), "object": "subscription_item", "quantity": 1}
                        for n in range(len(prices))
                    ],
                },
                "latest_invoice": None,
            },
            "sk_test",
        )
        for item, price in zip(subscription["items"].data, prices):
            item["price"] = stripe.Price.construct_from({"id": price, "object": "price"}, "sk_test")
            item["plan"] = stripe.Plan.construct_from(
                {"id": price, "object": "plan", "active": True}, "sk_test"
            )
        subscription["plan"] = subscription["items"].data[0].plan if len(prices) == 1 else None
        self.subscriptions.append(subscription)
        self.invoice(subscription, invoice_status, self.AMOUNTS.get(plan, 1), "subscription_create")
        return subscription

    def set_plan(self, subscription, plan):
        price = Profile.plan_to_stripe_price(plan)
        item = subscription["items"].data[0]
        item["price"] = stripe.Price.construct_from({"id": price, "object": "price"}, "sk_test")
        item["plan"] = stripe.Plan.construct_from({"id": price, "object": "plan", "active": True}, "sk_test")
        subscription["plan"] = item.plan

    def invoice(self, subscription, status, amount, billing_reason="subscription_cycle"):
        """A new latest invoice for the subscription. A paid one has its charge. billing_reason is why Stripe made
        it: the subscription starting, a new period, or a change to the subscription such as a switch. Its line
        charges for the subscription's price over its current period."""
        invoice_id = "in_%s" % (len(self.invoices) + 1)
        self.invoices[invoice_id] = {
            "id": invoice_id,
            "status": status,
            "subscription": subscription.id,
            "billing_reason": billing_reason,
            "lines": {
                "data": [
                    {
                        "amount": amount * 100,
                        "price": {"id": subscription["items"].data[0].price.id},
                        "period": {
                            "start": subscription.current_period_start,
                            "end": subscription.current_period_end,
                        },
                    }
                ]
            },
        }
        subscription["latest_invoice"] = invoice_id
        if status == "paid":
            self.charge_invoice(invoice_id, amount)

    def charge_invoice(self, invoice_id, amount):
        subscription = self.subscription(self.invoices[invoice_id]["subscription"])
        charge = stripe.Charge.construct_from(
            {
                "id": "ch_%s" % (len(self.charges) + 1),
                "object": "charge",
                "customer": subscription.customer,
                "invoice": invoice_id,
                "amount": amount * 100,
                "amount_refunded": 0,
                "created": int(datetime.datetime.now().timestamp()),
                "status": "succeeded",
                "refunded": False,
                "disputed": False,
            },
            "sk_test",
        )
        self.charges.append(charge)
        self.invoices[invoice_id]["charge"] = charge.id
        return charge

    def _invoice(self, invoice_id, expand=None):
        invoice = dict(self.invoices[invoice_id])
        charge_id = invoice.pop("charge", None)
        invoice["charge"] = self.charge(charge_id).to_dict_recursive() if charge_id else None
        if invoice["status"] == "paid" and "status_transitions" not in invoice:
            # tests.py: Stripe records when an invoice was paid, which here is when its charge was made.
            paid_at = invoice["charge"]["created"] if charge_id else int(datetime.datetime.now().timestamp())
            invoice["status_transitions"] = {"paid_at": paid_at}
        return stripe.Invoice.construct_from(invoice, "sk_test")

    def latest_charge(self, subscription):
        return self.charge(self.invoices[subscription.latest_invoice]["charge"])

    def renew(self, subscription, invoice_status="draft", status="active"):
        """The next period starts. Stripe charges its invoice about an hour later, and a failed charge leaves the
        subscription past due."""
        start = subscription.current_period_end
        subscription["current_period_start"] = start
        subscription["current_period_end"] = start + self.MONTH
        subscription["status"] = status
        self.invoice(subscription, invoice_status, 79)

    def pay_latest_invoice(self, subscription):
        invoice = self.invoices[subscription.latest_invoice]
        invoice["status"] = "paid"
        self.charge_invoice(invoice["id"], self.AMOUNTS[Profile.stripe_price_plan(subscription.plan.id)])
        subscription["status"] = "active"

    def _modify(self, subscription_id, **changes):
        subscription = self.subscription(subscription_id)
        if subscription.schedule and ("items" in changes or "cancel_at_period_end" in changes):
            raise stripe.error.InvalidRequestError(
                "The subscription is managed by the subscription schedule `%s`." % subscription.schedule, None
            )
        if "cancel_at_period_end" in changes:
            subscription["cancel_at_period_end"] = changes["cancel_at_period_end"]
            subscription["cancel_at"] = (
                subscription.current_period_end if changes["cancel_at_period_end"] else None
            )
        if changes.get("items"):
            old_plan = Profile.stripe_price_plan(subscription.plan.id)
            new_plan = Profile.stripe_price_plan(changes["items"][0]["price"])
            self.set_plan(subscription, new_plan)
            if (old_plan in self.ANNUAL_PLANS) != (new_plan in self.ANNUAL_PLANS):
                # tests.py: a new billing interval starts its first period now.
                now = int(datetime.datetime.now().timestamp())
                subscription["current_period_start"] = now
                subscription["current_period_end"] = now + self.MONTH
            if changes.get("proration_behavior") == "always_invoice":
                self.invoice(subscription, "paid", 50, "subscription_update")
        return subscription

    def _create_schedule(self, from_subscription):
        subscription = self.subscription(from_subscription)
        if subscription.schedule or subscription.cancel_at_period_end:
            raise stripe.error.InvalidRequestError("This subscription can't take a schedule.", None)
        schedule_id = "sub_sched_%s" % (len(self.schedules) + 1)
        phase = {
            "start_date": subscription.current_period_start,
            "end_date": subscription.current_period_end,
            "items": [{"price": subscription.plan.id, "quantity": 1}],
        }
        self.schedules[schedule_id] = stripe.SubscriptionSchedule.construct_from(
            {
                "id": schedule_id,
                "object": "subscription_schedule",
                "subscription": subscription.id,
                "current_phase": {"start_date": phase["start_date"], "end_date": phase["end_date"]},
                "phases": [phase],
            },
            "sk_test",
        )
        subscription["schedule"] = schedule_id
        return self.schedules[schedule_id]

    def _modify_schedule(self, schedule_id, phases, **settings):
        schedule = self.schedules[schedule_id]
        built = []
        for phase in phases:
            start = phase.get("start_date") or built[-1]["end_date"]
            end = phase.get("end_date") or start + self.MONTH * phase.get("iterations", 1)
            built.append(dict(phase, start_date=start, end_date=end))
        schedule["phases"] = built
        schedule["end_behavior"] = settings.get("end_behavior")
        return schedule

    def _release_schedule(self, schedule_id):
        for subscription in self.subscriptions:
            if subscription.schedule == schedule_id:
                subscription["schedule"] = None
        self.released.append(schedule_id)

    def reach_next_phase(self, subscription, invoice_status="paid"):
        """The period paid for ends, the schedule moves the subscription to its next phase's price, and Stripe
        charges that period's invoice. A charge that fails leaves the invoice open and the subscription past
        due."""
        schedule = self.schedules[subscription.schedule]
        plan = Profile.stripe_price_plan(schedule["phases"][1]["items"][0]["price"])
        start = subscription.current_period_end
        self.set_plan(subscription, plan)
        subscription["current_period_start"] = start
        subscription["current_period_end"] = start + (self.YEAR if plan in self.ANNUAL_PLANS else self.MONTH)
        subscription["schedule"] = None
        subscription["status"] = "active" if invoice_status == "paid" else "past_due"
        self.invoice(subscription, invoice_status, self.AMOUNTS[plan])

    def refund(self, charge, amount=None):
        charge = self.charge(charge)
        charge["amount_refunded"] = amount or charge.amount
        charge["refunded"] = charge.amount_refunded >= charge.amount
        return MagicMock(id="re_%s" % charge.id)

    def subscription_event(self, subscription):
        """customer.subscription.* as the webhook delivers it."""
        return {
            "id": subscription.id,
            "customer": subscription.customer,
            "status": "active",
            "plan": {"id": subscription.plan.id, "active": True},
            "cancel_at": subscription.cancel_at,
            "items": {"data": []},
        }

    def invoice_event(self, subscription):
        """invoice.paid as the webhook delivers it."""
        return {"id": subscription.latest_invoice, "customer": subscription.customer}


@override_settings(**USAGE_PRICES)
class Test_TeamStripeBilling(TeamProMixin, TestCase):
    """apps/team/stripe_billing.py: team plans bought, renewed, switched, cancelled and refunded through Stripe."""

    def setUp(self):
        super().setUp()
        self.stripe = FakeStripeBilling(self)
        self.staff = User.objects.create_user(username="staff", is_staff=True)

    def stripe_event(self, event_type, obj):
        """apps/team/tests.py: a Stripe event posted to the webhook, with what it queued for after its commit run in
        place."""
        queued = len(connection.run_on_commit)
        response = Client().post(
            reverse("zebra:webhooks_v2"),
            json.encode({"type": event_type, "data": {"object": obj}}),
            content_type="application/json",
        )
        callbacks = connection.run_on_commit[queued:]
        del connection.run_on_commit[queued:]
        for _, callback in callbacks:
            callback()
        self.assertEqual(response.status_code, 200)

    def paid_through(self, subscription):
        return datetime.datetime.fromtimestamp(subscription.current_period_end)

    def team_owner(self, username, plan=Team.PLAN_TEAM, period_end=None):
        """apps/team/tests.py: an owner whose team a paid Stripe subscription bills, and the subscription."""
        owner = self.reader(username)
        self.stripe.known_customer(owner)
        subscription = self.stripe.subscribe(owner, plan, period_end=period_end)
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))
        self.assertEqual(self.owned_team(owner).billing_reference, subscription.id)
        return owner, subscription

    def test_a_checkout_starts_one_team_whatever_order_its_events_arrive_in(self):
        buyer = self.reader("buyer", "free", feeds=2)
        subscription = self.stripe.subscribe(buyer, Team.PLAN_TEAM)
        # A usage billing subscription started after the team's, which Stripe lists ahead of it.
        self.stripe.subscribe(
            buyer, "usage", invoice_status="draft", prices=["price_text_classifier", "price_image_classifier"]
        )
        charge = self.stripe.latest_charge(subscription)

        # Stripe sends these before checkout.session.completed stores the customer on the account.
        self.stripe_event("customer.subscription.created", self.stripe.subscription_event(subscription))
        self.stripe_event("charge.succeeded", {"id": charge.id, "customer": charge.customer})
        self.assertIsNone(self.owned_team(buyer))
        self.stripe_event(
            "checkout.session.completed",
            {
                "customer": subscription.customer,
                "subscription": subscription.id,
                "metadata": {"newsblur_user_id": str(buyer.pk)},
            },
        )
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))

        [team] = Team.objects.filter(owner=buyer)
        self.assertEqual(
            (team.plan, team.status, team.billing_provider, team.billing_reference, team.paid_through),
            (
                Team.PLAN_TEAM,
                Team.STATUS_ACTIVE,
                Team.PROVIDER_STRIPE,
                subscription.id,
                self.paid_through(subscription),
            ),
        )
        self.assertEqual(self.plan_of(buyer), "pro")
        self.assertEqual(self.muted_sites(buyer), 0)
        [welcome] = self.mail_to(buyer)
        self.assertIn("?next=team", welcome.body)
        EmailNewPremium.delay.assert_not_called()
        EmailNewPremiumPro.delay.assert_not_called()
        EmailStaffPremiumUpgrade.delay.assert_called_once_with(
            user_id=buyer.pk, tier=Team.PLAN_TEAM, previous_tier="free"
        )

    def test_a_team_starts_only_once_stripe_shows_its_invoice_paid(self):
        buyer = self.reader("buyer")
        self.stripe.known_customer(buyer)
        subscription = self.stripe.subscribe(
            buyer, Team.PLAN_TEAM, invoice_status="open", status="incomplete"
        )

        # The event says the subscription is active on the team price. Stripe says otherwise.
        self.stripe_event("customer.subscription.created", self.stripe.subscription_event(subscription))
        self.assertIsNone(self.owned_team(buyer))

        # Charged, but the invoice isn't marked paid yet: neither a team nor Premium.
        subscription["status"] = "active"
        charge = self.stripe.charge_invoice(subscription.latest_invoice, 79)
        self.stripe_event("charge.succeeded", {"id": charge.id, "customer": charge.customer})
        self.assertIsNone(self.owned_team(buyer))
        self.assertEqual(self.plan_of(buyer), "free")
        EmailNewPremium.delay.assert_not_called()

        self.stripe.invoices[subscription.latest_invoice]["status"] = "paid"
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))
        self.assertEqual(self.owned_team(buyer).paid_through, self.paid_through(subscription))
        self.assertEqual(self.plan_of(buyer), "pro")

    def test_only_a_charged_renewal_moves_the_paid_period(self):
        owner, subscription = self.team_owner("teamowner")
        first_period = self.paid_through(subscription)

        # The new period starts before Stripe charges it, and then the charge fails.
        self.stripe.renew(subscription)
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.assertEqual(self.owned_team(owner).paid_through, first_period)
        self.stripe.invoices[subscription.latest_invoice]["status"] = "open"
        subscription["status"] = "past_due"
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        TeamProGrants()
        team = self.owned_team(owner)
        self.assertEqual((team.paid_through, team.status), (first_period, Team.STATUS_ACTIVE))

        self.stripe.pay_latest_invoice(subscription)
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))
        self.assertEqual(self.owned_team(owner).paid_through, self.paid_through(subscription))

    def test_a_recovered_payment_brings_a_lapsed_team_back(self):
        owner, subscription = self.team_owner("teamowner")
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))
        # Its first month ended two days ago.
        subscription["current_period_end"] = int((self.now - self.days(2)).timestamp())
        Team.objects.filter(owner=owner).update(paid_through=self.paid_through(subscription))
        self.stripe.renew(subscription, invoice_status="open", status="past_due")
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.committed(TeamProGrants)
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(member), "free")

        self.stripe.pay_latest_invoice(subscription)
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))

        team = self.owned_team(owner)
        self.assertEqual(
            (team.status, team.paid_through), (Team.STATUS_ACTIVE, self.paid_through(subscription))
        )
        self.assertEqual(self.plan_of(member), "pro")

    def test_a_teammate_or_an_owner_billed_elsewhere_cannot_buy_a_team(self):
        member = self.reader("member")
        self.join(member)
        store_owner = self.reader("storeowner")
        self.pay(store_owner, self.now + self.days(20), provider=Team.PROVIDER_APP_STORE, reference="2000001")
        for buyer, reason in ((member, "on_team"), (store_owner, "team_billed_elsewhere")):
            self.stripe.known_customer(buyer)
            self.stripe.subscribe(buyer, "premium")
            for path in ("stripe_checkout", "switch_stripe_subscription"):
                response = self.profile_post(buyer, path, plan=Team.PLAN_TEAM_ENTERPRISE)
                self.assertIn("team_purchase=%s" % reason, response["Location"])
        self.stripe.checkout.assert_not_called()
        self.stripe.modify.assert_not_called()
        self.assertIsNone(self.owned_team(member))
        self.assertEqual(self.owned_team(store_owner).billing_provider, Team.PROVIDER_APP_STORE)

        # Anyone else goes to Stripe Checkout, and comes back to a page that waits for the team.
        buyer = self.reader("buyer")
        response = self.profile_post(buyer, "stripe_checkout", plan=Team.PLAN_TEAM)
        self.assertEqual(response["Location"], "https://checkout.stripe.com/c/pay/cs_1")
        session = self.stripe.checkout.call_args.kwargs
        self.assertEqual(session["line_items"][0]["price"], Profile.plan_to_stripe_price(Team.PLAN_TEAM))
        self.assertTrue(session["success_url"].endswith("%s?plan=team" % reverse("stripe-return")))

    def test_a_stripe_plan_switches_up_to_a_team_plan_at_once_on_the_same_subscription(self):
        subscriber = self.reader("subscriber", "premium", premium_expire=self.now + self.days(200))
        self.stripe.known_customer(subscriber)
        subscription = self.stripe.subscribe(subscriber, "premium")

        response = self.profile_post(subscriber, "switch_stripe_subscription", plan=Team.PLAN_TEAM)

        self.assertTrue(response["Location"].endswith("%s?plan=team" % reverse("stripe-return")))
        [switch] = self.stripe.modify.call_args_list
        self.assertEqual(switch.args, (subscription.id,))
        self.assertEqual(switch.kwargs["proration_behavior"], "always_invoice")
        self.assertEqual(switch.kwargs["items"][0]["price"], Profile.plan_to_stripe_price(Team.PLAN_TEAM))
        self.stripe.checkout.assert_not_called()
        self.assertEqual(len(self.stripe.subscriptions), 1)
        team = self.owned_team(subscriber)
        self.assertEqual((team.plan, team.billing_reference), (Team.PLAN_TEAM, subscription.id))
        self.assertEqual(self.plan_of(subscriber), "pro")

        # Team up to Enterprise is at once too.
        self.profile_post(subscriber, "switch_stripe_subscription", plan=Team.PLAN_TEAM_ENTERPRISE)
        self.assertEqual(self.stripe.modify.call_args.kwargs["proration_behavior"], "always_invoice")
        self.assertEqual(self.owned_team(subscriber).plan, Team.PLAN_TEAM_ENTERPRISE)

    def test_switching_down_from_a_team_plan_keeps_the_team_until_the_paid_month_ends(self):
        owner, subscription = self.team_owner("teamowner", plan=Team.PLAN_TEAM_ENTERPRISE)
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))
        period_end = subscription.current_period_end

        for plan in (Team.PLAN_TEAM, "pro"):
            self.profile_post(owner, "switch_stripe_subscription", plan=plan)

            schedule = self.stripe.schedules[subscription.schedule]
            self.assertEqual(schedule["phases"][0]["end_date"], period_end)
            self.assertEqual(schedule["phases"][1]["items"][0]["price"], Profile.plan_to_stripe_price(plan))
            team = self.owned_team(owner)
            self.assertEqual(
                (team.plan, team.status, team.paid_through),
                (Team.PLAN_TEAM_ENTERPRISE, Team.STATUS_ACTIVE, self.paid_through(subscription)),
            )
            self.assertEqual(Profile.objects.get(user=owner).canonical()["team_pending_plan"], plan)
            self.assertIsNone(Profile.objects.get(user=member).canonical()["team_pending_plan"])
        self.stripe.modify.assert_not_called()
        self.assertEqual(self.plan_of(member), "pro")

        # Choosing the plan paid for again drops the scheduled switch.
        self.profile_post(owner, "switch_stripe_subscription", plan=Team.PLAN_TEAM_ENTERPRISE)
        self.assertIsNone(subscription.schedule)
        self.assertIsNone(Profile.objects.get(user=owner).canonical()["team_pending_plan"])

        # A lower price put on the subscription some other way still waits for the month paid for.
        self.stripe.set_plan(subscription, "pro")
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_ACTIVE)

    def test_a_switch_down_starts_the_lower_plan_once_the_paid_month_ends(self):
        # Both months ended an hour ago, which is when Stripe moves a subscription on to its next phase.
        period_end = self.now - datetime.timedelta(hours=1)
        down, down_subscription = self.team_owner("down", period_end=period_end)
        member = self.reader("member", "archive", premium_expire=self.now + self.days(100))
        self.join(member, self.join_link_token(self.owned_team(down), down))
        enterprise, enterprise_subscription = self.team_owner(
            "enterprise", plan=Team.PLAN_TEAM_ENTERPRISE, period_end=period_end
        )
        # An owner who also has Archive of their own until well after the switch keeps it.
        kept = self.reader("kept", "archive", premium_expire=self.now + self.days(200))
        self.stripe.known_customer(kept)
        kept_subscription = self.stripe.subscribe(kept, Team.PLAN_TEAM, period_end=period_end)
        self.stripe_event("invoice.paid", self.stripe.invoice_event(kept_subscription))
        for owner in (down, kept):
            self.profile_post(owner, "switch_stripe_subscription", plan="premium")
        self.profile_post(enterprise, "switch_stripe_subscription", plan=Team.PLAN_TEAM)
        self.assertEqual(self.owned_team(down).status, Team.STATUS_ACTIVE)

        for subscription in (down_subscription, enterprise_subscription, kept_subscription):
            self.stripe.reach_next_phase(subscription)
            self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
            self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))

        team = self.owned_team(down)
        self.assertEqual((team.status, team.pending_plan), (Team.STATUS_INACTIVE, None))
        self.assertEqual(self.plan_of(down), "premium")
        self.assertEqual(self.plan_of(member), "archive")
        self.assertEqual(
            (self.owned_team(kept).status, self.plan_of(kept)), (Team.STATUS_INACTIVE, "archive")
        )
        team = self.owned_team(enterprise)
        self.assertEqual(
            (team.plan, team.status, team.paid_through, team.pending_plan),
            (Team.PLAN_TEAM, Team.STATUS_ACTIVE, self.paid_through(enterprise_subscription), None),
        )
        self.assertEqual(self.plan_of(enterprise), "pro")

    def test_cancelling_runs_to_the_end_of_the_paid_month_and_keeps_the_team(self):
        owner, subscription = self.team_owner("teamowner")
        self.profile_post(owner, "switch_stripe_subscription", plan="pro")
        schedule_id = subscription.schedule

        self.profile_post(owner, "cancel_premium")

        self.assertEqual(self.stripe.released, [schedule_id])
        self.assertTrue(subscription.cancel_at_period_end)
        team = self.owned_team(owner)
        self.assertEqual(
            (team.status, team.paid_through, team.pending_plan),
            (Team.STATUS_ACTIVE, self.paid_through(subscription), None),
        )
        # Stripe ending the subscription changes nothing until the month paid for has passed (apps/team/tasks.py).
        subscription["status"] = "canceled"
        self.stripe_event("customer.subscription.deleted", self.stripe.subscription_event(subscription))
        TeamProGrants()
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_ACTIVE)

    def test_a_full_refund_ends_the_team_at_once_for_good(self):
        owner, subscription = self.team_owner("teamowner")
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))

        # A partial refund is a credit, not the end of the team.
        self.profile_post(self.staff, "refund_premium", user_id=owner.pk, partial="true")
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_ACTIVE)

        self.profile_post(self.staff, "refund_premium", user_id=owner.pk)

        team = self.owned_team(owner)
        self.assertEqual(team.status, Team.STATUS_INACTIVE)
        self.assertLess(team.paid_through, datetime.datetime.now())
        self.assertEqual(self.plan_of(member), "free")
        # Later events for the subscription, which Stripe still shows as paid up, don't bring it back.
        charge = self.stripe.latest_charge(subscription)
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.stripe_event("charge.refunded", {"id": charge.id, "customer": charge.customer})
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_INACTIVE)
        # The owner, with no plan of their own, expires from now through the usual window, not from the end of the
        # month the refund paid back.
        self.assertEqual(self.plan_of(owner), "pro")
        self.assertLessEqual(self.premium_expire(owner), datetime.datetime.now())

    def test_a_refund_made_in_stripe_or_a_dispute_ends_the_team(self):
        refunded, refunded_subscription = self.team_owner("refunded")
        disputed, disputed_subscription = self.team_owner("disputed")

        refunded_charge = self.stripe.latest_charge(refunded_subscription)
        self.stripe.refund(refunded_charge.id)
        self.stripe_event("charge.refunded", {"id": refunded_charge.id, "customer": refunded_charge.customer})
        disputed_charge = self.stripe.latest_charge(disputed_subscription)
        disputed_charge["disputed"] = True
        self.stripe_event("charge.dispute.created", {"id": "dp_1", "charge": disputed_charge.id})

        for owner, subscription in ((refunded, refunded_subscription), (disputed, disputed_subscription)):
            self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
            self.assertEqual(self.owned_team(owner).status, Team.STATUS_INACTIVE)
            self.assertEqual(self.plan_of(owner), "pro")
            self.assertLessEqual(self.premium_expire(owner), datetime.datetime.now())

    def test_a_stripe_purchase_while_paypal_bills_the_team_stops_the_paypal_renewal(self):
        owner = self.reader("teamowner")
        self.pay(
            owner,
            self.now + self.days(20),
            provider=Team.PROVIDER_PAYPAL,
            reference="I-TEAM",
            paid_at=self.now - self.days(11),
        )
        Profile.objects.filter(user=owner).update(paypal_sub_id="I-TEAM")
        PaypalIds.objects.create(user=owner, paypal_sub_id="I-TEAM")
        paypal = FakePayPal(self, "I-TEAM")
        self.stripe.known_customer(owner)
        subscription = self.stripe.subscribe(owner, Team.PLAN_TEAM_ENTERPRISE)

        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))

        team = self.owned_team(owner)
        self.assertEqual(
            (team.plan, team.billing_provider, team.billing_reference),
            (Team.PLAN_TEAM_ENTERPRISE, Team.PROVIDER_STRIPE, subscription.id),
        )
        self.assertEqual(paypal.posts, ["/v1/billing/subscriptions/I-TEAM/suspend"])
        self.assertEqual(self.staff_events(), ["team_paid_twice"])

    def test_a_stripe_payment_older_than_the_teams_newest_leaves_its_billing_alone(self):
        owner, subscription = self.team_owner("teamowner")
        # Stripe was paid two days before the owner bought Enterprise in the App Store.
        self.stripe.invoices[subscription.latest_invoice]["status_transitions"] = {
            "paid_at": int((self.now - self.days(2)).timestamp())
        }
        self.pay(
            owner,
            self.now + self.days(31),
            plan=Team.PLAN_TEAM_ENTERPRISE,
            provider=Team.PROVIDER_APP_STORE,
            reference="2000001",
        )

        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))

        team = self.owned_team(owner)
        self.assertEqual(
            (team.plan, team.billing_provider, team.billing_reference),
            (Team.PLAN_TEAM_ENTERPRISE, Team.PROVIDER_APP_STORE, "2000001"),
        )

    def test_an_owner_gets_back_a_plan_kept_beside_the_team_but_not_one_switched_into_it(self):
        lifetime = self.reader("lifetime", "archive")
        self.stripe.known_customer(lifetime)
        subscription = self.stripe.subscribe(lifetime, Team.PLAN_TEAM)
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))
        self.assertEqual(self.plan_of(lifetime), "pro")

        self.profile_post(self.staff, "refund_premium", user_id=lifetime.pk)

        self.assertEqual(self.owned_team(lifetime).status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(lifetime), "archive")
        self.assertIsNone(self.premium_expire(lifetime))

        # A Premium subscription switched to a team plan became the team's, so it isn't put back.
        subscriber = self.reader("subscriber", "premium", premium_expire=self.now + self.days(200))
        self.stripe.known_customer(subscriber)
        self.stripe.subscribe(subscriber, "premium")
        self.profile_post(subscriber, "switch_stripe_subscription", plan=Team.PLAN_TEAM)
        self.assertEqual(self.plan_of(subscriber), "pro")

        self.lapse(subscriber)

        self.assertEqual(self.owned_team(subscriber).status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(subscriber), "pro")
        self.assertFalse(TeamProGrant.objects.filter(user=subscriber).exists())

    def test_a_stripe_subscription_set_to_end_leaves_the_team_with_the_provider_billing_it(self):
        owner, subscription = self.team_owner("teamowner")
        subscription["cancel_at_period_end"] = True
        subscription["cancel_at"] = subscription.current_period_end
        self.pay(owner, self.now + self.days(31), provider=Team.PROVIDER_APP_STORE, reference="2000001")

        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))

        self.assertEqual(self.owned_team(owner).billing_provider, Team.PROVIDER_APP_STORE)

    def test_a_paypal_renewal_a_stripe_purchase_replaces_is_retried_and_then_goes_to_staff(self):
        owner = self.reader("teamowner")
        self.pay(
            owner,
            self.now + self.days(20),
            provider=Team.PROVIDER_PAYPAL,
            reference="I-TEAM",
            paid_at=self.now - self.days(11),
        )
        Profile.objects.filter(user=owner).update(paypal_sub_id="I-TEAM")
        PaypalIds.objects.create(user=owner, paypal_sub_id="I-TEAM")
        paypal = FakePayPal(self, "I-TEAM")
        # PayPal answers every suspend, but the subscription goes on renewing.
        paypal.suspends = False
        self.stripe.known_customer(owner)
        subscription = self.stripe.subscribe(owner, Team.PLAN_TEAM_ENTERPRISE)

        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))

        self.assertEqual(self.owned_team(owner).billing_reference, subscription.id)
        self.assertEqual(paypal.status, "ACTIVE")
        self.assertGreater(paypal.posts.count("/v1/billing/subscriptions/I-TEAM/suspend"), 1)
        self.assertEqual(self.staff_events(), ["team_paid_twice", "team_renewal_unconfirmed"])
        # The subscription that bills the team now keeps renewing.
        self.assertFalse(subscription.cancel_at_period_end)

    def test_a_payment_that_renews_the_team_first_keeps_it_from_an_older_refund_or_switch_down(self):
        refunded, refunded_subscription = self.team_owner("refunded")
        down, down_subscription = self.team_owner("down", period_end=self.now - datetime.timedelta(hours=1))
        self.profile_post(down, "switch_stripe_subscription", plan="premium")

        def renewed_first(owner, end_team):
            def renew_then_end(*args, **kwargs):
                # An App Store payment commits after the Stripe event read the team and before it ends the team.
                self.pay(
                    owner, self.now + self.days(31), provider=Team.PROVIDER_APP_STORE, reference="2000001"
                )
                return end_team(*args, **kwargs)

            return renew_then_end

        charge = self.stripe.latest_charge(refunded_subscription)
        self.stripe.refund(charge.id)
        with patch.object(
            stripe_billing, "end_team_now", side_effect=renewed_first(refunded, stripe_billing.end_team_now)
        ):
            self.stripe_event("charge.refunded", {"id": charge.id, "customer": charge.customer})
        self.stripe.reach_next_phase(down_subscription)
        with patch.object(
            stripe_billing,
            "end_team_switched_down",
            side_effect=renewed_first(down, stripe_billing.end_team_switched_down),
        ):
            self.stripe_event(
                "customer.subscription.updated", self.stripe.subscription_event(down_subscription)
            )

        for owner in (refunded, down):
            team = self.owned_team(owner)
            self.assertEqual(
                (team.status, team.billing_provider), (Team.STATUS_ACTIVE, Team.PROVIDER_APP_STORE)
            )
            self.assertEqual(self.plan_of(owner), "pro")

    def test_a_switch_down_whose_first_charge_fails_starts_the_lower_plan_only_once_stripe_collects_it(self):
        owner, subscription = self.team_owner("teamowner", period_end=self.now - datetime.timedelta(hours=1))
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))
        self.profile_post(owner, "switch_stripe_subscription", plan="premium")

        # The month paid for ends and the subscription moves to Premium, whose first charge fails.
        self.stripe.reach_next_phase(subscription, invoice_status="open")
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))

        team = self.owned_team(owner)
        self.assertEqual((team.status, team.pending_plan), (Team.STATUS_INACTIVE, "premium"))
        # The owner, with no plan of their own, has the usual expiry window, not a Premium nobody paid for.
        self.assertEqual((self.plan_of(owner), self.plan_of(member)), ("pro", "free"))
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.assertEqual(self.plan_of(owner), "pro")

        # Stripe collects it on a later try.
        self.stripe.pay_latest_invoice(subscription)
        self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))

        self.assertEqual(self.plan_of(owner), "premium")
        self.assertIsNone(self.owned_team(owner).pending_plan)

    def test_an_owner_gets_back_a_plan_of_their_own_only_until_it_ends(self):
        own_end = self.now + self.days(3)
        archive_owner = self.reader("archiveowner", "archive", premium_expire=own_end)
        lapsed = self.reader("lapsed", "archive", premium_expire=own_end)
        credited = self.reader("credited")
        owners = (archive_owner, lapsed, credited)
        for owner in owners:
            self.stripe.known_customer(owner)
            subscription = self.stripe.subscribe(owner, Team.PLAN_TEAM)
            self.stripe_event("invoice.paid", self.stripe.invoice_event(subscription))
            self.assertGreater(self.premium_expire(owner), own_end)
        # Ten days of Premium given while owning the team are a plan of their own.
        Profile.objects.get(user=credited).extend_premium_by_days(10)

        for owner in (archive_owner, credited):
            self.profile_post(self.staff, "refund_premium", user_id=owner.pk)
        self.lapse(lapsed)

        for owner in (archive_owner, lapsed):
            self.assertEqual((self.plan_of(owner), self.premium_expire(owner)), ("archive", own_end))
        self.assertEqual(self.plan_of(credited), "premium")
        self.assertLess(self.premium_expire(credited), self.now + self.days(11))

    def test_a_subscription_switched_down_to_an_own_plan_is_that_plan_from_then_on(self):
        owner, subscription = self.team_owner("teamowner", period_end=self.now - datetime.timedelta(hours=1))
        self.profile_post(owner, "switch_stripe_subscription", plan="archive")
        self.stripe.reach_next_phase(subscription)
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.assertEqual(self.plan_of(owner), "archive")
        self.assertFalse(subscription.cancel_at_period_end)

        # The owner changes that subscription's plan again, to Pro, and then back up to Premium Team.
        self.profile_post(owner, "switch_stripe_subscription", plan="pro")
        self.stripe_event("customer.subscription.updated", self.stripe.subscription_event(subscription))
        self.assertEqual(self.plan_of(owner), "pro")
        self.profile_post(owner, "switch_stripe_subscription", plan=Team.PLAN_TEAM)

        team = self.owned_team(owner)
        self.assertEqual((team.status, team.billing_reference), (Team.STATUS_ACTIVE, subscription.id))
        # Pro was switched into the team with proration, so it isn't a plan of their own to go back to.
        self.assertEqual(TeamProGrant.objects.get(user=owner).own_tier, TeamProGrant.TIER_FREE)


def paypal_time(moment):
    """apps/team/tests.py: a local time as PayPal writes times, in UTC to the second."""
    return moment.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def local_time(paypal_moment):
    return datetime.datetime.fromtimestamp(dateutil.parser.parse(paypal_moment).timestamp())


class FakePayPalBilling:
    """apps/team/tests.py: PayPal's records for every account in a test: subscriptions with their billing info and
    transactions, plans with their billing cycles, and what creating, approving, charging, suspending and refunding
    do there. A test that reaches PayPal's API anyway fails."""

    MONTHLY_PLANS = ("pro", "team", "team_enterprise")
    AMOUNTS = {
        "premium": 36,
        "archive": 99,
        "archive_extra": 159,
        "pro": 29,
        "team": 79,
        "team_enterprise": 129,
    }

    def __init__(self, test):
        self.subscriptions = {}
        self.transactions = {}
        self.created = []
        self.refunds = []
        self.clock = datetime.datetime.now()
        test.patch(profile_models.paypalrestsdk, "Api", return_value=self)
        test.patch(
            paypalrestsdk.api.Api, "http_call", side_effect=AssertionError("a test reached PayPal's API")
        )

    def plan(self, subscription):
        return Profile.paypal_plan(subscription["plan_id"])

    def subscribe(self, user, plan, created=None, start=None, status="ACTIVE"):
        """A subscription to plan the account approved through PayPal's button, made at created or else just after
        the last one. It bills from start, at once unless a switch scheduled it, and has no payment until charged.
        """
        if not created:
            self.clock = created = max(datetime.datetime.now(), self.clock + datetime.timedelta(seconds=1))
        subscription = {
            "id": "I-%s%s" % (plan.upper().replace("_", ""), len(self.subscriptions) + 1),
            "status": status,
            "plan_id": Profile.plan_to_paypal_plan_id(plan),
            "custom_id": str(user.pk),
            "create_time": paypal_time(created),
            "start_time": paypal_time(start or created),
            "billing_info": {
                "next_billing_time": paypal_time(start or created),
                "failed_payments_count": 0,
                "outstanding_balance": {"currency_code": "USD", "value": "0.0"},
            },
        }
        self.subscriptions[subscription["id"]] = subscription
        self.transactions[subscription["id"]] = []
        return subscription

    def known(self, user, subscription):
        """The account paid through PayPal before, so its history sync reads this subscription."""
        Profile.objects.filter(user=user).update(paypal_sub_id=subscription["id"])
        PaypalIds.objects.create(user=user, paypal_sub_id=subscription["id"])

    def approve(self, subscription):
        subscription["status"] = "ACTIVE"
        return subscription

    def period(self, subscription):
        if self.plan(subscription) in self.MONTHLY_PLANS:
            return relativedelta(months=1)
        return relativedelta(years=1)

    def charge(self, subscription, at=None):
        """PayPal collects the subscription's payment for the cycle starting at at, or now, and bills the next cycle
        a period later."""
        at = at or datetime.datetime.now()
        amount = "%.2f" % self.AMOUNTS[self.plan(subscription)]
        transaction = {
            "id": "TX%s" % (sum(len(transactions) for transactions in self.transactions.values()) + 1),
            "status": "COMPLETED",
            "time": paypal_time(at),
            "amount_with_breakdown": {"gross_amount": {"currency_code": "USD", "value": amount}},
        }
        # tests.py: PayPal lists a subscription's newest transaction first.
        self.transactions[subscription["id"]].insert(0, transaction)
        subscription["status"] = "ACTIVE"
        subscription["billing_info"].update(
            last_payment={"time": paypal_time(at), "amount": {"currency_code": "USD", "value": amount}},
            next_billing_time=paypal_time(at + self.period(subscription)),
            failed_payments_count=0,
            outstanding_balance={"currency_code": "USD", "value": "0.0"},
        )
        return transaction

    def fail_renewal(self, subscription):
        """PayPal couldn't collect the next cycle's payment. It moves on to the cycle after and holds the amount as
        outstanding."""
        billing_info = subscription["billing_info"]
        next_billing = local_time(billing_info["next_billing_time"])
        billing_info["next_billing_time"] = paypal_time(next_billing + self.period(subscription))
        billing_info["failed_payments_count"] += 1
        billing_info["outstanding_balance"] = {
            "currency_code": "USD",
            "value": "%.2f" % self.AMOUNTS[self.plan(subscription)],
        }

    def take_back(self, subscription, status):
        """PayPal took the subscription's latest payment back, refunded in its dashboard or reversed after a
        dispute."""
        transaction = self.transactions[subscription["id"]][0]
        transaction["status"] = status
        return transaction

    def next_billing(self, subscription):
        return local_time(subscription["billing_info"]["next_billing_time"])

    def latest_payment(self, subscription):
        return self.transactions[subscription["id"]][0]

    def _transaction(self, transaction_id):
        return next(
            (subscription_id, transaction)
            for subscription_id, transactions in self.transactions.items()
            for transaction in transactions
            if transaction["id"] == transaction_id
        )

    def get(self, url):
        path = url.split("?")[0]
        parts = path.strip("/").split("/")
        if path.startswith("/v1/billing/subscriptions/") and path.endswith("/transactions"):
            return {"transactions": copy.deepcopy(self.transactions[parts[3]])}
        if path.startswith("/v1/billing/subscriptions/"):
            if parts[3] not in self.subscriptions:
                raise paypalrestsdk.ResourceNotFound(MagicMock())
            subscription = copy.deepcopy(self.subscriptions[parts[3]])
            if "fields=plan" in url:
                # tests.py: asked for, PayPal includes the subscription's plan with its billing cycles.
                subscription["plan"] = self.get("/v1/billing/plans/%s" % subscription["plan_id"])
            return subscription
        if path.startswith("/v1/billing/plans/"):
            unit = "MONTH" if Profile.paypal_plan(parts[3]) in self.MONTHLY_PLANS else "YEAR"
            return {
                "id": parts[3],
                "billing_cycles": [
                    {"tenure_type": "REGULAR", "frequency": {"interval_unit": unit, "interval_count": 1}}
                ],
            }
        if path.startswith("/v1/payments/sale/"):
            subscription_id, transaction = self._transaction(parts[3])
            return {"id": transaction["id"], "billing_agreement_id": subscription_id}
        raise AssertionError("PayPal has no GET %s" % url)

    def post(self, url, data):
        path = url.split("?")[0]
        parts = path.strip("/").split("/")
        if path == "/v1/billing/subscriptions":
            user = User.objects.get(pk=data["custom_id"])
            start = local_time(data["start_time"]) if "start_time" in data else None
            subscription = self.subscribe(
                user, Profile.paypal_plan(data["plan_id"]), start=start, status="APPROVAL_PENDING"
            )
            self.created.append((data, subscription))
            approve_url = (
                "https://www.paypal.com/webapps/billing/subscriptions?ba_token=BA-%s" % subscription["id"]
            )
            return {"id": subscription["id"], "links": [{"rel": "approve", "href": approve_url}]}
        if path.startswith("/v1/billing/subscriptions/") and path.endswith("/suspend"):
            self.subscriptions[parts[3]]["status"] = "SUSPENDED"
            return {}
        if path.startswith("/v2/payments/captures/") and path.endswith("/refund"):
            _, transaction = self._transaction(parts[3])
            gross = float(transaction["amount_with_breakdown"]["gross_amount"]["value"])
            refunded = float(data["amount"]["value"])
            transaction["status"] = "REFUNDED" if refunded >= gross else "PARTIALLY_REFUNDED"
            self.refunds.append((transaction["id"], data["amount"]["value"]))
            return {"id": "REFUND-%s" % transaction["id"], "status": "COMPLETED"}
        raise AssertionError("PayPal has no POST %s" % url)


@override_settings(**USAGE_PRICES)
class Test_TeamPayPalBilling(TeamProMixin, TestCase):
    """apps/team/paypal_billing.py: team plans bought, renewed, switched, cancelled and refunded through PayPal."""

    def setUp(self):
        super().setUp()
        self.paypal = FakePayPalBilling(self)
        self.staff = User.objects.create_user(username="staff", is_staff=True)

    def paypal_event(self, event_type, resource):
        """apps/team/tests.py: a PayPal notification posted to the webhook, with what it queued for after its commit
        run in place."""
        response = self.committed(
            Client().post,
            reverse("paypal-webhooks"),
            json.encode({"event_type": event_type, "resource": resource}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)

    def subscription_event(self, event_type, subscription):
        """BILLING.SUBSCRIPTION.* as PayPal sends it."""
        resource = {key: subscription[key] for key in ("id", "status", "plan_id", "custom_id")}
        self.paypal_event(event_type, resource)

    def sale_completed(self, subscription):
        """PAYMENT.SALE.COMPLETED for the subscription's latest payment."""
        self.paypal_event(
            "PAYMENT.SALE.COMPLETED",
            {
                "id": self.paypal.latest_payment(subscription)["id"],
                "billing_agreement_id": subscription["id"],
                "custom": subscription["custom_id"],
            },
        )

    def team_owner(self, username, plan=Team.PLAN_TEAM, paid_at=None):
        """apps/team/tests.py: an owner whose team a PayPal subscription bills, bought through PayPal's button and
        paid at paid_at or now, and the subscription."""
        owner = self.reader(username)
        subscription = self.paypal.subscribe(owner, plan, created=paid_at)
        self.paypal.charge(subscription, at=paid_at)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", subscription)
        self.assertEqual(self.owned_team(owner).billing_reference, subscription["id"])
        return owner, subscription

    def own_subscriber(self, username, plan, paid_days_ago):
        """apps/team/tests.py: someone paying for plan through PayPal on their own, last paid paid_days_ago, and the
        subscription and that payment."""
        paid_at = self.now - self.days(paid_days_ago)
        user = self.reader(username, plan, premium_expire=paid_at + relativedelta(years=1))
        subscription = self.paypal.subscribe(user, plan, created=paid_at)
        payment = self.paypal.charge(subscription, at=paid_at)
        self.paypal.known(user, subscription)
        return user, subscription, payment

    def month_left(self, amount, paid_days_ago):
        """apps/team/tests.py: what is left of a month's payment made paid_days_ago, the month being the one after
        that payment."""
        paid_at = self.now - self.days(paid_days_ago)
        month = (paid_at + relativedelta(months=1) - paid_at).days
        return "%.2f" % (amount * (month - paid_days_ago) / month)

    def test_a_purchase_starts_one_team_whatever_order_its_notices_arrive_in(self):
        buyer = self.reader("buyer", "free", feeds=2)
        subscription = self.paypal.subscribe(buyer, Team.PLAN_TEAM)

        # PayPal activates the subscription before it has collected the first payment.
        self.subscription_event("BILLING.SUBSCRIPTION.CREATED", subscription)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", subscription)
        self.assertIsNone(self.owned_team(buyer))
        self.paypal.charge(subscription)
        self.sale_completed(subscription)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", subscription)
        self.sale_completed(subscription)

        [team] = Team.objects.filter(owner=buyer)
        self.assertEqual(
            (team.plan, team.status, team.billing_provider, team.billing_reference, team.paid_through),
            (
                Team.PLAN_TEAM,
                Team.STATUS_ACTIVE,
                Team.PROVIDER_PAYPAL,
                subscription["id"],
                self.paypal.next_billing(subscription),
            ),
        )
        self.assertEqual(self.plan_of(buyer), "pro")
        self.assertEqual(self.muted_sites(buyer), 0)
        [welcome] = self.mail_to(buyer)
        self.assertIn("?next=team", welcome.body)
        EmailNewPremium.delay.assert_not_called()
        EmailNewPremiumPro.delay.assert_not_called()
        EmailStaffPremiumUpgrade.delay.assert_called_once_with(
            user_id=buyer.pk, tier=Team.PLAN_TEAM, previous_tier="free"
        )

    def test_a_team_starts_only_from_a_payment_paypal_shows_for_this_account(self):
        # The notices say the subscription is active and paid. PayPal says it is still waiting for approval.
        buyer = self.reader("buyer")
        pending = self.paypal.subscribe(buyer, Team.PLAN_TEAM, status="APPROVAL_PENDING")
        self.paypal_event(
            "BILLING.SUBSCRIPTION.ACTIVATED",
            {
                "id": pending["id"],
                "status": "ACTIVE",
                "plan_id": pending["plan_id"],
                "custom_id": str(buyer.pk),
            },
        )
        self.paypal_event(
            "PAYMENT.SALE.COMPLETED",
            {"id": "TX-1", "billing_agreement_id": pending["id"], "custom": str(buyer.pk)},
        )
        self.assertIsNone(self.owned_team(buyer))
        self.assertEqual(self.plan_of(buyer), "free")

        # An IPN reaches the account whose email the payer's PayPal account has, for a team another account bought.
        payer = self.reader("payer")
        bought = self.paypal.subscribe(self.reader("teamowner"), Team.PLAN_TEAM)
        self.paypal.charge(bought)
        self.patch(PayPalIPN, "_postback", return_value=b"VERIFIED")
        self.committed(
            Client().post,
            reverse("paypal-ipn"),
            urlencode(
                {
                    "txn_type": "recurring_payment",
                    "txn_id": "TX-IPN-1",
                    "recurring_payment_id": bought["id"],
                    "custom": bought["custom_id"],
                    "payer_email": payer.email,
                    "payment_status": "Completed",
                    "mc_gross": "79.00",
                    "mc_currency": "USD",
                    "charset": "utf-8",
                }
            ),
            content_type="application/x-www-form-urlencoded",
        )
        self.assertEqual(Profile.objects.get(user=payer).paypal_sub_id, bought["id"])
        self.assertIsNone(self.owned_team(payer))
        self.assertEqual(self.plan_of(payer), "free")

        # Someone on another team who buys one anyway gets no team, and staff are told.
        member = self.reader("member")
        self.join(member)
        on_team = self.paypal.subscribe(member, Team.PLAN_TEAM)
        self.paypal.charge(on_team)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", on_team)
        self.assertIsNone(self.owned_team(member))
        self.assertEqual(self.staff_events(), ["team_purchase_on_team"])
        EmailNewPremium.delay.assert_not_called()

    def test_only_a_collected_renewal_moves_the_paid_period_and_a_later_one_brings_the_team_back(self):
        owner, subscription = self.team_owner("teamowner", paid_at=self.now - self.days(25))
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))

        self.paypal.charge(subscription)
        self.sale_completed(subscription)
        renewed_through = self.paypal.next_billing(subscription)
        self.assertEqual(self.owned_team(owner).paid_through, renewed_through)

        # The next renewal fails. PayPal moves on to the following cycle and holds the payment as outstanding.
        self.paypal.fail_renewal(subscription)
        self.subscription_event("BILLING.SUBSCRIPTION.UPDATED", subscription)
        TeamProGrants()
        team = self.owned_team(owner)
        self.assertEqual((team.paid_through, team.status), (renewed_through, Team.STATUS_ACTIVE))

        self.lapse(owner)
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(member), "free")

        self.paypal.charge(subscription)
        self.sale_completed(subscription)

        team = self.owned_team(owner)
        self.assertEqual(
            (team.status, team.paid_through), (Team.STATUS_ACTIVE, self.paypal.next_billing(subscription))
        )
        self.assertEqual(self.plan_of(member), "pro")

    def test_switching_up_from_a_plan_of_the_owners_own_refunds_what_is_left_of_it(self):
        subscriber, archive, archive_payment = self.own_subscriber("subscriber", "archive", paid_days_ago=100)

        response = self.profile_post(subscriber, "switch_paypal_subscription", plan=Team.PLAN_TEAM)

        [(request, team_subscription)] = self.paypal.created
        self.assertIn(team_subscription["id"], response["Location"])
        self.assertNotIn("start_time", request)
        self.assertTrue(
            request["application_context"]["return_url"].endswith("%s?plan=team" % reverse("paypal-return"))
        )
        self.paypal.approve(team_subscription)
        self.paypal.charge(team_subscription)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", team_subscription)

        team = self.owned_team(subscriber)
        self.assertEqual((team.plan, team.billing_reference), (Team.PLAN_TEAM, team_subscription["id"]))
        self.assertEqual(self.plan_of(subscriber), "pro")
        self.assertEqual(archive["status"], "SUSPENDED")
        # 265 days of the $99 year were left.
        self.assertEqual(self.paypal.refunds, [(archive_payment["id"], "71.88")])

        # The Archive the team replaced was refunded, so there is no Archive to go back to.
        self.lapse(subscriber)
        self.assertEqual(self.plan_of(subscriber), "pro")
        self.assertFalse(TeamProGrant.objects.filter(user=subscriber).exists())

    def test_switching_up_between_team_plans_refunds_what_is_left_of_the_month(self):
        owner, team_subscription = self.team_owner("teamowner", paid_at=self.now - self.days(20))
        team_payment = self.paypal.latest_payment(team_subscription)

        self.profile_post(owner, "switch_paypal_subscription", plan=Team.PLAN_TEAM_ENTERPRISE)

        [(request, enterprise)] = self.paypal.created
        self.assertNotIn("start_time", request)
        self.paypal.approve(enterprise)
        self.paypal.charge(enterprise)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", enterprise)

        team = self.owned_team(owner)
        self.assertEqual(
            (team.plan, team.billing_reference, team.paid_through),
            (Team.PLAN_TEAM_ENTERPRISE, enterprise["id"], self.paypal.next_billing(enterprise)),
        )
        self.assertEqual(team_subscription["status"], "SUSPENDED")
        self.assertEqual(self.paypal.refunds, [(team_payment["id"], self.month_left(79, 20))])

        # Refunding the rest of the old subscription's payment ends nothing, since it no longer bills the team.
        self.paypal.take_back(team_subscription, "REFUNDED")
        self.subscription_event("BILLING.SUBSCRIPTION.UPDATED", team_subscription)
        self.assertEqual(self.owned_team(owner).status, Team.STATUS_ACTIVE)
        self.assertFalse(TeamActivity.objects.filter(team=team, action="team_deactivated").exists())

    def test_an_ordinary_switch_refunds_the_old_plan_for_what_is_left_of_the_period_it_bills(self):
        pro, pro_subscription, pro_payment = self.own_subscriber("prouser", "pro", paid_days_ago=20)
        premium, premium_subscription, premium_payment = self.own_subscriber(
            "premiumuser", "premium", paid_days_ago=100
        )

        for user, subscription in ((pro, pro_subscription), (premium, premium_subscription)):
            archive = self.paypal.subscribe(user, "archive")
            self.paypal.charge(archive)
            self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", archive)
            self.assertEqual(subscription["status"], "SUSPENDED")

        # Pro bills monthly, so 20 days in a year's proration would refund $27.41. Premium bills yearly.
        self.assertEqual(
            self.paypal.refunds,
            [(pro_payment["id"], self.month_left(29, 20)), (premium_payment["id"], "26.14")],
        )

    def test_switching_down_keeps_the_team_until_the_paid_month_ends(self):
        owner, team_subscription = self.team_owner("teamowner", plan=Team.PLAN_TEAM_ENTERPRISE)
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))
        period_end = self.owned_team(owner).paid_through

        self.profile_post(owner, "switch_paypal_subscription", plan="archive")
        [(request, archive)] = self.paypal.created
        self.assertEqual(local_time(request["start_time"]), period_end)
        self.paypal.approve(archive)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", archive)

        team = self.owned_team(owner)
        self.assertEqual(
            (team.plan, team.status, team.paid_through, team.pending_plan),
            (Team.PLAN_TEAM_ENTERPRISE, Team.STATUS_ACTIVE, period_end, "archive"),
        )
        self.assertEqual(Profile.objects.get(user=owner).canonical()["team_pending_plan"], "archive")
        self.assertEqual(team_subscription["status"], "SUSPENDED")
        self.assertEqual((self.plan_of(owner), self.plan_of(member)), ("pro", "pro"))

        # Choosing again drops the earlier choice before it bills.
        self.profile_post(owner, "switch_paypal_subscription", plan=Team.PLAN_TEAM)
        _, team_switch = self.paypal.created[1]
        self.paypal.approve(team_switch)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", team_switch)

        self.assertEqual(archive["status"], "SUSPENDED")
        self.assertEqual(self.owned_team(owner).pending_plan, Team.PLAN_TEAM)
        self.assertEqual(self.paypal.refunds, [])

    def test_a_switch_down_starts_the_lower_plan_once_paypal_collects_it_after_the_paid_month(self):
        # All three months ended an hour ago.
        paid_at = self.now - relativedelta(months=1) - datetime.timedelta(hours=1)
        down, down_subscription = self.team_owner("down", paid_at=paid_at)
        member = self.reader("member", "archive", premium_expire=self.now + self.days(100))
        self.join(member, self.join_link_token(self.owned_team(down), down))
        late, _ = self.team_owner("late", paid_at=paid_at)
        enterprise, enterprise_subscription = self.team_owner(
            "enterprise", plan=Team.PLAN_TEAM_ENTERPRISE, paid_at=paid_at
        )

        for owner, plan in ((down, "premium"), (late, "premium"), (enterprise, Team.PLAN_TEAM)):
            self.profile_post(owner, "switch_paypal_subscription", plan=plan)
        (_, premium), (_, late_premium), (_, team_switch) = self.paypal.created
        for subscription in (premium, late_premium, team_switch):
            self.paypal.approve(subscription)
            self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", subscription)

        # Premium starts only once PayPal has collected it.
        self.assertEqual((self.owned_team(down).status, self.plan_of(down)), (Team.STATUS_ACTIVE, "pro"))
        self.assertEqual(down_subscription["status"], "SUSPENDED")
        self.paypal.charge(premium)
        self.sale_completed(premium)

        team = self.owned_team(down)
        self.assertEqual((team.status, team.pending_plan), (Team.STATUS_INACTIVE, None))
        self.assertEqual(self.plan_of(down), "premium")
        self.assertEqual(self.plan_of(member), "archive")

        # A team whose month ran out before PayPal collected the lower plan ends a day later as any team does, and
        # the plan starts once PayPal collects it.
        self.lapse(late)
        self.assertEqual(self.plan_of(late), "pro")
        self.paypal.charge(late_premium)
        self.sale_completed(late_premium)
        self.assertEqual(self.plan_of(late), "premium")
        self.assertIsNone(self.owned_team(late).pending_plan)

        # A switch between team plans bills the team from the new subscription's first payment.
        self.assertEqual(self.owned_team(enterprise).pending_plan, Team.PLAN_TEAM)
        self.paypal.charge(team_switch)
        self.sale_completed(team_switch)

        team = self.owned_team(enterprise)
        self.assertEqual(
            (team.plan, team.status, team.billing_reference, team.paid_through, team.pending_plan),
            (
                Team.PLAN_TEAM,
                Team.STATUS_ACTIVE,
                team_switch["id"],
                self.paypal.next_billing(team_switch),
                None,
            ),
        )
        self.assertEqual(enterprise_subscription["status"], "SUSPENDED")
        self.assertEqual(self.paypal.refunds, [])

    def test_cancelling_runs_to_the_end_of_the_paid_month_and_keeps_the_team(self):
        owner, subscription = self.team_owner("teamowner")
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(owner), owner))
        paid_through = self.owned_team(owner).paid_through

        self.profile_post(owner, "cancel_premium")
        self.subscription_event("BILLING.SUBSCRIPTION.SUSPENDED", subscription)
        TeamProGrants()

        self.assertEqual(subscription["status"], "SUSPENDED")
        team = self.owned_team(owner)
        self.assertEqual((team.status, team.paid_through), (Team.STATUS_ACTIVE, paid_through))
        self.assertEqual(self.plan_of(member), "pro")

        self.lapse(owner)
        team = self.owned_team(owner)
        self.assertEqual(team.status, Team.STATUS_INACTIVE)
        self.assertEqual(team.active_members().count(), 2)

    def test_a_full_refund_or_a_reversal_ends_the_team_at_once(self):
        refunded, _ = self.team_owner("refunded", paid_at=self.now - self.days(10))
        member = self.reader("member")
        self.join(member, self.join_link_token(self.owned_team(refunded), refunded))
        credited, _ = self.team_owner("credited", paid_at=self.now - self.days(10))
        reversed_owner, reversed_subscription = self.team_owner("reversed")

        # A prorated refund is a credit, not the end of the team.
        self.profile_post(self.staff, "refund_premium", user_id=credited.pk, partial="true")
        self.assertEqual(self.owned_team(credited).status, Team.STATUS_ACTIVE)

        self.profile_post(self.staff, "refund_premium", user_id=refunded.pk)
        team = self.owned_team(refunded)
        self.assertEqual(team.status, Team.STATUS_INACTIVE)
        self.assertLess(team.paid_through, datetime.datetime.now())
        self.assertEqual(self.plan_of(member), "free")

        reversal = self.paypal.take_back(reversed_subscription, "REVERSED")
        self.paypal_event("PAYMENT.SALE.REVERSED", {"id": "REVERSAL-1", "sale_id": reversal["id"]})
        self.assertEqual(self.owned_team(reversed_owner).status, Team.STATUS_INACTIVE)

        # Later notices for the subscription, which PayPal still shows active, don't bring the team back.
        self.subscription_event("BILLING.SUBSCRIPTION.UPDATED", reversed_subscription)
        self.assertEqual(self.owned_team(reversed_owner).status, Team.STATUS_INACTIVE)
        # Owners with no plan of their own expire from now through the usual window, not from the end of the month
        # the payment taken back bought.
        for owner in (refunded, reversed_owner):
            self.assertEqual(self.plan_of(owner), "pro")
            self.assertLessEqual(self.premium_expire(owner), datetime.datetime.now())

    def test_a_teammate_or_an_owner_billed_elsewhere_gets_no_paypal_team_plan(self):
        member = self.reader("member")
        self.join(member)
        store_owner = self.reader("storeowner")
        self.pay(store_owner, self.now + self.days(20), provider=Team.PROVIDER_APP_STORE, reference="2000001")
        stripe_owner = self.reader("stripeowner")
        self.pay(stripe_owner, self.now + self.days(20))
        refused = (
            (member, "on_team"),
            (store_owner, "team_billed_elsewhere"),
            (stripe_owner, "team_billed_elsewhere"),
            # Staff comp this one.
            (self.owner, "team_billed_elsewhere"),
        )
        for buyer, reason in refused:
            response = self.get(buyer, "paypal_plan", plan=Team.PLAN_TEAM_ENTERPRISE)
            self.assertEqual((response["code"], response["reason"]), (-1, reason))
            self.assertNotIn("plan_id", response)
            response = self.profile_post(buyer, "switch_paypal_subscription", plan=Team.PLAN_TEAM_ENTERPRISE)
            self.assertIn("team_purchase=%s" % reason, response["Location"])
        self.assertEqual(self.paypal.created, [])

        # Anyone else, and an owner whose team PayPal bills, is handed the plan to subscribe to.
        paypal_owner, _ = self.team_owner("paypalowner")
        for buyer in (self.reader("buyer"), paypal_owner):
            response = self.get(buyer, "paypal_plan", plan=Team.PLAN_TEAM_ENTERPRISE)
            self.assertEqual(response["plan_id"], Profile.plan_to_paypal_plan_id(Team.PLAN_TEAM_ENTERPRISE))

    def test_a_paypal_purchase_stops_stripe_renewals_without_a_refund(self):
        fake_stripe = FakeStripeBilling(self)
        # One owner's team Stripe bills already; the other pays for Archive through Stripe.
        stripe_owner = self.reader("stripeowner")
        fake_stripe.known_customer(stripe_owner)
        team_subscription = fake_stripe.subscribe(stripe_owner, Team.PLAN_TEAM)
        stripe_paid_at = self.now - self.days(11)
        fake_stripe.invoices[team_subscription.latest_invoice]["status_transitions"] = {
            "paid_at": int(stripe_paid_at.timestamp())
        }
        self.pay(
            stripe_owner, self.now + self.days(20), reference=team_subscription.id, paid_at=stripe_paid_at
        )
        archive_owner = self.reader("archiveowner", "archive", premium_expire=self.now + self.days(200))
        fake_stripe.known_customer(archive_owner)
        archive_subscription = fake_stripe.subscribe(archive_owner, "archive")

        for owner, plan in ((stripe_owner, Team.PLAN_TEAM_ENTERPRISE), (archive_owner, Team.PLAN_TEAM)):
            subscription = self.paypal.subscribe(owner, plan)
            self.paypal.charge(subscription)
            self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", subscription)
            team = self.owned_team(owner)
            self.assertEqual(
                (team.plan, team.billing_provider, team.billing_reference),
                (plan, Team.PROVIDER_PAYPAL, subscription["id"]),
            )

        self.assertTrue(team_subscription.cancel_at_period_end)
        self.assertTrue(archive_subscription.cancel_at_period_end)
        self.assertEqual([charge.amount_refunded for charge in fake_stripe.charges], [0, 0])
        self.assertEqual(self.staff_events(), ["team_paid_twice"])
        # The Archive paid for through Stripe was kept, and is the owner's plan again after the team.
        self.lapse(archive_owner)
        self.assertEqual(self.plan_of(archive_owner), "archive")

    def test_a_stripe_renewal_that_wont_stop_is_retried_and_then_goes_to_staff(self):
        fake_stripe = FakeStripeBilling(self)
        owner = self.reader("archiveowner", "archive", premium_expire=self.now + self.days(200))
        fake_stripe.known_customer(owner)
        archive_subscription = fake_stripe.subscribe(owner, "archive")
        fake_stripe.modify.side_effect = stripe.error.APIConnectionError("Stripe can't be reached")

        subscription = self.paypal.subscribe(owner, Team.PLAN_TEAM)
        self.paypal.charge(subscription)
        self.subscription_event("BILLING.SUBSCRIPTION.ACTIVATED", subscription)

        self.assertEqual(self.owned_team(owner).billing_reference, subscription["id"])
        self.assertFalse(archive_subscription.cancel_at_period_end)
        self.assertGreater(fake_stripe.modify.call_count, 1)
        self.assertEqual(self.staff_events(), ["team_renewal_unconfirmed"])

    def test_a_receipt_names_the_plan_and_the_period_the_provider_billed_for(self):
        fake_stripe = FakeStripeBilling(self)
        subscriber = self.reader("subscriber", "premium", premium_expire=self.now + self.days(265))
        fake_stripe.known_customer(subscriber)
        subscription = fake_stripe.subscribe(subscriber, "premium")
        # The Premium year was paid for 100 days ago. Switching to Premium Team now charges what is left of a month
        # of the team plan after the unused part of that year.
        fake_stripe.charges[-1]["created"] = int((self.now - self.days(100)).timestamp())
        self.profile_post(subscriber, "switch_stripe_subscription", plan=Team.PLAN_TEAM)
        paypal_pro, _, pro_payment = self.own_subscriber("paypalpro", "pro", paid_days_ago=20)
        Profile.objects.get(user=paypal_pro).setup_premium_history()

        def receipt(user):
            payment = PaymentHistory.objects.filter(user=user, payment_amount__gt=0).latest("payment_date")
            return self.client_for(user).get(reverse("profile-invoice", args=[payment.pk])).content.decode()

        def day(moment):
            return dateformat.format(moment, "F j, Y")

        switch = receipt(subscriber)
        self.assertIn("NewsBlur Premium Team Subscription", switch)
        self.assertIn(day(datetime.datetime.fromtimestamp(subscription.current_period_end)), switch)
        self.assertNotIn(day(self.now + relativedelta(years=1)), switch)
        pro = receipt(paypal_pro)
        self.assertIn("NewsBlur Premium Pro Subscription", pro)
        self.assertIn(day(local_time(pro_payment["time"]) + relativedelta(months=1)), pro)

    def test_the_payments_list_shows_when_paypal_bills_next(self):
        owner, subscription = self.team_owner("teamowner")

        response = json.decode(self.client_for(owner).get(reverse("profile-payment-history")).content)

        next_billing = dateutil.parser.parse(subscription["billing_info"]["next_billing_time"])
        self.assertEqual(response["next_invoice"]["payment_date"], str(next_billing.replace(tzinfo=None)))
