"""
page_scroll.py: a phone browser shrinks its own toolbar only when the page itself scrolls, so
the feed list, the story list and an open story scroll the page while they are at rest
(mobile.css Page scrolling, mobile_layout_view.js Page scroll). A slide, a swipe between stories,
a sheet or a modal puts the screen back in the fixed layout, scrolled to the same place.

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
    story_nav: box('.NB-mobile-story-bar'), story_toolbar: box('.NB-mobile-story-toolbar'),
    story_top: Math.round(document.querySelector('.NB-mobile-story-page-current').scrollTop),
    story_bottom: Math.round(document.querySelector('.NB-mobile-story-page-current').getBoundingClientRect().bottom),
    story: NEWSBLUR.app.mobile.story_pager.story_hash(),
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

    feed_id = ctx.pick_feed()
    # page_scroll.py tests opening a list without auto-selecting its first unread story; prefs_guard.py restores these settings.
    ctx.evaluate(
        "(() => { NEWSBLUR.assets.preference('open_feed_action', 0); "
        "NEWSBLUR.assets.save_phone_layout(%d, 'list'); })()" % feed_id
    )
    ctx.open_feed(feed_id)
    opened = ctx.evaluate(STATE)
    ctx.check(
        "a story list opens at its top, laid out in the page",
        opened["page"] and opened["page_screen"] == "titles" and opened["page_y"] == 0,
        opened,
    )
    ctx.set_layout("list")
    state = ctx.evaluate(STATE)
    # Tapping the feed's row scrolled it into view, so this is where the feed list was left.
    feeds_top = state["feeds_top"]
    loaded = state["stories"]
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
    check_scroll_regressions(ctx)

    # page_scroll.py spies on a dynamic call: resize_window itself was captured when its handler registered.
    ctx.wait(1200)
    ctx.evaluate(
        "(() => { window.__nb_resizes = 0; "
        "window.__nb_resize_view = NEWSBLUR.reader.switch_taskbar_view; "
        "NEWSBLUR.reader.switch_taskbar_view = function (view, options) { "
        "if (options && options.resize) window.__nb_resizes += 1; "
        "return window.__nb_resize_view.apply(this, arguments); }; })()"
    )
    page.set_viewport_size({"width": width, "height": ctx.viewport["height"] + 80})
    ctx.wait(1400)
    taller = ctx.evaluate("window.__nb_resizes")
    page.set_viewport_size({"width": width, "height": ctx.viewport["height"]})
    ctx.wait(1400)
    state = ctx.evaluate(STATE)
    ctx.check(
        "a window that only gets taller or shorter, as when the toolbar shrinks, re-lays out nothing",
        taller == 0 and ctx.evaluate("window.__nb_resizes") == 0 and abs(state["page_y"] - titles_top) <= 2,
        (taller, state),
    )
    # page_scroll.py proves the counter reaches the registered handler, rather than a replaced function it never calls.
    page.set_viewport_size({"width": width - 20, "height": ctx.viewport["height"]})
    ctx.wait(1400)
    ctx.check("a width change reaches the reader resize handler", ctx.evaluate("window.__nb_resizes") > 0)
    page.set_viewport_size({"width": width, "height": ctx.viewport["height"]})
    ctx.wait(1400)
    ctx.evaluate(
        "(() => { NEWSBLUR.reader.switch_taskbar_view = window.__nb_resize_view; "
        "delete window.__nb_resize_view; })()"
    )
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = %d; })()" % titles_top)
    ctx.wait(500)

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

    check_story_screen(ctx)
    titles_top = ctx.evaluate(STATE)["page_y"]

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


def check_scroll_regressions(ctx):
    """page_scroll.py exercises content-sized lists without depending on the fixture feed's article lengths."""
    result = ctx.evaluate("""(() => {
      var mobile = NEWSBLUR.app.mobile, titles = NEWSBLUR.app.story_titles;
      var before = window.scrollY;
      mobile.show_screen('dashboard', {animate: false});
      mobile.show_screen('titles', {animate: false});
      var after = window.scrollY;
      var had_end = !!titles.$('.NB-end-line').length;
      titles.show_no_more_stories();
      var padding = parseFloat(titles.$('.NB-end-line').css('paddingBottom'));
      if (!had_end) titles.$('.NB-end-line').remove();
      return {before: before, after: after, padding: padding, viewport: titles.viewport_height()};
    })()""")
    ctx.check("immediate screen changes preserve a scrolled story list", abs(result["after"] - result["before"]) <= 2, result)
    ctx.check("the final story spacer fits the visible viewport", 20 <= result["padding"] <= result["viewport"], result)


def check_story_screen(ctx):
    """An open story scrolled inside the story screen, so Safari's toolbar stayed up over it and
    the story stopped short of the bottom of the phone. The page now scrolls in its place, and a
    swipe to the next story lines the stories up in the fixed layout first. Expects the story
    list, and leaves it there."""
    page = ctx.page
    width = ctx.viewport["width"]
    ctx.set_layout("grid")
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = 0; })()")
    ctx.wait(300)
    ctx.tap_story(1)
    ctx.wait(800)
    # page_scroll.py gives geometry fixtures explicit lengths: the busiest feed may contain only short photos.
    # The longer neighbor must not stretch the parked first page and clamp away its saved offset.
    ctx.evaluate(
        "(() => { var pages = NEWSBLUR.app.mobile.story_pager.pages; "
        "pages.current.$el[0].firstElementChild.style.minHeight = '1800px'; "
        "pages.next.$el[0].firstElementChild.style.minHeight = "
        "(pages.current.$el[0].firstElementChild.offsetHeight + 1200) + 'px'; })()"
    )
    state = ctx.evaluate(STATE)
    first_story = state["story"]
    ctx.check(
        "an open story is laid out in the page, from its top",
        state["page"] and state["page_screen"] == "story" and state["page_y"] == 0,
        state,
    )
    ctx.touch.swipe(width / 2, 650, width / 2, 250, steps=10)
    ctx.wait(1200)
    state = ctx.evaluate(STATE)
    story_top = state["page_y"]
    ctx.check(
        "swiping an open story scrolls the page, with its nav bar and toolbar stuck to the top",
        story_top > 100
        and state["story_top"] == story_top
        and state["story_nav"]["top"] == 0
        and state["story_toolbar"]["top"] == state["story_nav"]["bottom"],
        state,
    )
    ctx.evaluate("(() => { var p = document.querySelector('.NB-mobile-story-page-current'); p.scrollTop = p.scrollHeight; })()")
    ctx.wait(500)
    state = ctx.evaluate(STATE)
    ctx.check(
        "an open story ends above the bottom of the window, with room beneath its last line",
        state["story_bottom"] <= state["window_height"] and state["page_height"] > state["window_height"],
        state,
    )
    ctx.shot("03-story-end-long-content-fixture")
    ctx.evaluate("(() => { document.querySelector('.NB-mobile-story-page-current').scrollTop = %d; })()" % story_top)
    ctx.wait(300)

    ctx.touch.swipe(width - 60, 500, 60, 505, steps=10)
    ctx.wait(1200)
    state = ctx.evaluate(STATE)
    ctx.check(
        "a swipe to the next story turns the page and gives the new story to the page at its top",
        state["story"] != first_story and state["page"] and state["page_screen"] == "story" and state["page_y"] == 0,
        (first_story, state),
    )
    ctx.touch.swipe(60, 500, width - 60, 505, steps=10)
    ctx.wait(1200)
    state = ctx.evaluate(STATE)
    ctx.check(
        "swiping back returns to the first story where it was left",
        state["story"] == first_story and state["page"] and abs(state["page_y"] - story_top) <= 2,
        (first_story, story_top, state),
    )
    page.locator(".NB-mobile-story-bar .NB-mobile-bar-back").tap()
    ctx.wait(1300)
    state = ctx.evaluate(STATE)
    ctx.check("back from a story returns the story list to the page", state["page_screen"] == "titles", state)
    check_back_lands_on_story(ctx)
    ctx.set_layout("list")


# Where the story being read sits in the list: how far its row is under the bar of pills, and
# whether the stories before it show as read.
PLACE = """(() => {
  var story = NEWSBLUR.reader.active_story;
  var bar = document.querySelector('.right-pane > .content-north').getBoundingClientRect().bottom;
  var row = story.story_title_view.$el[0].getBoundingClientRect();
  var index = NEWSBLUR.assets.stories.indexOf(story);
  return {screen: NEWSBLUR.app.mobile.screen, index: index, row_offset: Math.round(row.top - bar),
    page_y: Math.round(window.scrollY), restoration: window.history.scrollRestoration,
    unread_before: NEWSBLUR.assets.stories.first(index).filter(function (s) { return !s.get('read_status'); }).length};
})()"""


def check_back_lands_on_story(ctx):
    """After paging several stories ahead on the story screen, going back with the browser showed
    the story list where it was when the first story was opened, then moved it to the story being
    read: the browser had put the page back where that history entry was left. Expects the story
    list in a grid."""
    page = ctx.page
    width = ctx.viewport["width"]
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = 0; })()")
    ctx.wait(300)
    ctx.tap_story(0)
    for _ in range(6):
        ctx.touch.swipe(width - 60, 600, 60, 610, steps=10)
        ctx.wait(900)
    # The browser's own back, as Safari's edge swipe is: the history moves and nothing slides.
    page.evaluate("window.history.back()")
    ctx.wait(60)
    first = ctx.evaluate(PLACE)
    ctx.wait(900)
    settled = ctx.evaluate(PLACE)
    ctx.check(
        "back from stories paged ahead shows the list already on the story being read",
        first["screen"] == "titles"
        and first["index"] >= 5
        and first["restoration"] == "manual"
        and abs(first["row_offset"]) <= 2
        and abs(settled["row_offset"]) <= 2
        and not first["unread_before"],
        (first, settled),
    )
