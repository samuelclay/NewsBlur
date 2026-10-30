"""
smoke.py: the phone layout end to end on an iPhone-sized screen. Every flow a reader uses:
screens and history, list and grid, the story screen's swipes and toolbar, edge-swipe back,
long-press menus, bottom sheets, pull to refresh, search, modals, then regressions.py.
"""

from regressions import check_regressions


def run(ctx):
    page = ctx.page
    ctx.login("/")
    feed_id = ctx.pick_feed()
    feed_title = ctx.feed_title(feed_id)
    width = ctx.viewport["width"]
    print(f"   testing with feed {feed_id} ({feed_title})")

    state = ctx.state()
    ctx.check(
        "phone layout is active",
        state["active"] and ctx.evaluate("document.body.classList.contains('NB-mobile')"),
    )
    ctx.check("starts on the feed list", state["screen"] == "feeds", state)
    ctx.check("feed list fills the screen", ctx.screen_left(".left-pane") == 0)

    # Long press a feed: its manage menu opens as a bottom sheet and the feed doesn't open.
    ctx.long_press(ctx.feed_row(feed_id))
    ctx.wait(500)
    ctx.check(
        "long press opens the feed menu as a sheet",
        ctx.evaluate(
            "$('.NB-menu-manage-container.NB-mobile-sheet:visible').length == 1 && "
            "document.body.classList.contains('NB-mobile-sheet-open')"
        ),
    )
    ctx.check("long press doesn't open the feed", ctx.state()["screen"] == "feeds")
    page.locator(".NB-mobile-sheet-shade").tap(position={"x": 200, "y": 100})
    ctx.wait(500)
    ctx.check(
        "tapping outside closes the menu",
        ctx.evaluate(
            "!document.body.classList.contains('NB-mobile-sheet-open') && "
            "$('.NB-menu-manage-container:visible').length == 0"
        ),
    )

    # Dashboard is its own screen.
    page.locator(".NB-feeds-header-river-dashboard").tap()
    ctx.wait(700)
    state = ctx.state()
    ctx.check(
        "Dashboard pushes its own screen",
        state["screen"] == "dashboard" and state["entry"]["screen"] == "dashboard",
        state,
    )
    page.locator(".NB-mobile-dashboard-bar .NB-mobile-bar-back").tap()
    ctx.wait(700)
    ctx.check("back from the dashboard returns to the feed list", ctx.state()["screen"] == "feeds")

    # Opening a feed slides in its story list.
    row = ctx.feed_row(feed_id)
    ctx.press_point(row)
    row.tap()
    ctx.wait(150)
    ctx.check(
        "opening a feed animates",
        ctx.evaluate(
            "document.querySelector('.right-pane').classList.contains('NB-mobile-animating') || "
            "document.body.classList.contains('NB-mobile-transitioning')"
        ),
    )
    page.wait_for_function("NEWSBLUR.assets.stories.length > 0", timeout=30000)
    ctx.wait(1500)
    state = ctx.state()
    ctx.check(
        "the feed opens the story list",
        state["screen"] == "titles" and state["entry"]["screen"] == "titles",
        state,
    )
    ctx.check("the story list fills the screen", ctx.screen_left(".right-pane") == 0)
    ctx.check(
        "the nav bar shows the feed's title",
        ctx.evaluate("$('.NB-mobile-titles-bar .NB-mobile-bar-title-text').text()") == feed_title,
    )

    # List layout: compact rows that expand inline.
    ctx.set_layout("list")
    ctx.check(
        "list rows use the compact titles-pane template",
        ctx.evaluate(
            "document.querySelector('#story_titles .NB-story-title').classList.contains('NB-story-title-split') && "
            "document.querySelector('.right-pane').classList.contains('NB-story-pane-west')"
        ),
    )
    ctx.tap_story(2)
    ctx.check(
        "tapping a list row expands the story inline",
        ctx.evaluate(
            "$('#story_titles .NB-story-title-container.NB-selected .NB-story-detail .NB-feed-story-content').length == 1"
        ),
    )
    ctx.check("the list stays on screen", ctx.state()["screen"] == "titles")

    titles = page.locator("#story_titles .NB-story-title")
    ctx.long_press(titles.nth(min(4, titles.count() - 1)))
    ctx.wait(500)
    ctx.check(
        "long press on a story opens its menu",
        ctx.evaluate("$('.NB-menu-manage-container.NB-mobile-sheet:visible .NB-menu-manage').length == 1"),
    )
    page.locator(".NB-mobile-sheet-shade").tap(position={"x": 200, "y": 100})
    ctx.wait(400)

    page.locator(".NB-story-titles-header .NB-feedbar-options").first.tap()
    ctx.wait(600)
    sheet = ctx.evaluate(
        "(() => { var p = document.querySelector('.NB-popover'); if (!p) return null; "
        "var r = p.getBoundingClientRect(); return {bottom: Math.round(r.bottom), width: Math.round(r.width), "
        "height: innerHeight, viewport: innerWidth}; })()"
    )
    ctx.check(
        "feed options open as a bottom sheet",
        sheet and abs(sheet["bottom"] - sheet["height"]) <= 1 and sheet["width"] == sheet["viewport"],
        sheet,
    )
    ctx.close_overlays()

    # Grid layout: cards that push the story screen.
    ctx.set_layout("grid")
    ctx.check(
        "the toggle switches to grid",
        ctx.evaluate(f"NEWSBLUR.assets.view_setting({feed_id}, 'layout')") == "grid",
    )
    ctx.check(
        "the grid is one column on a phone",
        ctx.evaluate(
            "getComputedStyle(document.querySelector('#story_titles > .NB-story-titles')).gridTemplateColumns.split(' ').length"
        )
        == 1,
    )
    ctx.tap_story(1)
    state = ctx.state()
    ctx.check(
        "tapping a card pushes the story screen",
        state["screen"] == "story"
        and state["entry"]["screen"] == "story"
        and state["entry"]["story_hash"] == state["story"],
        state,
    )
    ctx.check("the story screen fills the screen", ctx.screen_left(".NB-mobile-story-screen") == 0)
    ctx.check(
        "the story renders",
        ctx.evaluate("$('.NB-mobile-story-page-current .NB-feed-story-content').length == 1"),
    )
    ctx.check(
        "the stories either side are rendered ahead",
        ctx.evaluate(
            "$('.NB-mobile-story-page-next .NB-feed-story-content').length + "
            "$('.NB-mobile-story-page-previous .NB-feed-story-content').length >= 1"
        ),
    )

    first = ctx.state()["story"]
    ctx.touch.swipe(width - 60, 600, 60, 610, steps=10)
    ctx.wait(800)
    second = ctx.state()["story"]
    ctx.check(
        "swiping left pages to the next story",
        second != first and ctx.state()["entry"]["story_hash"] == second,
        (first, second),
    )
    ctx.touch.swipe(60, 600, width - 60, 610, steps=10)
    ctx.wait(800)
    ctx.check("swiping right pages back", ctx.state()["story"] == first)
    ctx.touch.swipe(200, 700, 200, 300, steps=8)
    ctx.wait(500)
    ctx.check("a vertical swipe scrolls instead of paging", ctx.state()["story"] == first)
    # A tap during momentum scrolling only stops the scroll, as on a real phone.
    ctx.wait(1200)
    page.locator(".NB-mobile-story-next").tap()
    ctx.wait(700)
    ctx.check("the next button pages", ctx.state()["story"] == second)
    page.locator(".NB-mobile-story-previous").tap()
    ctx.wait(700)
    ctx.check("the previous button pages", ctx.state()["story"] == first)

    page.locator(".NB-mobile-story-view-option[data-view='text']").tap()
    ctx.wait(2500)
    ctx.check(
        "Text view renders",
        ctx.evaluate(
            "$('.NB-mobile-story-page-current .NB-text-view-detail, .NB-mobile-story-page-current .NB-feed-story').length >= 1"
        ),
    )
    page.locator(".NB-mobile-story-view-option[data-view='feed']").tap()
    ctx.wait(600)

    if ctx.evaluate("$('.NB-mobile-story-page-current .NB-feed-story-train').length > 0"):
        ctx.evaluate("(() => { $('.NB-mobile-story-page-current .NB-feed-story-train').first().click(); })()")
        ctx.wait(1800)
        modal = ctx.evaluate(
            "(() => { var c = document.querySelector('#simplemodal-container'); if (!c) return null; "
            "var r = c.getBoundingClientRect(); return {width: Math.round(r.width), top: Math.round(r.top)}; })()"
        )
        ctx.check(
            "Train opens a full-screen modal", modal and modal["width"] == width and modal["top"] == 0, modal
        )
        ctx.close_overlays()

    # Edge swipe back: a short one snaps back, a long one returns to the list.
    ctx.touch.swipe(5, 400, 60, 400, steps=6)
    ctx.wait(600)
    state = ctx.state()
    ctx.check(
        "a short edge swipe snaps back", state["screen"] == "story" and not state["transitioning"], state
    )
    ctx.touch.swipe(5, 400, 300, 400, steps=10)
    ctx.wait(900)
    state = ctx.state()
    ctx.check(
        "an edge swipe goes back to the list",
        state["screen"] == "titles" and state["entry"]["screen"] == "titles",
        state,
    )

    page.go_forward()
    ctx.wait(1000)
    ctx.check(
        "browser forward reopens the story",
        ctx.state()["screen"] == "story" and ctx.state()["story"] == first,
        ctx.state(),
    )
    page.go_back()
    ctx.wait(900)
    ctx.check("browser back returns to the list", ctx.state()["screen"] == "titles")

    # Search adds history entries on the same screen; the nav bar's back skips them.
    ctx.set_layout("list")
    term = ctx.evaluate(
        "(() => { var words = NEWSBLUR.assets.stories.map(function (s) { return s.get('story_title'); })"
        ".join(' ').match(/[A-Za-z]{5,}/g) || []; return words[0] || 'news'; })()"
    )
    page.locator(".NB-story-titles-header .NB-story-title-search-input").first.tap()
    page.keyboard.type(term)
    page.keyboard.press("Enter")
    ctx.wait(2500)
    ctx.check(
        "searching keeps the feed's title",
        ctx.evaluate("$('.NB-mobile-titles-bar .NB-mobile-bar-title-text').text()") == feed_title,
    )
    page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(1200)
    state = ctx.state()
    ctx.check(
        "back from a search lands on the feed list",
        state["screen"] == "feeds" and state["path"] == "/",
        state,
    )

    ctx.evaluate(
        "(() => { window.__nb_refreshes = 0; var refresh = NEWSBLUR.reader.force_feeds_refresh; "
        "NEWSBLUR.reader.force_feeds_refresh = function () { window.__nb_refreshes++; "
        "return refresh.apply(this, arguments); }; })()"
    )
    # Pull to refresh only starts at the top of the list, and press_point scrolled it earlier.
    ctx.evaluate("(() => { document.querySelector('.left-center-content').scrollTop = 0; })()")
    ctx.wait(300)
    ctx.touch.swipe(200, 200, 200, 420, steps=14, step_ms=20)
    ctx.wait(2500)
    ctx.check("pulling down the feed list refreshes it", ctx.evaluate("window.__nb_refreshes") == 1)

    ctx.evaluate("NEWSBLUR.reader.open_preferences_modal()")
    ctx.wait(1500)
    ctx.check(
        "modals have a close button",
        ctx.evaluate("$('#simplemodal-container a.modalCloseImg:visible').length == 1"),
    )
    page.locator("#simplemodal-container a.modalCloseImg").tap()
    ctx.wait(800)
    ctx.check(
        "the close button closes the modal",
        ctx.evaluate("document.querySelector('#simplemodal-container') == null"),
    )

    check_regressions(ctx, feed_id)
    ctx.check_no_page_errors()
