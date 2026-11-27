import datetime
import re
import threading
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core import mail
from django.db import DatabaseError, connection, transaction
from django.test import Client, TestCase, TransactionTestCase

from apps.profile.apple_subscriptions import apply_verified_apple_transaction
from apps.profile.models import (
    MGiftCode,
    MRedeemedCode,
    MReferral,
    PaymentHistory,
    Profile,
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
from apps.team.grants import activate_team, deactivate_team
from apps.team.models import (
    Team,
    TeamActivity,
    TeamInvite,
    TeamMember,
    TeamProGrant,
    team_owner_id,
)
from apps.team.tasks import TeamProGrants
from utils import json_functions as json

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
    "pro": dict(
        is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=False, is_pro=True
    ),
}


def patch_pro_feed_setup(testcase):
    """apps/team/tests.py: keeps the Celery tasks a committed grant starts off the dev broker. Returns the
    archive backfill mock."""
    patcher = patch.object(SchedulePremiumSetup, "apply_async")
    patcher.start()
    testcase.addCleanup(patcher.stop)
    patcher = patch.object(UserSubscription, "schedule_fetch_archive_feeds_for_user")
    backfill = patcher.start()
    testcase.addCleanup(patcher.stop)
    return backfill


class TeamClientMixin:
    def client_for(self, user):
        client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        if user:
            client.force_login(user)
        return client

    def post(self, user, path, **data):
        return json.decode(self.client_for(user).post("/team/%s" % path, data).content)

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


class Test_TeamSeats(TeamClientMixin, TestCase):
    def setUp(self):
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


class Test_TeamConcurrentJoins(TeamClientMixin, TransactionTestCase):
    def setUp(self):
        patcher = patch.object(EmailNewPremiumTrial, "delay")
        patcher.start()
        self.addCleanup(patcher.stop)
        patch_pro_feed_setup(self)

    def accept_at_once(self, team, token):
        """apps/team/tests.py: two new accounts accept the same token. The first holds the team row while it
        joins, and the second, already inside its own request, has to wait for it. Returns both responses."""
        first_client = self.client_for(User.objects.create_user(username="first"))
        second_client = self.client_for(User.objects.create_user(username="second"))
        second_results = []

        def accept_in_another_request():
            try:
                response = second_client.post("/team/accept_invite", {"token": token})
                second_results.append(json.decode(response.content))
            finally:
                connection.close()

        second_request = threading.Thread(target=accept_in_another_request)
        try:
            with transaction.atomic():
                team.lock()
                second_request.start()
                second_request.join(timeout=1)
                self.assertTrue(second_request.is_alive(), "accept_invite went ahead without the team lock")
                first_response = json.decode(
                    first_client.post("/team/accept_invite", {"token": token}).content
                )
        finally:
            second_request.join(timeout=10)
        return first_response, second_results[0]

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


class Test_TeamRoles(TeamClientMixin, TestCase):
    def setUp(self):
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

        self.assertEqual(self.get(None, "invite_preview", token=token)["invite"]["team_name"], "Newsroom")
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


class Test_TeamOneTeamPerAccount(TeamClientMixin, TestCase):
    def setUp(self):
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

        with patch.object(TeamActivity, "PAGE_SIZE", 4):
            first_page = self.get(owner, "activity", team_id=team.pk)
            second_page = self.get(owner, "activity", team_id=team.pk, page=2)

        self.assertEqual(
            [entry["action"] for entry in first_page["activities"]],
            ["member_removed", "team_pro_granted", "member_joined", "join_link_created"],
        )
        self.assertTrue(first_page["has_more"])
        self.assertEqual([entry["action"] for entry in second_page["activities"]], ["team_created"])
        self.assertFalse(second_page["has_more"])


class TeamProMixin(TeamClientMixin):
    def setUp(self):
        super().setUp()
        self.now = datetime.datetime.now()
        self.welcome_tasks = []
        for task in (EmailNewPremium, EmailNewPremiumPro, EmailStaffPremiumUpgrade):
            patcher = patch.object(task, "delay")
            self.welcome_tasks.append(patcher.start())
            self.addCleanup(patcher.stop)
        for task in (EmailStaffNotification, EmailReferralCredit):
            patcher = patch.object(task, "delay")
            patcher.start()
            self.addCleanup(patcher.stop)
        patch_pro_feed_setup(self)
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

    def test_an_inactive_team_neither_grants_pro_nor_gives_grace(self):
        deactivate_team(self.team)
        reader = self.reader("reader", "trial", premium_expire=self.now + self.days(20))
        mail.outbox = []

        self.join(reader)
        self.assertEqual(self.plan_of(reader), "trial")
        self.leave(reader)

        self.assertEqual(self.plan_of(reader), "trial")
        self.assertEqual(mail.outbox, [])
        self.assertFalse(TeamProGrant.objects.filter(user=reader).exists())

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

    def setUp(self):
        patcher = patch.object(EmailNewPremiumTrial, "delay")
        patcher.start()
        self.addCleanup(patcher.stop)
        self.backfill = patch_pro_feed_setup(self)

    def test_joining_starts_the_archive_backfill_only_for_teammates_without_archive(self):
        owner = User.objects.create_user(username="owner")
        token = self.join_link_token(self.create_team(owner), owner)
        trial_reader = User.objects.create_user(username="trialreader")
        archive_reader = User.objects.create_user(username="archivereader")
        Profile.objects.filter(user=archive_reader).update(is_archive=True, is_premium_trial=False)

        for user in (trial_reader, archive_reader):
            self.assertEqual(self.post(user, "accept_invite", token=token)["code"], 1)

        self.backfill.assert_called_once_with(trial_reader.pk)
