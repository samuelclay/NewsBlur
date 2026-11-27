"""The shared site limit. A team follows at most as many sites as one Premium Pro account, counted as the distinct
active sites of its owner and everyone holding a seat (apps/team/models.py TeamScope). A site someone on the team
already follows costs nothing more, muted sites cost nothing, and a teammate's sites stop counting when their seat
ends. Accounts on no team keep the limits they have on their own."""

from django.core.cache import cache
from django.utils.translation import gettext

from apps.profile.models import Profile
from apps.reader.models import UserSubscription
from apps.team.models import Team, TeamMember, team_scope
from utils.languages import localized_number

# sites.py: how long the count shown to the web client (site_limit_shown) is reused. Every check before a site
# becomes active counts again.
SHOWN_COUNT_SECONDS = 5 * 60


def site_limit():
    return Profile.PRO_FEED_LIMIT


def _active_sites(member_ids):
    return UserSubscription.objects.filter(user_id__in=member_ids, active=True)


class TeamRoom:
    """The room a team has for sites, asked one site at a time in the order they would become active."""

    def __init__(self, followed, room):
        self.followed = followed
        self.room = room

    def admits(self, feed_id):
        if feed_id in self.followed:
            return True
        if self.room <= 0:
            return False
        self.room -= 1
        self.followed.add(feed_id)
        return True


class TeamSites:
    """One team's shared sites, read with the team row locked until the surrounding transaction ends, so two
    teammates adding sites at once can't both take its last room."""

    def __init__(self, team_id):
        self.team_id = team_id
        self.member_ids = list(
            TeamMember.objects.filter(team_id=team_id, status=TeamMember.STATUS_ACTIVE).values_list(
                "user_id", flat=True
            )
        )

    @classmethod
    def lock_for(cls, user):
        """For someone on an active team, inside the transaction that makes their sites active. Taken before
        any other row lock, the order every team change locks in. None for everyone else."""
        scope = team_scope(user)
        if not scope:
            return None
        Team.objects.select_for_update().get(pk=scope.team_id)
        return cls(scope.team_id)

    def room_for(self, feed_ids, without_user_id=None):
        """The team's room for these sites. without_user_id leaves one teammate's own sites out of the count,
        for a choice that replaces all of them."""
        sites = _active_sites(self.member_ids)
        if without_user_id:
            sites = sites.exclude(user_id=without_user_id)
        followed = set(sites.filter(feed_id__in=feed_ids).values_list("feed_id", flat=True))
        return TeamRoom(followed, site_limit() - sites.values("feed_id").distinct().count())

    def fitting(self, feed_ids, without_user_id=None):
        """Of these sites, in order, the ones that can be active."""
        room = self.room_for(feed_ids, without_user_id)
        return [feed_id for feed_id in dict.fromkeys(feed_ids) if room.admits(feed_id)]

    def refusal_message(self):
        team = Team.objects.select_related("owner").get(pk=self.team_id)
        return gettext(
            "%(team)s has reached the %(limit)s sites everyone on the team shares. "
            "Mute a site, or ask %(owner)s, who owns the team, to make room."
        ) % {"team": team.name, "limit": localized_number(site_limit()), "owner": team.owner.username}


def fit_sites_on_join(member, reactivate_muted):
    """A new teammate's sites, fitted into the team's room as they join (apps/team/grants.py grant_team_pro),
    under the team row lock that TeamInvite.accept and activate_team hold. Joining is never refused: the active
    sites that don't fit are muted, newest first, for the teammate to choose from in the feed chooser. An account
    that wasn't premium also gets its muted sites back, oldest first, while the team has room."""
    subscriptions = UserSubscription.objects.filter(user_id=member.user_id)
    candidates = list(subscriptions.filter(active=True).order_by("pk").values_list("feed_id", flat=True))
    if reactivate_muted:
        candidates += list(
            subscriptions.filter(active=False).order_by("pk").values_list("feed_id", flat=True)
        )
    fitting = TeamSites(member.team_id).fitting(candidates, without_user_id=member.user_id)
    subscriptions.filter(active=True).exclude(feed_id__in=fitting).update(active=False)
    subscriptions.filter(active=False, feed_id__in=fitting).update(active=True)


def site_limit_shown(user):
    """The site limit the web client checks itself against (templates/base.html): this account's active sites
    plus what its team has left, with the team's count from a short cache. None when it is on no active team.
    """
    scope = team_scope(user)
    if not scope:
        return None
    cache_key = "team:%s:active_sites" % scope.team_id
    team_count = cache.get(cache_key)
    if team_count is None:
        team_count = _active_sites(scope.member_ids).values("feed_id").distinct().count()
        cache.set(cache_key, team_count, SHOWN_COUNT_SECONDS)
    own_count = UserSubscription.objects.filter(user=user, active=True).count()
    return own_count + max(0, site_limit() - team_count)
