import datetime
import secrets
from types import SimpleNamespace

from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.core.mail import EmailMultiAlternatives
from django.db import IntegrityError, models, transaction
from django.db.models import Q
from django.template.loader import render_to_string
from django.utils.text import slugify
from django.utils.translation import gettext

from utils import log as logging
from utils.languages import account_translation


class Team(models.Model):
    PLAN_TEAM = "team"
    PLAN_TEAM_ENTERPRISE = "team_enterprise"
    PLAN_CHOICES = (
        (PLAN_TEAM, "Premium Team"),
        (PLAN_TEAM_ENTERPRISE, "Premium Team Enterprise"),
    )

    STATUS_ACTIVE = "active"
    STATUS_INACTIVE = "inactive"
    STATUS_CHOICES = (
        (STATUS_ACTIVE, "Active"),
        (STATUS_INACTIVE, "Inactive"),
    )

    PROVIDER_STRIPE = "stripe"
    PROVIDER_PAYPAL = "paypal"
    PROVIDER_APP_STORE = "app_store"
    PROVIDER_PLAY = "play"
    # models.py: a team staff give away. Only a comp may leave paid_through empty (apps/team/billing.py).
    PROVIDER_COMP = "comp"
    PROVIDER_CHOICES = (
        (PROVIDER_STRIPE, "Stripe"),
        (PROVIDER_PAYPAL, "PayPal"),
        (PROVIDER_APP_STORE, "App Store"),
        (PROVIDER_PLAY, "Google Play"),
        (PROVIDER_COMP, "Comp"),
    )
    PAID_PROVIDERS = (PROVIDER_STRIPE, PROVIDER_PAYPAL, PROVIDER_APP_STORE, PROVIDER_PLAY)
    # models.py: providers charge a renewal some hours after the paid period ends, so a team lapses only once a
    # day has passed without one, rather than lapsing and coming straight back on every renewal.
    LAPSE_AFTER = datetime.timedelta(days=1)

    DEFAULT_SEAT_LIMIT = 10
    NAME_MAX_LENGTH = 100
    # models.py: counts invite_sent activity, so re-sending a live invite counts against it too.
    EMAIL_INVITES_PER_DAY = 50
    # models.py: attempts at a free slug when teams with the same name are created at the same moment.
    SLUG_ATTEMPTS = 3

    name = models.CharField(max_length=NAME_MAX_LENGTH)
    slug = models.SlugField(max_length=120, unique=True)
    # models.py: the account that pays, and the user id everything the team shares falls under
    # (team_owner_id). An account owns at most one team. TeamMember holds the owner role too; create_team and
    # transfer_ownership keep the two in step. Deleting the owner's account leaves the team for staff to
    # reassign.
    owner = models.OneToOneField(
        User, related_name="owned_team", null=True, blank=True, on_delete=models.SET_NULL
    )
    plan = models.CharField(max_length=32, choices=PLAN_CHOICES, default=PLAN_TEAM)
    seat_limit = models.PositiveIntegerField(default=DEFAULT_SEAT_LIMIT)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    # models.py: the end of the owner's paid period, written by billing. The hourly team-pro-grants task
    # (apps/team/tasks.py) lapses the team a day after it passes. Only a comp may leave it empty (Team.lapsed).
    paid_through = models.DateTimeField(null=True, blank=True)
    # models.py: who bills the team and the id that stays the same across its renewals, written by
    # apps/team/billing.py record_team_payment. Empty until the first payment.
    billing_provider = models.CharField(max_length=16, choices=PROVIDER_CHOICES, null=True, blank=True)
    billing_reference = models.TextField(null=True, blank=True)
    pending_owner = models.ForeignKey(
        User, related_name="+", null=True, blank=True, on_delete=models.SET_NULL
    )
    transfer_requested_date = models.DateTimeField(null=True, blank=True)
    # models.py: empty while the team still has the default name it was bought with (record_team_payment), so
    # the owner is asked for a real one.
    name_confirmed_date = models.DateTimeField(null=True, blank=True)
    created_date = models.DateTimeField(default=datetime.datetime.now)
    updated_date = models.DateTimeField(auto_now=True)

    def __str__(self):
        return "%s (%s)" % (self.name, self.slug)

    @classmethod
    def lapsed(cls, now):
        """The filter for a team whose plan has lapsed at a moment: nobody owns it, its paid period ended more than
        LAPSE_AFTER before, or it has no paid period and isn't a comp. The hourly task (apps/team/tasks.py) ends an
        active team that matches, and PremiumExpire (apps/profile/tasks.py) stops sparing its owner."""
        return (
            Q(owner__isnull=True)
            | Q(paid_through__lt=now - cls.LAPSE_AFTER)
            | Q(paid_through__isnull=True)
            & (Q(billing_provider__isnull=True) | Q(billing_provider__in=cls.PAID_PROVIDERS))
        )

    @classmethod
    def paid_for(cls, now):
        """The active teams whose plan hasn't lapsed at a moment (lapsed)."""
        return cls.objects.filter(status=cls.STATUS_ACTIVE).exclude(cls.lapsed(now))

    @classmethod
    def create_team(cls, owner, name, plan=PLAN_TEAM, name_confirmed=True):
        """Returns (team, None), or (None, failure reason) when the owner already has a team or is on one.
        name_confirmed is False for a team started with a default name. Teams start through apps/team/billing.py,
        which gives the owner Premium Pro: everything that skips the team lookup for accounts without Pro
        (team_scope) counts on every owner of an active team having it."""
        name_confirmed_date = datetime.datetime.now() if name_confirmed else None
        for attempt in range(cls.SLUG_ATTEMPTS):
            try:
                with transaction.atomic():
                    reason = cls._creation_refusal(owner)
                    if reason:
                        return None, reason
                    team = cls.objects.create(
                        name=name,
                        slug=cls._unique_slug(name),
                        owner=owner,
                        plan=plan,
                        name_confirmed_date=name_confirmed_date,
                    )
                    TeamMember.objects.create(team=team, user=owner, role=TeamMember.ROLE_OWNER)
                    TeamActivity.log(team, owner, "team_created", name=name, plan=plan)
                return team, None
            except IntegrityError:
                # models.py: a create or accept by the same account committed first, so the one team per owner
                # or one active team per account constraint refused this one, and asking again names which.
                # Otherwise a team with the same name took the slug first, and the next attempt picks another.
                reason = cls._creation_refusal(owner)
                if reason:
                    return None, reason
                if attempt == cls.SLUG_ATTEMPTS - 1:
                    raise

    @classmethod
    def _creation_refusal(cls, owner):
        if cls.objects.filter(owner=owner).exists():
            return "already_owns_team"
        if TeamMember.active_membership(owner):
            return "already_on_team"
        return None

    @classmethod
    def _unique_slug(cls, name):
        base = slugify(name)[: cls.NAME_MAX_LENGTH] or "team"
        slug = base
        suffix = 2
        while cls.objects.filter(slug=slug).exists():
            slug = "%s-%s" % (base, suffix)
            suffix += 1
        return slug

    def active_members(self):
        return self.members.filter(status=TeamMember.STATUS_ACTIVE).select_related("user")

    def pending_invites(self):
        return self.invites.filter(
            kind=TeamInvite.KIND_EMAIL,
            accepted_date__isnull=True,
            revoked_date__isnull=True,
            expire_date__gt=datetime.datetime.now(),
        )

    def live_join_link(self):
        return self.invites.filter(kind=TeamInvite.KIND_LINK, revoked_date__isnull=True).first()

    def lock(self):
        """Lock this team's row until the surrounding transaction ends. Every change to its seats, roles and
        owner, every invite sent and every new join link happens under this lock."""
        return Team.objects.select_for_update().get(pk=self.pk)

    def rename(self, actor, name):
        """Only the owner renames the team (apps/team/views.py), and the first rename confirms the name."""
        old_name = self.name
        self.name = name
        if not self.name_confirmed_date:
            self.name_confirmed_date = datetime.datetime.now()
        self.save(update_fields=["name", "name_confirmed_date", "updated_date"])
        TeamActivity.log(self, actor, "team_renamed", old_name=old_name, name=name)

    def invite_by_email(self, actor, emails, role):
        """Invite each address, or refresh and resend its live invite. Returns a failure reason or None. The team
        row lock keeps the daily limit and one live invite per address when invites are sent at once, and each
        email goes out from its own task once the invites have committed (apps/team/tasks.py)."""
        # models.py: apps/team/tasks.py imports apps/team/grants.py, which imports apps.profile, which imports
        # this module.
        from apps.team.tasks import SendTeamInviteEmail

        with transaction.atomic():
            team = self.lock()
            if team.status != Team.STATUS_ACTIVE:
                return "team_inactive"
            now = datetime.datetime.now()
            day_ago = now - datetime.timedelta(days=1)
            sent_today = self.activities.filter(action="invite_sent", created_date__gte=day_ago).count()
            if sent_today + len(emails) > self.EMAIL_INVITES_PER_DAY:
                return "invite_limit"

            expire_date = now + datetime.timedelta(days=TeamInvite.EMAIL_INVITE_DAYS)
            for email in emails:
                invite = self.pending_invites().filter(email__iexact=email).first()
                if invite:
                    # models.py: a resend dates the invite anew, which is what lets it bring back someone
                    # removed before it (TeamInvite.accept).
                    invite.role = role
                    invite.created_by = actor
                    invite.created_date = now
                    invite.expire_date = expire_date
                    invite.save(update_fields=["role", "created_by", "created_date", "expire_date"])
                else:
                    invite = TeamInvite.objects.create(
                        team=self,
                        kind=TeamInvite.KIND_EMAIL,
                        email=email,
                        token=TeamInvite.new_token(),
                        role=role,
                        created_by=actor,
                        created_date=now,
                        expire_date=expire_date,
                    )
                TeamActivity.log(self, actor, "invite_sent", email=email, role=role)
                transaction.on_commit(
                    lambda invite_id=invite.pk: SendTeamInviteEmail.delay(invite_id=invite_id)
                )
        return None

    def create_join_link(self, actor):
        """Replace any live join link with a new one, so a team never has two. Returns a failure reason or
        None."""
        with transaction.atomic():
            team = self.lock()
            if team.status != Team.STATUS_ACTIVE:
                return "team_inactive"
            replaced = self.invites.filter(kind=TeamInvite.KIND_LINK, revoked_date__isnull=True).update(
                revoked_date=datetime.datetime.now()
            )
            TeamInvite.objects.create(
                team=self,
                kind=TeamInvite.KIND_LINK,
                token=TeamInvite.new_token(),
                role=TeamMember.ROLE_MEMBER,
                created_by=actor,
            )
            TeamActivity.log(self, actor, "join_link_created", replaced=bool(replaced))
        return None

    def revoke_join_link(self, actor):
        revoked = self.invites.filter(kind=TeamInvite.KIND_LINK, revoked_date__isnull=True).update(
            revoked_date=datetime.datetime.now()
        )
        if revoked:
            TeamActivity.log(self, actor, "join_link_revoked")

    def _locked_seats(self, actor_membership, member):
        """Lock the team row and read both seats again, so a role or seat change decided on an earlier read
        can't cross another one. Every change to who holds which seat goes through this lock. Returns the actor's
        and the member's active seats; either is None once it is no longer active."""
        self.lock()
        seats = TeamMember.objects.select_related("user").filter(team=self, status=TeamMember.STATUS_ACTIVE)
        return seats.filter(pk=actor_membership.pk).first(), seats.filter(pk=member.pk).first()

    def change_role(self, actor_membership, member, role):
        """Only the owner changes roles, and never their own. Returns a failure reason or None."""
        with transaction.atomic():
            actor, member = self._locked_seats(actor_membership, member)
            if not actor or actor.role != TeamMember.ROLE_OWNER:
                return "not_allowed"
            if not member:
                return "not_found"
            if member.role == TeamMember.ROLE_OWNER:
                return "not_allowed"
            old_role = member.role
            if old_role == role:
                return None
            member.role = role
            member.save(update_fields=["role"])
            TeamActivity.log(
                self,
                actor.user,
                "role_changed",
                user_id=member.user_id,
                username=member.user.username,
                old_role=old_role,
                role=role,
            )
        return None

    def remove_member(self, actor_membership, member):
        """Returns a failure reason or None."""
        with transaction.atomic():
            actor, member = self._locked_seats(actor_membership, member)
            if not actor:
                return "not_allowed"
            if not member:
                return "not_found"
            if not actor.can_remove(member):
                return "not_allowed"
            member.mark_removed(removed_by=actor.user, departure=TeamMember.DEPARTURE_REMOVED)
            TeamActivity.log(
                self, actor.user, "member_removed", user_id=member.user_id, username=member.user.username
            )
        return None

    def transfer_ownership(self, owner_membership, new_owner_membership):
        """The new owner must be another active member. The old owner stays on as a manager.
        Returns a failure reason or None."""
        with transaction.atomic():
            owner, new_owner = self._locked_seats(owner_membership, new_owner_membership)
            if not owner or owner.role != TeamMember.ROLE_OWNER:
                return "not_allowed"
            if not new_owner or new_owner.pk == owner.pk:
                return "not_found"
            owner.role = TeamMember.ROLE_MANAGER
            owner.save(update_fields=["role"])
            new_owner.role = TeamMember.ROLE_OWNER
            new_owner.save(update_fields=["role"])
            self.owner = new_owner.user
            self.save(update_fields=["owner", "updated_date"])
            TeamActivity.log(
                self,
                owner.user,
                "ownership_transferred",
                user_id=new_owner.user_id,
                username=new_owner.user.username,
            )
        return None

    def canonical(self, membership):
        members = list(self.active_members().order_by("joined_date"))
        data = {
            "id": self.pk,
            "name": self.name,
            "name_needs_confirming": self.name_confirmed_date is None,
            "slug": self.slug,
            "plan": self.plan,
            "status": self.status,
            "seat_limit": self.seat_limit,
            "seats_used": len(members),
            "role": membership.role,
            "members": [member.canonical() for member in members],
        }
        if membership.is_manager:
            invites = self.pending_invites().select_related("created_by").order_by("-created_date")
            data["invites"] = [invite.canonical() for invite in invites]
            join_link = self.live_join_link()
            data["join_link"] = join_link and {
                "url": join_link.join_url,
                "created_date": join_link.created_date,
            }
        return data


class TeamMember(models.Model):
    ROLE_OWNER = "owner"
    ROLE_MANAGER = "manager"
    ROLE_MEMBER = "member"
    ROLE_CHOICES = (
        (ROLE_OWNER, "Owner"),
        (ROLE_MANAGER, "Manager"),
        (ROLE_MEMBER, "Member"),
    )

    STATUS_ACTIVE = "active"
    STATUS_REMOVED = "removed"
    STATUS_CHOICES = (
        (STATUS_ACTIVE, "Active"),
        (STATUS_REMOVED, "Removed"),
    )

    DEPARTURE_LEFT = "left"
    DEPARTURE_REMOVED = "removed"
    DEPARTURE_CHOICES = (
        (DEPARTURE_LEFT, "Left"),
        (DEPARTURE_REMOVED, "Removed"),
    )

    team = models.ForeignKey(Team, related_name="members", on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name="team_memberships", on_delete=models.CASCADE)
    role = models.CharField(max_length=16, choices=ROLE_CHOICES, default=ROLE_MEMBER)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    invited_by = models.ForeignKey(User, related_name="+", null=True, blank=True, on_delete=models.SET_NULL)
    # models.py: who ended the seat. The member themselves when they left, a manager or owner when removed.
    removed_by = models.ForeignKey(User, related_name="+", null=True, blank=True, on_delete=models.SET_NULL)
    # models.py: whether the seat ended by leaving or by a removal. It outlives removed_by, which empties when the
    # remover's account is deleted, and decides how the person may come back (TeamInvite.accept).
    departure = models.CharField(max_length=8, choices=DEPARTURE_CHOICES, null=True, blank=True)
    joined_date = models.DateTimeField(default=datetime.datetime.now)
    removed_date = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("team", "user")
        constraints = [
            # models.py: an account is active on one team at a time, as owner or member. This settles one
            # account accepting two teams' invites at the same moment, which no single team lock can.
            models.UniqueConstraint(
                fields=["user"], condition=Q(status="active"), name="team_member_one_active_team"
            ),
        ]

    def __str__(self):
        return "%s on %s (%s, %s)" % (self.user_id, self.team_id, self.role, self.status)

    @classmethod
    def active_membership(cls, user):
        return cls.objects.select_related("team").filter(user=user, status=cls.STATUS_ACTIVE).first()

    @property
    def is_manager(self):
        return self.role in (self.ROLE_OWNER, self.ROLE_MANAGER)

    def can_remove(self, member):
        """Owners remove managers and members, managers remove members. Nobody removes the owner or
        themselves; leaving is its own action."""
        if member.pk == self.pk or member.role == self.ROLE_OWNER:
            return False
        if self.role == self.ROLE_OWNER:
            return True
        return self.role == self.ROLE_MANAGER and member.role == self.ROLE_MEMBER

    def mark_removed(self, removed_by, departure):
        """Called under the team row lock (Team._locked_seats, leave). Team Pro ends with the seat, in the same
        transaction, and once that commits the person gets one email saying which plan they are on now. A
        teammate of a lapsed team has no Pro left to end, and the lapse already emailed them."""
        # models.py: apps/team/grants.py imports apps.profile, which imports this module.
        from apps.team.grants import release_team_pro, send_seat_ended_email

        self.status = self.STATUS_REMOVED
        self.removed_by = removed_by
        self.departure = departure
        self.removed_date = datetime.datetime.now()
        self.save(update_fields=["status", "removed_by", "departure", "removed_date"])

        plan = release_team_pro(self.user)
        if plan is None:
            return
        team = self.team
        transaction.on_commit(lambda: send_seat_ended_email(self.user, team, plan))

    def leave(self):
        """Returns a failure reason or None. The role is read again under the team row lock, so a transfer that
        makes this member the owner at the same moment can't leave the team without one."""
        with transaction.atomic():
            self.team.lock()
            seat = (
                TeamMember.objects.filter(pk=self.pk, status=self.STATUS_ACTIVE)
                .select_related("team")
                .first()
            )
            if not seat:
                return "not_found"
            if seat.role == self.ROLE_OWNER:
                return "owner_cannot_leave"
            seat.mark_removed(removed_by=self.user, departure=self.DEPARTURE_LEFT)
            TeamActivity.log(seat.team, self.user, "member_left")
        return None

    def canonical(self):
        return {
            "user_id": self.user_id,
            "username": self.user.username,
            "role": self.role,
            "joined_date": self.joined_date,
        }


class TeamInvite(models.Model):
    KIND_EMAIL = "email"
    KIND_LINK = "link"
    KIND_CHOICES = (
        (KIND_EMAIL, "Email"),
        (KIND_LINK, "Join link"),
    )

    EMAIL_INVITE_DAYS = 14

    team = models.ForeignKey(Team, related_name="invites", on_delete=models.CASCADE)
    kind = models.CharField(max_length=8, choices=KIND_CHOICES)
    email = models.EmailField(blank=True)
    token = models.CharField(max_length=64, unique=True)
    role = models.CharField(max_length=16, choices=TeamMember.ROLE_CHOICES, default=TeamMember.ROLE_MEMBER)
    created_by = models.ForeignKey(User, related_name="+", null=True, blank=True, on_delete=models.SET_NULL)
    created_date = models.DateTimeField(default=datetime.datetime.now)
    # models.py: email invites expire; a join link lives until it is revoked or regenerated.
    expire_date = models.DateTimeField(null=True, blank=True)
    accepted_by = models.ForeignKey(User, related_name="+", null=True, blank=True, on_delete=models.SET_NULL)
    accepted_date = models.DateTimeField(null=True, blank=True)
    revoked_date = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["team"],
                condition=Q(kind="link", revoked_date__isnull=True),
                name="team_invite_one_live_join_link",
            ),
        ]

    def __str__(self):
        return "%s invite to %s (%s)" % (self.kind, self.team_id, self.email or "link")

    @staticmethod
    def new_token():
        return secrets.token_urlsafe(24)

    @property
    def join_url(self):
        # models.py: the web reader's ?next= handler opens the join screen for this token.
        return "https://%s/?next=team_join&team_invite=%s" % (Site.objects.get_current().domain, self.token)

    def refusal_reason(self):
        if self.revoked_date:
            return "invite_revoked"
        if self.kind == self.KIND_EMAIL and self.accepted_date:
            return "invite_used"
        if self.expire_date and self.expire_date <= datetime.datetime.now():
            return "invite_expired"
        if self.team.status != Team.STATUS_ACTIVE:
            return "team_inactive"
        return None

    def returns_removed_member(self, member):
        """Someone a manager removed comes back only by an email invite sent after the removal, so neither a
        join link they kept nor an older invite still in their inbox reopens the seat. Someone who left can
        come back with either."""
        if member.departure != TeamMember.DEPARTURE_REMOVED:
            return True
        return self.kind == self.KIND_EMAIL and self.created_date > member.removed_date

    def accept(self, user):
        """Join the team, reusing the user's earlier seat row if they had one. Returns a failure reason or
        None. The team row lock makes the seat count and the single use of an email invite hold when several
        people accept at once."""
        # models.py: apps/team/grants.py and apps/team/tasks.py import apps.profile, which imports this module.
        from apps.team.grants import grant_team_pro, own_subscription
        from apps.team.tasks import SettleOwnPlanOnJoin

        try:
            with transaction.atomic():
                team = self.team.lock()
                invite = TeamInvite.objects.select_related("team").get(pk=self.pk)
                reason = invite.refusal_reason()
                if reason:
                    return reason

                member = TeamMember.objects.filter(team=team, user=user).first()
                if member and member.status == TeamMember.STATUS_ACTIVE:
                    return "already_member"
                if member and not invite.returns_removed_member(member):
                    return "removed_by_team"
                if TeamMember.active_membership(user):
                    return "already_on_team"
                if team.members.filter(status=TeamMember.STATUS_ACTIVE).count() >= team.seat_limit:
                    return "seat_limit"

                now = datetime.datetime.now()
                rejoin = {}
                if not member:
                    member = TeamMember(team=team, user=user)
                elif member.removed_date:
                    # models.py: the seat row is reused, so the stint it held is kept on the join for the shared
                    # allowances to count what the team used during it (_earlier_seats).
                    rejoin["earlier_seat"] = [member.joined_date.isoformat(), member.removed_date.isoformat()]
                member.role = invite.role
                member.status = TeamMember.STATUS_ACTIVE
                member.invited_by = invite.created_by
                member.joined_date = now
                member.removed_by = None
                member.departure = None
                member.removed_date = None
                member.save()

                if invite.kind == self.KIND_EMAIL:
                    invite.accepted_by = user
                    invite.accepted_date = now
                    invite.save(update_fields=["accepted_by", "accepted_date"])
                TeamActivity.log(team, user, "member_joined", role=invite.role, via=invite.kind, **rejoin)
                # models.py: granted in the seat's own transaction, so a seat never commits without its Pro.
                grant_team_pro(member)
                # models.py: the plan the joiner pays for on their own is settled once the seat commits, and only
                # on a join. A lapsed team coming back (apps/team/grants.py activate_team) leaves it alone.
                subscription = own_subscription(user)
                if subscription:
                    transaction.on_commit(
                        lambda: SettleOwnPlanOnJoin.delay(
                            user_id=user.pk, team_id=team.pk, subscription=subscription
                        )
                    )
        except IntegrityError:
            # models.py: the same account joined another team at the same moment, and the one active team
            # constraint on TeamMember refused this join.
            if TeamMember.active_membership(user):
                return "already_on_team"
            raise
        return None

    def revoke(self, actor):
        self.revoked_date = datetime.datetime.now()
        self.save(update_fields=["revoked_date"])
        TeamActivity.log(self.team, actor, "invite_revoked", email=self.email)

    def send_email(self):
        """Sent by SendTeamInviteEmail (apps/team/tasks.py) once the invite has committed."""
        inviter = self.created_by
        with account_translation(inviter.profile):
            data = dict(inviter=inviter, team=self.team, join_url=self.join_url, expire_date=self.expire_date)
            text = render_to_string("mail/email_team_invite.txt", data)
            html = render_to_string("mail/email_team_invite.xhtml", data)
            subject = gettext("%(username)s invited you to join %(team)s on NewsBlur") % {
                "username": inviter.username,
                "team": self.team.name,
            }
        msg = EmailMultiAlternatives(
            one_line(subject),
            text,
            from_email="NewsBlur <%s>" % settings.HELLO_EMAIL,
            to=[self.email],
        )
        msg.attach_alternative(html, "text/html")
        msg.send()

        # models.py: the invite id, never the address, which stays in the access controlled invite row.
        logging.user(inviter, "~BB~FM~SBSending team invite %s for team %s" % (self.pk, self.team_id))

    def preview(self):
        """What the join screen shows to whoever holds the token, before they accept."""
        return {
            "team_name": self.team.name,
            "member_count": self.team.members.filter(status=TeamMember.STATUS_ACTIVE).count(),
            "inviter": self.created_by.username if self.created_by else None,
            "role": self.role,
            "kind": self.kind,
        }

    def canonical(self):
        return {
            "id": self.pk,
            "email": self.email,
            "role": self.role,
            "invited_by": self.created_by.username if self.created_by else None,
            "created_date": self.created_date,
            "expire_date": self.expire_date,
        }


class TeamActivity(models.Model):
    PAGE_SIZE = 50

    team = models.ForeignKey(Team, related_name="activities", on_delete=models.CASCADE)
    actor = models.ForeignKey(User, related_name="+", null=True, blank=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=32)
    details = models.JSONField(default=dict, blank=True)
    created_date = models.DateTimeField(default=datetime.datetime.now)

    def __str__(self):
        return "%s on %s by %s" % (self.action, self.team_id, self.actor_id)

    @classmethod
    def log(cls, team, actor, action, **details):
        # models.py: details can hold an invitee's address, so the log line names only their keys. The row keeps
        # the values, where only the team's managers can read them.
        logging.user(actor, "~FC~SBTeam %s~SN: %s %s" % (team.pk, action, ", ".join(sorted(details))))
        return cls.objects.create(team=team, actor=actor, action=action, details=details)

    def canonical(self):
        return {
            "id": self.pk,
            "action": self.action,
            "actor_id": self.actor_id,
            "actor": self.actor.username if self.actor else None,
            "details": self.details,
            "date": self.created_date,
        }


class TeamProGrant(models.Model):
    """The Premium Pro a team gives one teammate (apps/team/grants.py). Their Profile carries the real Pro flags
    while they hold it, so this row keeps the plan they have on their own to go back to when the seat ends. It
    exists exactly as long as the seat is held on an active team."""

    TIER_FREE = "free"
    TIER_TRIAL = "trial"
    TIER_PREMIUM = "premium"
    TIER_ARCHIVE = "archive"
    TIER_ARCHIVE_EXTRA = "archive_extra"
    TIER_PRO = "pro"
    # models.py: lowest first. A plan bought during the seat only ever raises own_tier along this order.
    TIER_ORDER = (TIER_FREE, TIER_TRIAL, TIER_PREMIUM, TIER_ARCHIVE, TIER_ARCHIVE_EXTRA, TIER_PRO)
    TIER_CHOICES = tuple((tier, tier) for tier in TIER_ORDER)
    PAID_TIERS = (TIER_PREMIUM, TIER_ARCHIVE, TIER_ARCHIVE_EXTRA, TIER_PRO)
    # models.py: the Profile flags (apps/profile/models.py) that hold each plan.
    TIER_FLAGS = {
        TIER_FREE: dict(
            is_premium=False, is_premium_trial=False, is_archive=False, is_archive_extra=False, is_pro=False
        ),
        TIER_TRIAL: dict(
            is_premium=True, is_premium_trial=True, is_archive=False, is_archive_extra=False, is_pro=False
        ),
        TIER_PREMIUM: dict(
            is_premium=True, is_premium_trial=False, is_archive=False, is_archive_extra=False, is_pro=False
        ),
        TIER_ARCHIVE: dict(
            is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=False, is_pro=False
        ),
        TIER_ARCHIVE_EXTRA: dict(
            is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=True, is_pro=False
        ),
        TIER_PRO: dict(
            is_premium=True, is_premium_trial=False, is_archive=True, is_archive_extra=False, is_pro=True
        ),
    }

    user = models.OneToOneField(User, related_name="team_pro_grant", on_delete=models.CASCADE)
    # models.py: the seat the grant came from.
    member = models.ForeignKey(TeamMember, related_name="+", null=True, blank=True, on_delete=models.SET_NULL)
    own_tier = models.CharField(max_length=16, choices=TIER_CHOICES)
    own_trial_expire = models.DateTimeField(null=True, blank=True)
    # models.py: Profile.is_premium_trial when the grant began. None means the account never had a trial and
    # can still start one (Profile.start_premium_trial), which team Pro's flags would otherwise take away.
    own_premium_trial = models.BooleanField(null=True, blank=True)
    granted_date = models.DateTimeField(default=datetime.datetime.now)

    def __str__(self):
        return "Team Pro for %s (own %s)" % (self.user_id, self.own_tier)

    @classmethod
    def tier_of(cls, profile):
        if profile.is_pro:
            return cls.TIER_PRO
        if profile.is_archive:
            return cls.TIER_ARCHIVE_EXTRA if profile.is_archive_extra else cls.TIER_ARCHIVE
        if profile.is_premium:
            return cls.TIER_TRIAL if profile.is_premium_trial else cls.TIER_PREMIUM
        return cls.TIER_FREE

    def own_flags(self):
        """The Profile flags of the plan this person has on their own, for code that compares a payment with it."""
        return SimpleNamespace(**self.TIER_FLAGS[self.own_tier])

    def own_plan_on(self, profile, date):
        """The plan this person is on by themselves on a date: their tier while premium_expire, their own paid
        through date, covers it, their trial while it runs, and otherwise free."""
        if self.own_tier in self.PAID_TIERS and (
            profile.premium_expire is None or profile.premium_expire > date
        ):
            return self.own_tier
        if self.own_tier == self.TIER_TRIAL and self.own_trial_expire and self.own_trial_expire > date:
            return self.TIER_TRIAL
        return self.TIER_FREE

    def record_own_plan(self, tier, downgrade_extra=False):
        """The person bought, renewed or was given a plan of their own while holding team Pro. It can only raise
        the tier they go back to, except that a confirmed switch from Archive Extra to Archive lowers it, as in
        Profile.activate_archive. Returns True when the tier changed."""
        with transaction.atomic():
            grant = TeamProGrant.objects.select_for_update().filter(pk=self.pk).first()
            if not grant:
                return False
            if downgrade_extra and tier == self.TIER_ARCHIVE and grant.own_tier == self.TIER_ARCHIVE_EXTRA:
                own_tier = self.TIER_ARCHIVE
            elif self.TIER_ORDER.index(tier) > self.TIER_ORDER.index(grant.own_tier):
                own_tier = tier
            else:
                return False
            TeamProGrant.objects.filter(pk=self.pk).update(own_tier=own_tier)
        self.own_tier = own_tier
        logging.user(self.user, "~FMTeam Pro: own plan is now %s" % own_tier)
        return True

    def record_own_plan_ended(self):
        """A plan of the person's own expired or was cancelled while they held team Pro."""
        TeamProGrant.objects.filter(pk=self.pk).update(own_tier=self.TIER_FREE, own_trial_expire=None)
        self.own_tier = self.TIER_FREE
        self.own_trial_expire = None
        logging.user(self.user, "~FMTeam Pro: own plan ended, now free")


def one_line(text):
    """An email subject has to be one line, or Django refuses to send it. Team names are checked for line breaks
    when saved (apps/team/views.py); this keeps a subject one line whatever it was built from."""
    return " ".join(text.splitlines())


def team_pro_grant(user):
    """The Premium Pro this account holds from a team, or None. apps/profile reads it here, where it can
    without importing apps/team/grants.py."""
    return TeamProGrant.objects.filter(user=user).first()


def team_owner_id(user):
    """The user id this account's team usage falls under: the owner of the one team it is active on, which is
    its own id when it owns the team, or None when it is on no team or its team is inactive."""
    membership = TeamMember.active_membership(user)
    if not membership or membership.team.status != Team.STATUS_ACTIVE:
        return None
    return membership.team.owner_id


def teammate_seat_windows(owner_id, since):
    """(user_id, joined_date, removed_date) for each seat other than the owner's on the team owner_id owns that
    was held at some point since a date. removed_date is None while the seat is held. What a teammate runs up in
    that window falls under the owner (team_owner_id)."""
    seats = list(
        TeamMember.objects.filter(team__owner_id=owner_id)
        .exclude(user_id=owner_id)
        .filter(Q(removed_date__isnull=True) | Q(removed_date__gt=since))
        .values_list("user_id", "joined_date", "removed_date")
    )
    return seats + _earlier_seats(TeamActivity.objects.filter(team__owner_id=owner_id), seats, since)


def _earlier_seats(team_activities, seats, since):
    """A seat row is reused when someone rejoins (TeamInvite.accept), so its dates cover only their latest stint.
    Each rejoin keeps the stint before it on its member_joined activity. These are the earlier stints that ended
    after since, for the seats that started after it."""
    rejoined = [user_id for user_id, joined_date, _ in seats if joined_date > since]
    if not rejoined:
        return []
    joins = team_activities.filter(action="member_joined", actor_id__in=rejoined, created_date__gt=since)
    earlier = []
    for user_id, details in joins.values_list("actor_id", "details"):
        if "earlier_seat" not in details:
            continue
        joined_date, removed_date = (
            datetime.datetime.fromisoformat(date) for date in details["earlier_seat"]
        )
        if removed_date > since:
            earlier.append((user_id, joined_date, removed_date))
    return earlier


class TeamScope:
    """Whose usage counts as one active team's. A team is one Premium Pro account that up to ten people use, so
    everything Pro meters is one allowance for the team, counted against its owner: the owner's usage always,
    and each teammate's for the time they held a seat. Usage rows keep the user id of whoever used it, which is
    the per teammate breakdown."""

    def __init__(self, team_id, team_name, owner_id, owner_timezone, seats):
        self.team_id = team_id
        self.team_name = team_name
        self.owner_id = owner_id
        self.owner_timezone = owner_timezone
        # models.py: (user_id, joined_date, removed_date) of every seat on the team but the owner's, held or ended.
        self.seats = seats

    @property
    def member_ids(self):
        """The owner and everyone holding a seat now."""
        return [self.owner_id] + [user_id for user_id, _, removed_date in self.seats if removed_date is None]

    def windows(self, since):
        """(user_id, from, until) for each account whose usage since a moment is the team's. The owner's counts
        throughout, so its from and until are None."""
        seats = [seat for seat in self.seats if seat[2] is None or seat[2] > since]
        earlier = _earlier_seats(TeamActivity.objects.filter(team_id=self.team_id), seats, since)
        return [(self.owner_id, None, None)] + seats + earlier


def team_scope(user):
    """Whose usage counts with this account's (TeamScope), in one query, or None when it is on no active team so
    a caller counts the account alone. Everyone on an active team carries the Pro flags, so other accounts skip
    the lookup."""
    if not user.profile.is_pro:
        return None
    rows = list(
        TeamMember.objects.filter(
            team__members__user_id=user.pk,
            team__members__status=TeamMember.STATUS_ACTIVE,
            team__status=Team.STATUS_ACTIVE,
            team__owner__isnull=False,
        ).values_list(
            "team_id",
            "team__name",
            "team__owner_id",
            "team__owner__profile__timezone",
            "user_id",
            "joined_date",
            "removed_date",
        )
    )
    if not rows:
        return None
    team_id, team_name, owner_id, owner_timezone = rows[0][:4]
    seats = [row[4:] for row in rows if row[4] != owner_id]
    return TeamScope(team_id, team_name, owner_id, owner_timezone, seats)


def team_plan_fields(profile):
    """The team plan an account is on, for every client's profile payload (Profile.canonical and
    templates/base.html), where an owner and a teammate otherwise both look like Premium Pro. Owners and
    teammates alike get the plan and their role; only the owner gets the billing provider and the paid through
    date, as a Unix time. Each is None for an account on no active team. Everyone on an active team carries the
    Pro flags, so other accounts skip the lookup, and the rest take one query."""
    fields = dict(
        team_plan=None,
        team_role=None,
        team_billing_provider=None,
        team_paid_through=None,
        team_pending_owner=None,
    )
    if not profile.is_pro:
        return fields
    seat = (
        TeamMember.objects.filter(
            user_id=profile.user_id, status=TeamMember.STATUS_ACTIVE, team__status=Team.STATUS_ACTIVE
        )
        .values(
            "role",
            "team__plan",
            "team__billing_provider",
            "team__paid_through",
            "team__pending_owner__username",
        )
        .first()
    )
    if not seat:
        return fields
    fields.update(
        team_plan=seat["team__plan"],
        team_role=seat["role"],
        team_pending_owner=seat["team__pending_owner__username"],
    )
    if seat["role"] == TeamMember.ROLE_OWNER:
        paid_through = seat["team__paid_through"]
        fields.update(
            team_billing_provider=seat["team__billing_provider"],
            team_paid_through=int(paid_through.strftime("%s")) if paid_through else None,
        )
    return fields


def usage_query(scope, user_id, since, date_field):
    """A Mongo query for the usage rows that count against an allowance from a moment on: one account's, or
    with a TeamScope everyone's on its team, each in their own window. Rows keep the user in user_id and their
    date in date_field."""
    if not scope:
        return {"user_id": user_id}
    clauses = []
    for window_user_id, start, end in scope.windows(since):
        clause = {"user_id": window_user_id}
        dates = {}
        if start:
            dates["$gte"] = start
        if end:
            dates["$lt"] = end
        if dates:
            clause[date_field] = dates
        clauses.append(clause)
    return {"$or": clauses}
