"""
regressions.py: bugs found in code review of the phone layout (PR #2189), each confirmed failing
before its fix. smoke.py runs these too.
"""

FEEDS_SCREEN_X = "(() => { var m = getComputedStyle(document.querySelector('.left-pane')).transform; " \
    "return m === 'none' ? 0 : parseFloat(m.split(',')[4]); })()"
STORY_LISTENERS = "(() => { var s = NEWSBLUR.reader.active_story; " \
    "return (s._events['change:selected'] || []).length + (s._events['change'] || []).length; })()"


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
    ctx.evaluate("(() => { NEWSBLUR.app.mobile.set_screen('titles'); NEWSBLUR.app.mobile.after_screen_change(); })()")
    ctx.wait(1200)
    pager = ctx.evaluate(
        "({story: !!NEWSBLUR.app.mobile.story_pager.story, "
        "views: $('.NB-mobile-story-page .NB-feed-story-content').length})"
    )
    ctx.check("closing mid page turn leaves the pager empty", not pager["story"] and pager["views"] == 0, pager)
    ctx.check("closing mid page turn doesn't select the next story", ctx.state()["story"] == story_before)

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


def run(ctx):
    ctx.login("/")
    check_regressions(ctx, ctx.pick_feed())
    ctx.check_no_page_errors()
