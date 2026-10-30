"""
regressions.py: bugs found in code review of the phone layout (PR #2189), each confirmed failing
before its fix. smoke.py runs these too.
"""

FEEDS_SCREEN_X = (
    "(() => { var m = getComputedStyle(document.querySelector('.left-pane')).transform; "
    "return m === 'none' ? 0 : parseFloat(m.split(',')[4]); })()"
)
STORY_LISTENERS = (
    "(() => { var s = NEWSBLUR.reader.active_story; "
    "return (s._events['change:selected'] || []).length + (s._events['change'] || []).length; })()"
)


def check_regressions(ctx, feed_id):
    """Expects to start on the feeds screen."""
    # The header back button once animated as an edge swipe, sliding the feeds screen in from the
    # trailing edge instead of from behind on the leading edge.
    ctx.open_feed(feed_id)
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(90)
    x = ctx.evaluate(FEEDS_SCREEN_X)
    rtl = ctx.evaluate("document.documentElement.dir === 'rtl'")
    ctx.check("header back slides the feed list in from the leading edge", x > 0 if rtl else x < 0, x)
    ctx.wait(900)

    # Text-mode story pages leaked their StoryDetailView, which kept its bindings on the story.
    ctx.open_feed(feed_id)
    ctx.set_layout("grid")
    ctx.tap_story(1)
    before = ctx.evaluate(STORY_LISTENERS)
    for _ in range(3):
        ctx.page.locator(".NB-mobile-story-view-option[data-view='text']").tap()
        ctx.wait(900)
        ctx.page.locator(".NB-mobile-story-view-option[data-view='feed']").tap()
        ctx.wait(500)
    after = ctx.evaluate(STORY_LISTENERS)
    ctx.check("switching Feed and Text doesn't leak story listeners", after <= before, (before, after))

    # Closing the story screen mid page turn (Safari's own swipe-back is instant) used to finish
    # the turn anyway: it repopulated the pager and selected, so marked read, the next story.
    story_before = ctx.state()["story"]
    ctx.page.locator(".NB-mobile-story-next").tap()
    ctx.wait(60)
    ctx.evaluate("(() => { NEWSBLUR.app.mobile.story_pager.close(); })()")
    ctx.wait(1200)
    pager = ctx.evaluate(
        "({story: !!NEWSBLUR.app.mobile.story_pager.story, "
        "views: $('.NB-mobile-story-page .NB-feed-story-content').length})"
    )
    ctx.check(
        "closing mid page turn leaves the pager empty", not pager["story"] and pager["views"] == 0, pager
    )
    ctx.check("closing mid page turn doesn't select the next story", ctx.state()["story"] == story_before)
    # Leave the story screen through history, the way a pop really happens.
    ctx.page.go_back()
    ctx.wait(1000)

    # A screen change during an edge swipe (reader_opened, feed_reset) used to leave the drag's
    # classes behind, and NB-mobile-transitioning makes every screen ignore taps.
    release = ctx.touch.drag(5, 400, 160, 400, steps=8)
    ctx.wait(60)
    ctx.evaluate("(() => { NEWSBLUR.app.mobile.set_screen(NEWSBLUR.app.mobile.screen); })()")
    release()
    ctx.wait(900)
    stuck = ctx.evaluate(
        "({transitioning: document.body.classList.contains('NB-mobile-transitioning'), "
        "dragging: $('.NB-mobile-dragging').length, "
        "inline: $('.NB-mobile-screen').filter(function () { return this.style.transform; }).length})"
    )
    ctx.check(
        "a screen change mid edge-swipe clears the drag",
        not stuck["transitioning"] and not stuck["dragging"] and not stuck["inline"],
        stuck,
    )
    ctx.set_layout("list")
    check_story_iframe_sandbox(ctx, feed_id)
    check_discovery_back(ctx)


def check_story_iframe_sandbox(ctx, feed_id):
    """The phone Story view's iframe once had allow-same-origin. /rss_feeds/original_story serves
    the publisher's page from NewsBlur's origin, so its scripts could act as the signed-in reader.
    Expects to be on the story list."""
    ctx.set_layout("grid")
    ctx.tap_story(1)
    # The test feed may block framing; the iframe's sandbox is what matters, so allow it here.
    ctx.evaluate(
        f"(() => {{ NEWSBLUR.assets.get_feed({feed_id}).set('disabled_page', false, {{silent: true}}); "
        "NEWSBLUR.app.mobile.story_pager.update_chrome(); })()"
    )
    ctx.page.locator(".NB-mobile-story-view-option[data-view='story']").tap()
    ctx.wait(1500)
    sandbox = ctx.evaluate(
        "(() => { var f = document.querySelector('.NB-mobile-story-page-current iframe'); "
        "return f ? {sandbox: f.getAttribute('sandbox'), reachable: !!f.contentDocument} : null; })()"
    )
    ctx.check(
        "the Story view iframe can't reach the reader's origin",
        sandbox and "allow-same-origin" not in sandbox["sandbox"] and not sandbox["reachable"],
        sandbox,
    )
    ctx.page.locator(".NB-mobile-story-view-option[data-view='feed']").tap()
    ctx.wait(500)
    ctx.page.locator(".NB-mobile-story-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)
    ctx.set_layout("list")


def check_discovery_back(ctx):
    """Add + Discover's tab entries were tagged as the feed list, so browser Back between two tabs
    hid discovery and showed the feeds. Expects to be on the story list."""
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)
    ctx.page.locator(".NB-feeds-header-add-site").tap()
    ctx.wait(2500)
    # A phone shows only the current tab; the rest live under More (add_site_view.js). Visit two
    # other tabs so Back crosses an entry written by a tab change.
    paths = [ctx.evaluate("location.pathname")]
    tags = []
    for index in (1, 2):
        ctx.page.locator(".NB-add-site-tabs-overflow-button").tap()
        ctx.wait(500)
        ctx.page.locator(".NB-add-site-tabs-overflow-item >> visible=true").nth(index).tap()
        ctx.wait(1200)
        paths.append(ctx.evaluate("location.pathname"))
        tags.append(ctx.state()["entry"]["screen"])
    ctx.check("discovery tabs each write their own history entry", len(set(paths)) == 3, paths)
    ctx.check("discovery tab entries belong to the story list screen", tags == ["titles", "titles"], tags)
    ctx.page.go_back()
    ctx.wait(1200)
    state = ctx.state()
    ctx.check(
        "browser Back between discovery tabs stays in Add + Discover",
        state["screen"] == "titles" and ctx.evaluate("!!NEWSBLUR.reader.flags.add_site_view"),
        state,
    )
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(1200)


def run(ctx):
    ctx.login("/")
    check_regressions(ctx, ctx.pick_feed())
    ctx.check_no_page_errors()
