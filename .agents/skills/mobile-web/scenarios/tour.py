"""
tour.py: screenshots of every phone screen, in order, for PRs and design review.
Pass --args dark to run.py for the dark theme (applied in the page only, never saved).
"""


def run(ctx):
    page = ctx.page
    theme = (ctx.args or "light").strip()
    ctx.login("/")
    if theme == "dark":
        ctx.use_dark_theme()
    feed_id = ctx.pick_feed()

    def shot(name):
        ctx.shot(f"{theme}-{name}")

    shot("01-feeds")
    ctx.long_press(ctx.feed_row(feed_id))
    ctx.wait(600)
    shot("02-feed-longpress-menu")
    page.locator(".NB-mobile-sheet-shade").tap(position={"x": 200, "y": 100})
    ctx.wait(400)

    page.locator(".NB-feeds-header-river-dashboard").tap()
    ctx.wait(1000)
    shot("03-dashboard")
    page.locator(".NB-mobile-dashboard-bar .NB-mobile-bar-back").tap()
    ctx.wait(700)

    ctx.open_feed(feed_id)
    ctx.set_layout("list")
    shot("04-story-list")
    ctx.tap_story(2)
    ctx.wait(500)
    shot("05-list-expanded")
    page.locator(".NB-story-titles-header .NB-feedbar-options").first.tap()
    ctx.wait(700)
    shot("06-feed-options-sheet")
    ctx.close_overlays()

    ctx.set_layout("grid")
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = 0; })()")
    shot("07-grid")
    ctx.tap_story(1)
    ctx.wait(300)
    shot("08-story-feed")
    page.locator(".NB-mobile-story-view-option[data-view='text']").tap()
    ctx.wait(2500)
    shot("09-story-text")
    page.locator(".NB-mobile-story-view-option[data-view='feed']").tap()
    ctx.wait(800)
    release = ctx.touch.drag(ctx.viewport["width"] - 60, 600, 150, 605, steps=8)
    ctx.wait(80)
    shot("10-story-swipe-mid")
    release()
    ctx.wait(900)
    page.locator(".NB-mobile-story-options").tap()
    ctx.wait(700)
    shot("11-typography-sheet")
    ctx.close_overlays()
    release = ctx.touch.drag(5, 400, 200, 400, steps=10)
    ctx.wait(80)
    shot("12-edge-swipe-back-mid")
    release()
    ctx.wait(900)
    shot("13-back-to-grid")

    ctx.evaluate("NEWSBLUR.reader.open_preferences_modal()")
    ctx.wait(1800)
    shot("14-preferences-modal")
    ctx.close_overlays()

    page.go_back()
    ctx.wait(800)
    page.locator(".NB-feeds-header-add-site").tap()
    ctx.wait(2500)
    shot("15-add-and-discover")
    ctx.check("the tour reached Add + Discover", ctx.state()["screen"] == "titles", ctx.state())
    ctx.check_no_page_errors()
