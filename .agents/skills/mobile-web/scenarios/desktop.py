"""
desktop.py: a desktop-sized window never sees the phone layout or its chrome.
"""

DESKTOP_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36"
)
VIEWPORT = {"width": 1440, "height": 900, "mobile": False, "touch": False, "user_agent": DESKTOP_UA}


def run(ctx):
    ctx.login("/")
    ctx.check("the phone layout is inactive", not ctx.state()["active"])
    ctx.shot("01-dashboard")
    ctx.evaluate(f"NEWSBLUR.reader.open_feed({ctx.pick_feed()})")
    ctx.wait(3000)
    ctx.evaluate(
        "(() => { var story = NEWSBLUR.assets.stories.at(1); if (story) story.set('selected', true); })()"
    )
    ctx.wait(1500)
    ctx.check(
        "no phone chrome is visible",
        ctx.evaluate(
            "$('.NB-mobile-bar:visible, .NB-mobile-story-screen:visible, .NB-mobile-toolbar:visible').length == 0"
        ),
    )
    ctx.check("history entries are left untagged", not (ctx.state()["entry"]))
    ctx.shot("02-feed")

    # common/feed_list_cache.js: desktop draws the kept feed list before /reader/feeds answers too.
    page = ctx.page
    page.wait_for_function("NEWSBLUR.assets.feed_list_subscriptions", timeout=30000)
    held = []
    page.route("**/reader/feeds?**", lambda route: held.append(route))
    page.goto("https://localhost/", wait_until="load")
    page.wait_for_function(
        "window.NEWSBLUR && NEWSBLUR.assets && NEWSBLUR.assets.folders.length", timeout=30000
    )
    ctx.wait(1000)
    drawn = ctx.evaluate(
        "(() => ({rows: $('.NB-feedlist .feed:visible').length, counts: $('.NB-feedlist .unread_count:visible').length, "
        "filter: $('.NB-intelligence-slider .NB-active').length}))()"
    )
    ctx.check(
        "desktop draws the kept feed list, with counts and filter, before /reader/feeds answers",
        held and drawn["rows"] > 0 and drawn["counts"] > 0 and drawn["filter"],
        (len(held), drawn),
    )
    for route in held:
        route.continue_()
    page.unroute("**/reader/feeds?**")
    page.wait_for_function(
        "NEWSBLUR.assets.feed_list_subscriptions && NEWSBLUR.assets.feed_list_subscriptions.share_ext_token",
        timeout=30000,
    )
    ctx.check_no_page_errors()
