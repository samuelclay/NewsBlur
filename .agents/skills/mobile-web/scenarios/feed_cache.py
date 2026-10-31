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

    # The kept copy says one fetched feed was never fetched, as when a site was added just before
    # the page closed. Written into the copy in memory too, which the page saves as it hides.
    stale_feed = ctx.evaluate(
        """(() => {
      var feed = NEWSBLUR.assets.feeds.find(function (f) {
        return f.get('fetched_once') && !f.get('has_exception') && $('.NB-feedlist .feed[data-id="' + f.id + '"]:visible').length;
      });
      if (!feed) return null;
      var mark = function (data) { data.feeds.forEach(function (f) { if (f.id == feed.id) f.fetched_once = false; }); };
      mark(NEWSBLUR.assets.feed_list_subscriptions);
      var key = NEWSBLUR.feed_list_cache.cache_key(NEWSBLUR.Globals.user_id);
      var data = JSON.parse(localStorage.getItem(key)); mark(data); localStorage.setItem(key, JSON.stringify(data));
      return feed.id;
    })()"""
    )
    stale_row = f".NB-feedlist .feed[data-id='{stale_feed}']"

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
    # A blurblog opened before the server answers stays selected once its answer merges in.
    social_id = ctx.evaluate(
        "(() => { var f = NEWSBLUR.assets.social_feeds.first(); if (!f) return null; "
        "NEWSBLUR.reader.open_social_stories(f.id); return f.id; })()"
    )
    if social_id:
        ctx.wait(1500)
        ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
        ctx.wait(900)
    unfetched_early = ctx.evaluate(f"$(\"{stale_row}\").first().hasClass('NB-feed-unfetched')")

    ctx.evaluate(
        "(() => { window.__nb_list_root = document.querySelector('.NB-feedlist').firstElementChild; })()"
    )
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
        "(() => ({same_list: window.__nb_list_root === document.querySelector('.NB-feedlist').firstElementChild, "
        "rows: $('.NB-feedlist .feed:visible').length, player: !!NEWSBLUR.app.media_player.state_restored}))()"
    )
    ctx.check(
        "the server's list merges in without redrawing the feed list",
        after["same_list"] and after["rows"] == rows_before,
        after,
    )
    # A merge that left the rows alone kept the copy's stale styling for the whole session.
    unfetched_after = ctx.evaluate(f"$(\"{stale_row}\").first().hasClass('NB-feed-unfetched')")
    ctx.check(
        "a feed row the server's list changed redraws itself, here no longer unfetched",
        stale_feed and unfetched_early and not unfetched_after,
        {"feed": stale_feed, "early": unfetched_early, "after": unfetched_after},
    )
    if social_id:
        selected = ctx.evaluate(f"!!NEWSBLUR.assets.social_feeds.get('{social_id}').get('selected')")
        ctx.check("a blurblog opened before the server answered stays selected", selected)
    # On / the dashboard rivers load after a cached draw too.
    rivers = ctx.evaluate("$('#NB-splash .NB-module-river .NB-story-title').length")
    ctx.check("the dashboard's rivers load after a cached draw", rivers > 0, rivers)
    ctx.check("the Listen player restores from the server's state", after["player"], after)

    # A reload into a feed showed an empty story list while its stories loaded, and the desktop
    # layout flashed before the phone layout took over.
    ctx.open_feed(feed_id)
    path = ctx.evaluate("location.pathname")
    held_stories = []
    page.route("**/reader/feed/**", lambda route: held_stories.append(route))
    page.goto("https://localhost" + path, wait_until="load")
    ctx.wait(2000)
    loading = ctx.evaluate(
        "(() => { var line = document.querySelector('#story_titles .NB-load-line'); "
        "var r = line && line.getBoundingClientRect(); "
        "return {screen: NEWSBLUR.app.mobile.screen, spinner: !!line && r.height >= 100 && "
        "getComputedStyle(line, '::before').animationName === 'NB-mobile-spin', "
        "booting: document.body.classList.contains('NB-mobile-booting'), "
        "mobile: document.body.classList.contains('NB-mobile')}; })()"
    )
    ctx.shot("reload-into-feed")
    for route in held_stories:
        route.continue_()
    page.unroute("**/reader/feed/**")
    ctx.check(
        "a reload into a feed shows a spinner while its stories load",
        held_stories and loading["screen"] == "titles" and loading["spinner"],
        loading,
    )
    ctx.check(
        "the phone layout is up and the page no longer hidden for boot",
        loading["mobile"] and not loading["booting"],
        loading,
    )

    page.goto("https://localhost/reader/logout", wait_until="load")
    ctx.wait(1000)
    ctx.check("signing out clears the kept feed list", not ctx.evaluate(STORED)["keys"])
    ctx.check_no_page_errors()
