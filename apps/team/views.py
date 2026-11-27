"""Team views: teams, members, roles, invites and join links (apps/team/models.py)."""

import re

from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.utils.translation import gettext_lazy

from apps.team.grants import own_plan_on_join
from apps.team.models import Team, TeamActivity, TeamInvite, TeamMember
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
}


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
    # views.py: staff only until teams can be bought.
    user = get_user(request)
    if not user.is_staff:
        return _failure("not_allowed")
    name = _clean_name(request.POST["name"])
    if not name:
        return _failure("invalid_name")
    plan = request.POST.get("plan", Team.PLAN_TEAM)
    if plan not in dict(Team.PLAN_CHOICES):
        return _failure("invalid_plan")

    team, reason = Team.create_team(user, name, plan)
    if reason:
        return _failure(reason)
    return _team_response(user, team.pk)


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
    user = get_user(request)
    membership = _membership(user, request.POST["team_id"])
    if not membership:
        return _failure("not_found")
    if membership.role != TeamMember.ROLE_OWNER:
        return _failure("not_allowed")
    member = _membership(request.POST["user_id"], membership.team_id)
    if not member:
        return _failure("not_found")

    reason = membership.team.transfer_ownership(membership, member)
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
