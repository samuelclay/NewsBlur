"""
dashboard_realtime.py: every dashboard module takes the new stories announced for its feeds.

A story announced over the socket (reader.js feed:story:new) goes to each dashboard module, which asks
assetmodel.js add_dashboard_story to fetch it into its own stories. Those fetches are batched, and the batch
used to remember only the first module that ever asked: a story for a feed in two modules reached one of
them, and once the modules were rebuilt (feed_options_popover.js does that when a module changes river) no
module took new stories until the page reloaded.

The announcement and the story are made up here, so the run needs no new story on the server: the page's own
feed:story:new listeners are called, and the fetch of the story by its hash is answered in the test.
"""

import json
import time
from urllib.parse import parse_qs, urlparse

from desktop import VIEWPORT  # noqa: F401  (desktop.py: a 1440x900 window without touch)

# Modules that take new stories in real time, with the feeds each would take one from. A module ordered oldest
# first only takes stories older than its newest, and saved searches, blurblogs and the curated rivers take none.
MODULES = """(() => {
    var modules = [];
    _.each(['left', 'right'], function (side) {
        _.each(NEWSBLUR.app.dashboard_rivers[side].rivers, function (river, index) {
            var river_id = river.model.get('river_id');
            if (river.options.global_feed || river.options.query) return;
            if (!/^(river:|feed:)/.test(river_id)) return;
            if (NEWSBLUR.assets.view_setting(river_id, 'order') != 'newest') return;
            var feed_ids = river.feeds(true);
            if (river.options.infrequent) {
                var threshold = NEWSBLUR.assets.preference('infrequent_stories_per_month');
                feed_ids = _.filter(NEWSBLUR.assets.feeds.pluck('id'), function (feed_id) {
                    return NEWSBLUR.assets.get_feed(feed_id).get('average_stories_per_month') <= threshold;
                });
            }
            feed_ids = _.filter(feed_ids, function (feed_id) {
                var feed = NEWSBLUR.assets.get_feed(feed_id);
                return feed && feed.get('active') && !feed.get('is_daily_briefing');
            });
            modules.push({ name: side + ' ' + index + ' (' + (river_id == 'river:' ? 'All Site Stories' : river_id) + ')',
                           side: side, index: index, feed_ids: feed_ids });
        });
    });
    return modules;
})()"""

TEMPLATE_STORY = """(() => {
    var story = null;
    _.each(['left', 'right'], function (side) {
        _.each(NEWSBLUR.app.dashboard_rivers[side].rivers, function (river) {
            story = story || river.options.dashboard_stories.first();
        });
    });
    return story && story.toJSON();
})()"""


class NewStories:
    """Made-up stories the page can hear about and fetch by hash."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.stories = {}
        self.template = ctx.evaluate(TEMPLATE_STORY)
        ctx.page.route("**/reader/river_stories**", self.on_route)

    def on_route(self, route):
        request = route.request
        query = parse_qs(urlparse(request.url).query)
        if request.post_data:
            query.update(parse_qs(request.post_data))
        hashes = query.get("h", [])
        if not hashes:
            return route.continue_()
        stories = [self.stories[story_hash] for story_hash in hashes if story_hash in self.stories]
        route.fulfill(
            content_type="application/json",
            body=json.dumps({"stories": stories, "user_profiles": [], "classifiers": {}}),
        )

    def announce(self, feed_id, label):
        """Tells the page of a new story in the feed, dated now, as node/unread_counts.js would."""
        timestamp = int(time.time())
        story_hash = f"{feed_id}:{label[:2]}{timestamp % 10000:04d}"
        title = f"Dashboard realtime {label}"
        story = dict(self.template)
        story.update(
            id=f"https://example.com/{story_hash}",
            story_hash=story_hash,
            guid_hash=story_hash.split(":")[1],
            story_feed_id=feed_id,
            story_title=title,
            story_timestamp=str(timestamp),
            read_status=0,
            # Liked, so the module shows it at any Focus level.
            intelligence={"feed": 1, "author": 0, "tags": 0, "title": 0},
        )
        self.stories[story_hash] = story
        self.ctx.evaluate(
            f"""(() => {{
                _.each(NEWSBLUR.reader.socket.listeners('feed:story:new'), function (listener) {{
                    listener('{feed_id}:story', '{story_hash},{timestamp}');
                }});
            }})()"""
        )
        return title

    def stop(self):
        self.ctx.page.unroute_all(behavior="ignoreErrors")


def shows(ctx, module, title):
    """Whether the module's list has a row for the story."""
    return ctx.evaluate(
        f"""(() => {{
            var river = NEWSBLUR.app.dashboard_rivers['{module['side']}'].rivers[{module['index']}];
            return _.any(river.$('.NB-story-title .NB-storytitles-title'), function (el) {{
                return $(el).text().trim() == {json.dumps(title)};
            }});
        }})()"""
    )


def check_modules(ctx, modules, title, name):
    ctx.wait(3500)
    for module in modules:
        ctx.check(f"{name}: {module['name']} shows the new story", shows(ctx, module, title))


def wait_for_modules(ctx):
    ctx.page.wait_for_function(
        "NEWSBLUR.app.dashboard_rivers && NEWSBLUR.reader.socket && "
        "NEWSBLUR.reader.socket.listeners('feed:story:new').length",
        timeout=60000,
    )
    ctx.wait(5000)


def run(ctx):
    ctx.login("/")
    wait_for_modules(ctx)
    modules = ctx.evaluate(MODULES)
    shared = None
    for first in modules:
        for second in modules:
            if first is second:
                continue
            both = set(first["feed_ids"]) & set(second["feed_ids"])
            if both and not shared:
                shared = (sorted(both)[0], [first, second])
    if not shared:
        raise RuntimeError(
            "The dashboard needs two modules, ordered newest first, that share a feed "
            "(All Site Stories and Infrequent Site Stories do)"
        )
    feed_id, sharing = shared
    stories = NewStories(ctx)
    if not stories.template:
        raise RuntimeError("No dashboard module has a story to model a new one on")
    try:
        title = stories.announce(feed_id, "shared by two modules")
        check_modules(ctx, sharing, title, "a feed in two modules")
        ctx.shot("01-two-modules")

        # feed_options_popover.js rebuilds every module when one is pointed at another river.
        ctx.evaluate("NEWSBLUR.reader.load_dashboard_rivers(true)")
        wait_for_modules(ctx)
        title = stories.announce(feed_id, "after the modules are rebuilt")
        check_modules(ctx, sharing, title, "rebuilt modules")
        ctx.shot("02-rebuilt")
    finally:
        stories.stop()
    ctx.check_no_page_errors()
