import datetime
import re
import threading
from decimal import Decimal
from unittest.mock import MagicMock, patch

import redis
import stripe
from django.conf import settings
from django.contrib.auth.models import User
from django.core import mail
from django.db import DatabaseError, connection, transaction
from django.test import Client, TestCase, TransactionTestCase, override_settings
from django.utils import dateformat
from mongoengine.context_managers import switch_db

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
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed
from apps.rss_feeds.tasks import SchedulePremiumSetup
from apps.statistics.models import MStatistics
from apps.statistics.rllm_costs import RLLMCosts
from apps.team.grants import activate_team, deactivate_team
from apps.team.models import (
    Team,
    TeamActivity,
    TeamInvite,
    TeamMember,
    TeamProGrant,
    team_owner_id,
)
from apps.team.tasks import SendTeamInviteEmail, SettleOwnPlanOnJoin, TeamProGrants
from utils import json_functions as json
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
        self.patch(SettleOwnPlanOnJoin, "delay", side_effect=lambda **kwargs: SettleOwnPlanOnJoin(**kwargs))
        self.patch(EmailNewPremiumTrial, "delay")
        self.patch(SchedulePremiumSetup, "apply_async")
        self.patch(UserSubscription, "queue_new_feeds")
        self.backfill = self.patch(UserSubscription, "schedule_fetch_archive_feeds_for_user")

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
        team, reason = Team.create_team(owner, name)
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

    def grace_day(self, user, day):
        """apps/team/tests.py: moves the user's grace so that today is its given day, where day 1 is the day it
        began, then runs the hourly task."""
        started = self.now - self.days(day - 1) - datetime.timedelta(minutes=1)
        TeamProGrant.objects.filter(user=user).update(
            grace_started=started, grace_until=started + self.days(14)
        )
        TeamProGrants()

    def mail_to(self, user):
        return [message for message in mail.outbox if user.email in message.to[0]]


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

        # A site muted during the seat stays muted when the same grant comes back after leaving.
        UserSubscription.objects.filter(user=free, feed__feed_address__endswith="/0").update(active=False)
        self.leave(free)
        self.join(free)
        self.assertEqual(self.muted_sites(free), 1)

    def test_a_removed_teammate_keeps_pro_for_14_days_with_an_email_on_day_1_and_day_10(self):
        reader = self.reader("reader", "free", feeds=2)
        self.join(reader)

        self.post(self.owner, "remove_member", team_id=self.team.pk, user_id=reader.pk)
        self.assertEqual(len(self.mail_to(reader)), 1)

        self.grace_day(reader, 9)
        self.assertEqual(len(self.mail_to(reader)), 1)
        self.grace_day(reader, 10)
        TeamProGrants()
        self.assertEqual(len(self.mail_to(reader)), 2)

        self.grace_day(reader, 14)
        self.assertEqual(self.plan_of(reader), "pro")
        self.assertEqual(self.muted_sites(reader), 0)

        self.grace_day(reader, 15)
        self.assertEqual(self.plan_of(reader), "free")
        self.assertEqual(self.muted_sites(reader), 2)
        self.assertEqual(len(self.mail_to(reader)), 2)

    def test_leaving_returns_a_paying_teammate_to_their_own_plan(self):
        paid_through = self.now + self.days(200)
        reader = self.reader("reader", "archive", premium_expire=paid_through, feeds=2)
        self.join(reader)

        self.leave(reader)
        self.grace_day(reader, 15)

        self.assertEqual(self.plan_of(reader), "archive")
        self.assertEqual(self.premium_expire(reader), paid_through)
        self.assertEqual(self.muted_sites(reader), 0)

    def test_a_failed_grant_leaves_no_seat_without_pro(self):
        reader = self.reader("reader", "free")

        with patch("apps.team.grants.grant_team_pro", side_effect=DatabaseError("connection lost")):
            with self.assertRaises(DatabaseError):
                self.team.live_join_link().accept(reader)

        self.assertIsNone(TeamMember.active_membership(reader))


class Test_TeamProOwnPlans(TeamProMixin, TestCase):
    """A plan the teammate gets, loses or renews on their own during the seat is the one they go back to."""

    def test_rejoining_during_grace_keeps_the_plan_from_before_the_first_seat(self):
        reader = self.reader("reader", "free", feeds=1)
        other_owner = User.objects.create_user(username="otherowner")
        other_team = self.create_team(other_owner, "Elsewhere")
        self.join(reader)
        self.post(self.owner, "remove_member", team_id=self.team.pk, user_id=reader.pk)

        # The first grace has run out, but the hourly task hasn't run yet when the reader joins another team.
        started = self.now - self.days(15)
        TeamProGrant.objects.filter(user=reader).update(
            grace_started=started, grace_until=started + self.days(14)
        )
        self.join(reader, self.join_link_token(other_team, other_owner))
        TeamProGrants()
        self.assertEqual(self.plan_of(reader), "pro")

        self.leave(reader, other_team)
        self.grace_day(reader, 15)
        self.assertEqual(self.plan_of(reader), "free")

    def test_a_store_expiry_during_the_seat_keeps_team_pro_and_ends_the_own_plan(self):
        reader = self.reader("reader", "premium", premium_expire=self.now + self.days(10), feeds=2)
        self.join(reader)

        Profile.objects.get(user=reader).deactivate_premium()
        self.assertEqual(self.plan_of(reader), "pro")
        self.assertEqual(self.muted_sites(reader), 0)

        self.leave(reader)
        self.grace_day(reader, 15)
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
        self.grace_day(reader, 15)
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
        self.grace_day(reader, 15)
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
        self.grace_day(reader, 15)
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
        self.grace_day(reader, 15)
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
        self.assertEqual(self.plan_of(self.owner), "premium")
        # Someone on no team still expires as before.
        self.assertEqual(self.plan_of(outsider), "free")
        self.assertEqual([message.to for message in mail.outbox], [["outsider <outsider@example.com>"]])

        # The plan that ran out during the seat ends with the grace, with no further 30 days.
        self.leave(lapsed)
        self.grace_day(lapsed, 15)
        self.assertEqual(self.plan_of(lapsed), "free")
        self.assertEqual(self.muted_sites(lapsed), 1)


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
        leaver_grace_until = TeamProGrant.objects.get(user=leaver).grace_until
        roles = self.roles()
        Team.objects.filter(pk=self.team.pk).update(paid_through=self.now - datetime.timedelta(hours=1))
        mail.outbox = []

        TeamProGrants()
        TeamProGrants()

        self.team.refresh_from_db()
        self.assertEqual(self.team.status, Team.STATUS_INACTIVE)
        self.assertEqual(self.plan_of(free_reader), "free")
        self.assertEqual(self.muted_sites(free_reader), 2)
        self.assertEqual(self.plan_of(archive_reader), "archive")
        self.assertIsNone(team_owner_id(free_reader))
        # Someone already in grace keeps the date their first email gave them.
        self.assertEqual(self.plan_of(leaver), "pro")
        self.assertEqual(TeamProGrant.objects.get(user=leaver).grace_until, leaver_grace_until)
        self.assertEqual(
            sorted(message.to[0] for message in mail.outbox),
            sorted("%s <%s>" % (user, user.email) for user in (self.owner, free_reader, archive_reader)),
        )
        self.assertEqual(self.roles(), roles)

        activate_team(self.team)

        self.assertEqual(self.plan_of(free_reader), "pro")
        self.assertEqual(self.muted_sites(free_reader), 0)
        self.assertEqual(self.plan_of(archive_reader), "pro")
        self.assertEqual(team_owner_id(free_reader), self.owner.pk)
        self.assertEqual(self.roles(), roles)

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


class Test_TeamProFeedSetup(TeamClientMixin, TransactionTestCase):
    """Real commits, so the feed setup a grant starts after it commits runs."""

    def test_joining_starts_the_archive_backfill_only_for_teammates_without_archive(self):
        owner = User.objects.create_user(username="owner")
        token = self.join_link_token(self.create_team(owner), owner)
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


def stripe_subscription(subscription_id, prices):
    """apps/team/tests.py: a Stripe subscription as the API returns it, with no top level plan once it has two
    items."""
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
            "status": "active",
            "cancel_at": None,
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
            stripe.Subscription, "list", side_effect=lambda **kwargs: MagicMock(data=self.subscriptions)
        )
        self.modify = test.patch(stripe.Subscription, "modify", side_effect=self._modify)
        self.cancel = test.patch(stripe.Subscription, "cancel")
        self.delete = test.patch(stripe.Subscription, "delete")
        self.refund = test.patch(stripe.Refund, "create")

    def _modify(self, subscription_id, cancel_at_period_end=False, **changes):
        if cancel_at_period_end:
            subscription = next(sub for sub in self.subscriptions if sub.id == subscription_id)
            subscription["cancel_at"] = int(datetime.datetime.now().timestamp())

    def renewals_turned_off(self):
        return [(call.args[0], call.kwargs) for call in self.modify.call_args_list]


class FakePayPal:
    """apps/team/tests.py: PayPal's subscriptions API for one subscription."""

    def __init__(self, test, subscription_id):
        self.subscription_id = subscription_id
        self.status = "ACTIVE"
        self.posts = []
        test.patch(profile_models.paypalrestsdk, "Api", return_value=self)

    def get(self, url):
        if "/transactions" in url:
            return {"transactions": []}
        return {"id": self.subscription_id, "status": self.status, "plan_id": "P-TEAMJOINER"}

    def post(self, url, data):
        self.posts.append(url)
        if url.endswith("/suspend"):
            self.status = "SUSPENDED"
        return {}


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
        self.grace_day(reader, 15)
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

    def classify(self, user):
        LLMCostTracker.record_usage(
            provider="anthropic",
            model="claude-sonnet-5-5",
            feature="story_classification",
            input_tokens=1_000_000,
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
        for user in (stayer, leaver):
            self.join(user)
        self.leave(leaver)
        TeamMember.objects.filter(user__in=(stayer, leaver)).update(joined_date=self.at(0.3))
        TeamMember.objects.filter(user=leaver).update(removed_date=self.at(0.6))

        self.cost(self.owner, 0.40, self.at(0.1))
        self.cost(stayer, 5.00, self.at(0.2))
        self.cost(stayer, 0.20, self.at(0.5))
        self.cost(stayer, 0.10, self.at(0.5), feature="vision_classification")
        self.cost(stayer, 3.00, self.at(0.5), feature="ask_ai")
        self.cost(leaver, 0.20, self.at(0.4))
        self.cost(leaver, 2.00, self.at(0.8))
        self.cost(outsider, 4.00, self.at(0.5))

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

        body = self.client_for(None).get("/monitor/users").content.decode("utf-8")

        counts = dict(re.findall(r'users\{category="(\w+)"\} (\d+)', body))
        self.assertEqual(
            {category: counts[category] for category in ("premium", "archive", "pro", "team_seats")},
            {"premium": "1", "archive": "1", "pro": "1", "team_seats": "3"},
        )

    def test_the_hourly_task_puts_back_pro_a_stale_profile_save_took_away(self):
        reader = self.reader("reader", "trial", premium_expire=self.now + self.days(20))
        leaver = self.reader("leaver", "free")
        outsider = self.reader("outsider", "free")
        # Loaded before the grant, as LastSeenMiddleware does, and saved whole after it.
        stale_profiles = [Profile.objects.get(user=user) for user in (reader, leaver)]
        for user in (reader, leaver):
            self.join(user)
        self.leave(leaver)
        for stale_profile in stale_profiles:
            stale_profile.save()
        self.assertEqual([self.plan_of(reader), self.plan_of(leaver)], ["trial", "free"])

        TeamProGrants()

        self.assertEqual([self.plan_of(user) for user in (reader, leaver, outsider)], ["pro", "pro", "free"])

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
            self.grace_day(user, 15)

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
        self.grace_day(reader, 15)
        self.assertEqual(self.plan_of(reader), "archive")
