import datetime
import re
import threading
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core import mail
from django.db import connection, transaction
from django.test import Client, TestCase, TransactionTestCase

from apps.profile.tasks import EmailNewPremiumTrial
from apps.team.models import Team, TeamActivity, TeamInvite, TeamMember, team_owner_id
from utils import json_functions as json


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
