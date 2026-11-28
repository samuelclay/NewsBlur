"""Team views: teams, members, roles, invites and join links (apps/team/models.py)."""

import re

from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.models import User
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.utils.translation import gettext_lazy
from django.views.decorators.http import require_POST

from apps.profile.apple_subscriptions import app_account_token
from apps.profile.models import Profile
from apps.profile.tasks import EmailStaffNotification
from apps.team.billing import (
    accept_comped_transfer,
    comp_refusal,
    comp_team,
    end_comp,
    start_comp_team,
)
from apps.team.grants import own_plan_on_join
from apps.team.models import Team, TeamActivity, TeamInvite, TeamMember, TeamProGrant
from apps.team.play_billing import play_account_id
from apps.team.stripe_billing import team_purchase_refusal
from utils import json_functions as json
from utils.user_functions import ajax_login_required, get_user
from utils.view_functions import required_params

# views.py: expected outcomes are answered with a reason and a message, never raised or sent to Sentry.
FAILURE_MESSAGES = {
    "not_found": gettext_lazy("That team or teammate wasn't found."),
    "not_allowed": gettext_lazy("Your role on this team can't do that."),
    "invalid_name": gettext_lazy("Give the team a name of up to 100 characters."),
    "invalid_plan": gettext_lazy("That plan isn't available."),
    "invalid_role": gettext_lazy("Teammates can be invited as a manager or a member."),
    "invalid_email": gettext_lazy("Check the email addresses and try again."),
    "invite_limit": gettext_lazy("This team has sent a lot of invites today. Try again tomorrow."),
    "seat_limit": gettext_lazy("This team has no open seats. Ask the team's owner to free one up."),
    "invite_not_found": gettext_lazy("This invite isn't valid. Ask the team for a new one."),
    "invite_expired": gettext_lazy("This invite has expired. Ask the team for a new one."),
    "invite_revoked": gettext_lazy("This invite was cancelled. Ask the team for a new one."),
    "invite_used": gettext_lazy("This invite has already been used. Ask the team for a new one."),
    "already_member": gettext_lazy("You're already on this team."),
    "already_on_team": gettext_lazy("You can only be on one team at a time. Leave your current team first."),
    "already_owns_team": gettext_lazy("You already have a team. Each account can own one team."),
    "removed_by_team": gettext_lazy("You were removed from this team. Ask a manager for a new invite."),
    "owner_cannot_leave": gettext_lazy("Transfer ownership to a teammate before you leave the team."),
    "team_inactive": gettext_lazy("This team's plan has ended, so it can't take new teammates right now."),
    "on_team": gettext_lazy("You can only be on one team at a time. Leave your current team first."),
    "team_billed_elsewhere": gettext_lazy(
        "Your team is already paid for another way, so it can't be bought here."
    ),
    "no_transfer": gettext_lazy("That request to take over the team isn't open anymore."),
    "transfer_needs_payment": gettext_lazy("To take over this team, buy its plan."),
    "team_comped": gettext_lazy(
        "This team's plan is free, so there's nothing to pay. Accept the request to take it over instead."
    ),
    # views.py: what staff are told in the User Admin dialog (media/js/newsblur/reader/reader_admin.js).
    "account_not_found": gettext_lazy("That account doesn't exist."),
    "invalid_seat_limit": gettext_lazy("Give the seat limit as a whole number of at least 1."),
    "seat_limit_too_high": gettext_lazy("That's more seats than a team can have."),
    "seat_limit_below_seats": gettext_lazy("The team has more teammates than that. Remove some first."),
    "plan_follows_payments": gettext_lazy(
        "This team's plan follows what it pays for. Only a comped team's plan can be changed here."
    ),
    "comp_not_owner": gettext_lazy(
        "This account is on a team it doesn't own. Comp it from the owner's account."
    ),
    "already_comped": gettext_lazy("This team is comped already."),
    "team_billed": gettext_lazy("A subscription pays for this team. Cancel it first, then comp the team."),
    "not_comped": gettext_lazy("This team isn't comped."),
    # views.py: what someone asking for more than ten seats is told (contact).
    "invalid_seats": gettext_lazy("Ask for more than 10 seats. Both team plans come with up to 10."),
    "note_too_long": gettext_lazy("That note is too long. Shorten it and send it again."),
}
# views.py: someone asking for more seats is told this however many times they send it (contact).
MORE_SEATS_SENT = gettext_lazy("Thanks, your request was sent. You'll get a reply by email.")
CONTACT_NOTE_MAX_LENGTH = 2000
# views.py: repeats of one account's request for more seats within this long email staff once (contact).
CONTACT_DEDUPE_SECONDS = 24 * 60 * 60


def _failure(reason, **extra):
    response = {"code": -1, "reason": reason, "message": str(FAILURE_MESSAGES[reason])}
    response.update(extra)
    return response


def _membership(user, team_id):
    return (
        TeamMember.objects.select_related("team")
        .filter(team_id=team_id, user=user, status=TeamMember.STATUS_ACTIVE)
        .first()
    )


def _team_response(user, team_id):
    membership = _membership(user, team_id)
    return {"code": 1, "team": membership.team.canonical(membership)}


def _clean_name(name):
    # views.py: one line only, since the name goes into email subjects.
    name = name.strip()
    if not name or len(name) > Team.NAME_MAX_LENGTH or len(name.splitlines()) > 1:
        return None
    return name


def _emails_from(post):
    """A list of addresses, or one string of them separated by commas, spaces or new lines, without
    repeats."""
    values = post.getlist("emails") or post.getlist("emails[]")
    emails = []
    for value in values:
        for email in re.split(r"[\s,;]+", value):
            email = email.strip().lower()
            if email and email not in emails:
                emails.append(email)
    return emails


def _is_valid_email(email):
    try:
        validate_email(email)
    except ValidationError:
        return False
    return True


@ajax_login_required
@json.json_view
def load_team(request):
    user = get_user(request)
    membership = TeamMember.active_membership(user)
    return {"code": 1, "team": membership.team.canonical(membership) if membership else None}


@required_params("name")
@ajax_login_required
@json.json_view
def create_team(request):
    # views.py: staff only until teams can be bought. A team started here is a comp (apps/team/billing.py).
    user = get_user(request)
    if not user.is_staff:
        return _failure("not_allowed")
    name = _clean_name(request.POST["name"])
    if not name:
        return _failure("invalid_name")
    plan = request.POST.get("plan", Team.PLAN_TEAM)
    if plan not in dict(Team.PLAN_CHOICES):
        return _failure("invalid_plan")

    team, reason = start_comp_team(user, name, plan)
    if reason:
        return _failure(reason)
    return _team_response(user, team.pk)


@required_params("plan", method="GET")
@ajax_login_required
@json.json_view
def paypal_plan(request):
    """views.py: the PayPal plan a team purchase subscribes to. The upgrade dialog's PayPal button asks for it as it
    opens PayPal, so the server decides who may buy a team there (apps/team/stripe_billing.py
    team_purchase_refusal)."""
    user = get_user(request)
    plan = request.GET["plan"]
    if plan not in dict(Team.PLAN_CHOICES):
        return _failure("invalid_plan")
    refusal = team_purchase_refusal(user, Team.PROVIDER_PAYPAL)
    if refusal:
        return _failure(refusal)
    return {"code": 1, "plan": plan, "plan_id": Profile.plan_to_paypal_plan_id(plan)}


@ajax_login_required
@json.json_view
def app_store_purchase(request):
    """views.py: what the iOS and macOS apps ask before showing a team plan's buy button, so the server decides who may
    buy a team in the App Store (apps/team/stripe_billing.py team_purchase_refusal). The app buys with the app account
    token it is given, which ties Apple's signed transactions to this account
    (apps/profile/apple_subscriptions.py)."""
    user = get_user(request)
    refusal = team_purchase_refusal(user, Team.PROVIDER_APP_STORE)
    if refusal:
        return _failure(refusal)
    return {"code": 1, "app_account_token": app_account_token(user.pk)}


@ajax_login_required
@json.json_view
def play_purchase(request):
    """views.py: what the Android app asks before showing a team plan's buy button, so the server decides who may buy a
    team on Google Play (apps/team/stripe_billing.py team_purchase_refusal). The app buys with the obfuscated account id
    it is given, which Google keeps on the subscription and which ties it to this account
    (apps/team/play_billing.py)."""
    user = get_user(request)
    refusal = team_purchase_refusal(user, Team.PROVIDER_PLAY)
    if refusal:
        return _failure(refusal)
    return {"code": 1, "obfuscated_account_id": play_account_id(user.pk)}


@required_params("name", team_id=int)
@ajax_login_required
@json.json_view
def rename_team(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if membership.role != TeamMember.ROLE_OWNER:
        return _failure("not_allowed")
    name = _clean_name(request.POST["name"])
    if not name:
        return _failure("invalid_name")

    membership.team.rename(user, name)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def invite(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if not membership.is_manager:
        return _failure("not_allowed")
    role = request.POST.get("role", TeamMember.ROLE_MEMBER)
    if role not in (TeamMember.ROLE_MANAGER, TeamMember.ROLE_MEMBER):
        return _failure("invalid_role")
    if role == TeamMember.ROLE_MANAGER and membership.role != TeamMember.ROLE_OWNER:
        return _failure("not_allowed")
    emails = _emails_from(request.POST)
    invalid_emails = [email for email in emails if not _is_valid_email(email)]
    if not emails or invalid_emails:
        return _failure("invalid_email", invalid_emails=invalid_emails)

    reason = membership.team.invite_by_email(user, emails, role)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int, invite_id=int)
@ajax_login_required
@json.json_view
def revoke_invite(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if not membership.is_manager:
        return _failure("not_allowed")
    pending_invite = membership.team.pending_invites().filter(pk=request.POST["invite_id"]).first()
    if not pending_invite:
        return _failure("not_found")

    pending_invite.revoke(user)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def create_join_link(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if not membership.is_manager:
        return _failure("not_allowed")

    reason = membership.team.create_join_link(user)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def revoke_join_link(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if not membership.is_manager:
        return _failure("not_allowed")

    membership.team.revoke_join_link(user)
    return _team_response(user, membership.team_id)


@required_params("token", method="GET")
@json.json_view
def invite_preview(request):
    # views.py: open to anyone holding the token, so the join screen can show it before signup or login.
    team_invite = (
        TeamInvite.objects.select_related("team", "created_by").filter(token=request.GET["token"]).first()
    )
    if not team_invite:
        return _failure("invite_not_found")
    reason = team_invite.refusal_reason()
    if reason:
        return _failure(reason)
    preview = team_invite.preview()
    # views.py: request.user, not get_user, which stands the homepage account in for a logged out visitor.
    if request.user.is_authenticated:
        preview["own_plan"] = own_plan_on_join(request.user)
    return {"code": 1, "invite": preview}


@required_params("token")
@ajax_login_required
@json.json_view
def accept_invite(request):
    user = get_user(request)
    team_invite = TeamInvite.objects.filter(token=request.POST["token"]).first()
    if not team_invite:
        return _failure("invite_not_found")

    # views.py: read before joining, since the join settles the person's own plan once it commits.
    own_plan = own_plan_on_join(user)
    reason = team_invite.accept(user)
    if reason:
        return _failure(reason)
    response = _team_response(user, team_invite.team_id)
    response["own_plan"] = own_plan
    return response


@required_params("role", team_id=int, user_id=int)
@ajax_login_required
@json.json_view
def change_role(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if membership.role != TeamMember.ROLE_OWNER:
        return _failure("not_allowed")
    member = _membership(request.POST["user_id"], membership.team_id)
    if not member:
        return _failure("not_found")
    if member.role == TeamMember.ROLE_OWNER:
        return _failure("not_allowed")
    role = request.POST["role"]
    if role not in (TeamMember.ROLE_MANAGER, TeamMember.ROLE_MEMBER):
        return _failure("invalid_role")

    reason = membership.team.change_role(membership, member, role)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int, user_id=int)
@ajax_login_required
@json.json_view
def remove_member(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if not membership.is_manager:
        return _failure("not_allowed")
    member = _membership(request.POST["user_id"], membership.team_id)
    if not member:
        return _failure("not_found")
    if not membership.can_remove(member):
        return _failure("not_allowed")

    reason = membership.team.remove_member(membership, member)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def leave_team(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")

    reason = membership.leave()
    if reason:
        return _failure(reason)
    return {"code": 1}


@required_params(team_id=int, user_id=int)
@ajax_login_required
@json.json_view
def transfer_ownership(request):
    """views.py: the owner asks a teammate to take the team over (Team.request_transfer)."""
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if membership.role != TeamMember.ROLE_OWNER:
        return _failure("not_allowed")
    member = _membership(request.POST["user_id"], membership.team_id)
    if not member:
        return _failure("not_found")

    reason = membership.team.request_transfer(membership, member)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def cancel_transfer(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")

    reason = membership.team.cancel_transfer(user)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def decline_transfer(request):
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")

    reason = membership.team.decline_transfer(user)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int)
@ajax_login_required
@json.json_view
def accept_transfer(request):
    """views.py: the teammate asked takes over a comped team, which has nothing to pay. A team that is paid for is
    taken over by buying its plan (apps/team/billing.py record_team_payment)."""
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")

    reason = accept_comped_transfer(user, membership.team_id)
    if reason:
        return _failure(reason)
    return _team_response(user, membership.team_id)


@required_params(team_id=int, method="GET")
@ajax_login_required
@json.json_view
def activity(request):
    user = get_user(request)
    membership = _membership(user, request.GET["team_id"])
    if not membership:
        return _failure("not_found")
    if not membership.is_manager:
        return _failure("not_allowed")
    try:
        page = max(int(request.GET.get("page", 1)), 1)
    except ValueError:
        page = 1

    offset = (page - 1) * TeamActivity.PAGE_SIZE
    activities = list(
        TeamActivity.objects.filter(team_id=membership.team_id)
        .select_related("actor")
        .order_by("-created_date", "-pk")[offset : offset + TeamActivity.PAGE_SIZE + 1]
    )
    return {
        "code": 1,
        "activities": [entry.canonical() for entry in activities[: TeamActivity.PAGE_SIZE]],
        "has_more": len(activities) > TeamActivity.PAGE_SIZE,
    }


def _staff_response(user):
    """views.py: the team this account is on for the staff User Admin dialog (Team.staff_canonical), or None, and
    whether staff can comp a team for it (apps/team/billing.py comp_refusal)."""
    membership = TeamMember.active_membership(user)
    return {
        "code": 1,
        "team": membership.team.staff_canonical(user.pk) if membership else None,
        "can_comp": comp_refusal(user) is None,
    }


def _staff_team_action(request, action):
    """views.py: runs action(team) on the team the account user_id is on, and answers with its failure reason or the
    team as staff see it now."""
    user = User.objects.filter(pk=request.POST["user_id"]).first()
    if not user:
        return _failure("account_not_found")
    membership = TeamMember.active_membership(user)
    if not membership:
        return _failure("not_found")
    reason = action(membership.team)
    if reason:
        return _failure(reason)
    return _staff_response(user)


@staff_member_required
@required_params(user_id=int, method="GET")
@ajax_login_required
@json.json_view
def staff_team(request):
    """views.py: staff only, as the other User Admin dialog endpoints are (apps/profile/views.py refund_premium)."""
    user = User.objects.filter(pk=request.GET["user_id"]).first()
    if not user:
        return _failure("account_not_found")
    return _staff_response(user)


@staff_member_required
@required_params("seat_limit", user_id=int)
@ajax_login_required
@json.json_view
def staff_seat_limit(request):
    try:
        seat_limit = int(request.POST["seat_limit"])
    except ValueError:
        return _failure("invalid_seat_limit")
    return _staff_team_action(request, lambda team: team.set_seat_limit(request.user, seat_limit))


@staff_member_required
@required_params("plan", user_id=int)
@ajax_login_required
@json.json_view
def staff_plan(request):
    plan = request.POST["plan"]
    if plan not in dict(Team.PLAN_CHOICES):
        return _failure("invalid_plan")
    return _staff_team_action(request, lambda team: team.set_comped_plan(request.user, plan))


@staff_member_required
@required_params("plan", user_id=int)
@ajax_login_required
@json.json_view
def staff_comp(request):
    """views.py: staff comp a team for the account, with no payment and no lapse date (apps/team/billing.py
    comp_team)."""
    plan = request.POST["plan"]
    if plan not in dict(Team.PLAN_CHOICES):
        return _failure("invalid_plan")
    user = User.objects.filter(pk=request.POST["user_id"]).first()
    if not user:
        return _failure("account_not_found")
    _, reason = comp_team(user, plan, request.user)
    if reason:
        return _failure(reason)
    return _staff_response(user)


@staff_member_required
@required_params(user_id=int)
@ajax_login_required
@json.json_view
def staff_end_comp(request):
    return _staff_team_action(request, lambda team: end_comp(team, request.user))


@require_POST
@ajax_login_required
@json.json_view
def contact(request):
    """views.py: "More than 10 teammates? Get in touch". Staff are emailed the request with the account attached
    (EmailStaffNotification), and the team the account is on logs it. Repeats from one account within
    CONTACT_DEDUPE_SECONDS are answered the same and email staff no more."""
    user = get_user(request)
    name = _clean_name(request.POST.get("team_name", ""))
    if not name:
        return _failure("invalid_name")
    try:
        seats = int(request.POST.get("seats", ""))
    except ValueError:
        seats = 0
    if seats <= Team.DEFAULT_SEAT_LIMIT:
        return _failure("invalid_seats")
    note = request.POST.get("note", "").strip()
    if len(note) > CONTACT_NOTE_MAX_LENGTH:
        return _failure("note_too_long")

    if cache.add("team_contact:%s" % user.pk, True, timeout=CONTACT_DEDUPE_SECONDS):
        membership = TeamMember.active_membership(user)
        lines = [
            "%s asked for a team of %s seats, named %s." % (user.username, seats, name),
            "Account: %s, %s, user id %s, on %s."
            % (user.username, user.email or "no email", user.pk, TeamProGrant.tier_of(user.profile)),
        ]
        if membership:
            team = membership.team
            lines.append(
                "Their team: %s, %s, %s of %s seats in use, %s, as %s."
                % (
                    team.name,
                    team.plan,
                    team.active_members().count(),
                    team.seat_limit,
                    team.status,
                    membership.role,
                )
            )
            TeamActivity.log(team, user, "more_seats_requested", seats=seats, name=name)
        lines.append("Note: %s" % (note or "none"))
        EmailStaffNotification.delay(
            event_type="team_more_seats",
            subject="Team of %s seats requested: %s" % (seats, user.username),
            body="\n\n".join(lines),
        )
    return {"code": 1, "message": str(MORE_SEATS_SENT)}
