"""
feed_cache.py: the feed list draws from its localStorage copy the moment the page loads, before
/reader/feeds answers (common/feed_list_cache.js, common/assetmodel.js load_feeds), and the
server's answer then merges in without redrawing it. Holds /reader/feeds on a reload to check
both, then signs out, which must clear the copy. Run it last: it ends signed out.
"""

STORED = """(() => {
  var keys = [];
  for (var i = 0; i < localStorage.length; i++) {
    if (localStorage.key(i).indexOf('NB:feed_list:') === 0) keys.push(localStorage.key(i));
  }
  var raw = keys.length && localStorage.getItem(keys[0]);
  var data = raw ? JSON.parse(raw) : null;
  return {keys: keys, feeds: data ? data.feeds.length : 0,
          secrets: data ? ['share_ext_token', 'social_services', 'user_profile'].filter(function (k) { return k in data; }) : []};
})()"""


def run(ctx):
    page = ctx.page
    ctx.login("/")
    page.wait_for_function("NEWSBLUR.assets.feed_list_subscriptions", timeout=30000)
    stored = ctx.evaluate(STORED)
    ctx.check(
        "the feed list is kept per user, without secrets",
        len(stored["keys"]) == 1 and stored["feeds"] > 0 and not stored["secrets"],
        stored,
    )

    held = []
    page.route("**/reader/feeds?**", lambda route: held.append(route))
    page.reload(wait_until="load")
    page.wait_for_function(
        "window.NEWSBLUR && NEWSBLUR.assets && NEWSBLUR.assets.folders.length", timeout=30000
    )
    ctx.wait(1500)
    early = ctx.evaluate(
        "(() => ({rows: $('.NB-feedlist .feed:visible').length, held: !NEWSBLUR.assets.feed_list_subscriptions.share_ext_token, "
        "counts: $('.NB-feedlist .unread_count:visible').length, "
        "filter: $('.NB-intelligence-slider .NB-active').length, "
        "unread_view: /unread_view_/.test($('.NB-feedlists').attr('class'))}))()"
    )
    # The cached draw once ran before reader.js bound its own feed list handlers, so the
    # intelligence filter never loaded: no counts, no feeds inside folders, no filter selected.
    ctx.check(
        "the feed list draws, with its counts and filter, before /reader/feeds answers",
        len(held) >= 1
        and early["rows"] > 0
        and early["held"]
        and early["counts"] > 0
        and early["filter"]
        and early["unread_view"],
        {"held_requests": len(held), **early},
    )
    ctx.shot("drawn-from-cache")

    # The list is usable straight away: a feed opens while the feed list request is still held.
    feed_id = ctx.pick_feed()
    ctx.open_feed(feed_id)
    ctx.check("a feed opens before the feed list request answers", ctx.state()["screen"] == "titles")
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)

    ctx.evaluate("(() => { window.__nb_first_row = document.querySelector('.NB-feedlist .feed'); })()")
    rows_before = ctx.evaluate("$('.NB-feedlist .feed:visible').length")
    for route in held:
        route.continue_()
    page.unroute("**/reader/feeds?**")
    page.wait_for_function(
        "NEWSBLUR.assets.feed_list_subscriptions && NEWSBLUR.assets.feed_list_subscriptions.share_ext_token",
        timeout=30000,
    )
    ctx.wait(800)
    after = ctx.evaluate(
        "(() => ({same_rows: window.__nb_first_row === document.querySelector('.NB-feedlist .feed'), "
        "rows: $('.NB-feedlist .feed:visible').length, player: !!NEWSBLUR.app.media_player.state_restored}))()"
    )
    ctx.check(
        "the server's list merges in without redrawing the feed list",
        after["same_rows"] and after["rows"] == rows_before,
        after,
    )
    ctx.check("the Listen player restores from the server's state", after["player"], after)

    page.goto("https://localhost/reader/logout", wait_until="load")
    ctx.wait(1000)
    ctx.check("signing out clears the kept feed list", not ctx.evaluate(STORED)["keys"])
    ctx.check_no_page_errors()
