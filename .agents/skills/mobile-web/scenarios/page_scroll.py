"""
page_scroll.py: a phone browser shrinks its own toolbar only when the page itself scrolls, so
the feed list and the story list scroll the page while they are at rest (mobile.css Page
scrolling, mobile_layout_view.js Page scroll). A slide, a sheet or a modal puts the screen back in
the fixed layout with the list at the same place.

Emulated Chromium has no toolbar to shrink, so this checks what makes Safari shrink its own: the
page, not the list, is what a swipe scrolls.
"""

STATE = """(() => {
  var titles = document.querySelector('#story_titles'), feeds = document.querySelector('.left-center-content');
  var box = function (selector) {
    var r = document.querySelector(selector).getBoundingClientRect();
    return {top: Math.round(r.top), bottom: Math.round(r.bottom)};
  };
  return {
    page: document.body.classList.contains('NB-mobile-page-scroll'),
    page_screen: NEWSBLUR.app.mobile.page_scroll_screen,
    page_y: Math.round(window.scrollY),
    page_height: document.documentElement.scrollHeight,
    window_height: window.innerHeight,
    titles_top: Math.round(titles.scrollTop),
    feeds_top: Math.round(feeds.scrollTop),
    nav: box('.NB-mobile-titles-bar'), pills: box('.right-pane > .content-north'),
    header: box('.left-north'), taskbar: box('.left-south'),
    stories: NEWSBLUR.assets.stories.length
  };
})()"""


def run(ctx):
    page = ctx.page
    width = ctx.viewport["width"]
    ctx.login("/")

    state = ctx.evaluate(STATE)
    ctx.check(
        "the feed list at rest is laid out in the page, which is taller than the window",
        state["page"] and state["page_screen"] == "feeds" and state["page_height"] > state["window_height"],
        state,
    )
    ctx.touch.swipe(width / 2, 600, width / 2, 200, steps=10)
    ctx.wait(1200)
    state = ctx.evaluate(STATE)
    ctx.check(
        "a swipe on the feed list scrolls the page, with the header and taskbar stuck to the top",
        state["page_y"] > 100
        and state["feeds_top"] == state["page_y"]
        and state["header"]["top"] == 0
        and state["taskbar"]["top"] == state["header"]["bottom"],
        state,
    )
    ctx.shot("01-feeds-scrolled")

    ctx.open_feed(ctx.pick_feed())
    ctx.set_layout("list")
    state = ctx.evaluate(STATE)
    # Tapping the feed's row scrolled it into view, so this is where the feed list was left.
    feeds_top = state["feeds_top"]
    loaded = state["stories"]
    ctx.check(
        "a story list opens at its top, laid out in the page",
        state["page"] and state["page_screen"] == "titles" and state["page_y"] == 0,
        state,
    )
    for _ in range(6):
        ctx.touch.swipe(width / 2, 650, width / 2, 150, steps=10)
        ctx.wait(700)
    ctx.wait(1500)
    state = ctx.evaluate(STATE)
    titles_top = state["page_y"]
    ctx.check(
        "swiping the story list scrolls the page, with the nav bar and pills stuck to the top",
        titles_top > 600
        and state["titles_top"] == titles_top
        and state["nav"]["top"] == 0
        and state["pills"]["top"] == state["nav"]["bottom"],
        state,
    )
    ctx.check("scrolling the page loads the next page of stories", state["stories"] > loaded, (loaded, state))
    ctx.shot("02-titles-scrolled")

    # Safari's toolbar shrinking makes the window taller mid-scroll. The reader re-laid out every
    # pane for it, which stuttered the scroll.
    ctx.evaluate(
        "(() => { window.__nb_resizes = 0; var resize = NEWSBLUR.reader.resize_window; "
        "NEWSBLUR.reader.resize_window = function () { window.__nb_resizes += 1; return resize.apply(this, arguments); }; })()"
    )
    page.set_viewport_size({"width": width, "height": ctx.viewport["height"] + 80})
    ctx.wait(900)
    taller = ctx.evaluate("window.__nb_resizes")
    page.set_viewport_size({"width": width, "height": ctx.viewport["height"]})
    ctx.wait(900)
    state = ctx.evaluate(STATE)
    ctx.check(
        "a window that only gets taller or shorter, as when the toolbar shrinks, re-lays out nothing",
        taller == 0 and ctx.evaluate("window.__nb_resizes") == 0 and abs(state["page_y"] - titles_top) <= 2,
        (taller, state),
    )

    page.locator(".NB-mobile-titles-bar .NB-mobile-mark-read").tap()
    ctx.wait(700)
    state = ctx.evaluate(STATE)
    ctx.check(
        "a sheet holds the list still in the fixed layout, at the same place",
        not state["page"] and state["page_y"] == 0 and abs(state["titles_top"] - titles_top) <= 2,
        state,
    )
    ctx.close_overlays()
    state = ctx.evaluate(STATE)
    ctx.check(
        "closing the sheet gives the list back to the page, at the same place",
        state["page"] and abs(state["page_y"] - titles_top) <= 2,
        state,
    )

    page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(250)
    state = ctx.evaluate(STATE)
    ctx.check(
        "a slide moves both screens in the fixed layout, each list where it was",
        not state["page"]
        and state["page_y"] == 0
        and abs(state["titles_top"] - titles_top) <= 2
        and abs(state["feeds_top"] - feeds_top) <= 2,
        state,
    )
    ctx.wait(1200)
    state = ctx.evaluate(STATE)
    ctx.check(
        "back on the feed list, the page is where the list was left",
        state["page"] and state["page_screen"] == "feeds" and abs(state["page_y"] - feeds_top) <= 2,
        state,
    )
    ctx.check_no_page_errors()
