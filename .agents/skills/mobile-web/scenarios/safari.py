"""
safari.py: iOS Safari's browser mode, where Safari swipes back and forward from the screen's
edges itself. navigator.standalone is false there (true for a home screen web app, undefined in
the Chromium the other scenarios run), so this scenario sets it before the reader loads.

Safari's toolbar and the status bar also take SAFARI_CHROME pixels of the screen that the page
doesn't get, so the screen is made that much taller than the window. The feed list and story list
are laid out in the page, which Safari draws under its toolbar by itself, and the fixed screens
have to reach under it (mobile.css Page scrolling and Under Safari's toolbar).
"""

SAFARI_CHROME = 160

ANIMATING = (
    "document.querySelectorAll('.NB-mobile-animating, .NB-mobile-dragging').length > 0 || "
    "document.body.classList.contains('NB-mobile-transitioning')"
)


def run(ctx):
    page = ctx.page
    page.add_init_script("Object.defineProperty(navigator, 'standalone', {value: false, configurable: true})")
    page.add_init_script(
        "Object.defineProperty(screen, 'height', {get: () => window.innerHeight + %d, configurable: true})"
        % SAFARI_CHROME
    )
    ctx.login("/")
    ctx.check("the page sees iOS Safari's browser mode", ctx.evaluate("navigator.standalone === false"))
    feed_id = ctx.pick_feed()
    ctx.open_feed(feed_id)

    # Safari runs its own edge swipe here; the layout's used to run at the same time.
    release = ctx.touch.drag(5, 400, 220, 400, steps=10)
    ctx.wait(60)
    dragging = ctx.evaluate(
        "({dragging: $('.NB-mobile-dragging').length, "
        "moved: !!document.querySelector('.right-pane').style.transform})"
    )
    release()
    ctx.wait(800)
    ctx.check(
        "an edge drag leaves the swipe to Safari",
        not dragging["dragging"] and not dragging["moved"] and ctx.state()["screen"] == "titles",
        dragging,
    )

    # Safari's swipe cancels the page's touch, then goes back once the finger lifts. Its own
    # snapshot already slid, so the screens switch without a second slide.
    ctx.touch._send("touchStart", 5, 400)
    ctx.touch._send("touchCancel")
    page.go_back()
    ctx.wait(30)
    slid = ctx.evaluate(ANIMATING)
    ctx.wait(800)
    ctx.check(
        "Back after Safari's swipe switches screens without sliding again",
        not slid and ctx.state()["screen"] == "feeds",
        {"slid": slid, "state": ctx.state()},
    )

    # A slow Safari swipe can take several seconds before it goes back, and still doesn't slide
    # twice.
    window_ms = ctx.evaluate("NEWSBLUR.app.mobile.BROWSER_SWIPE_MS")
    ctx.open_feed(feed_id)
    ctx.touch._send("touchStart", 5, 400)
    ctx.touch._send("touchCancel")
    ctx.wait(5000)
    page.go_back()
    ctx.wait(30)
    slid = ctx.evaluate(ANIMATING)
    ctx.wait(800)
    ctx.check(
        "a slow Safari swipe-back doesn't slide twice",
        not slid and ctx.state()["screen"] == "feeds",
        {"slid": slid, "state": ctx.state()},
    )

    # A Safari swipe let go of before it went anywhere cancels the touch with no popstate. Once
    # BROWSER_SWIPE_MS has passed, a Back from Safari's toolbar, which sends the page no touches,
    # slides again.
    ctx.open_feed(feed_id)
    ctx.touch._send("touchStart", 5, 400)
    ctx.touch._send("touchCancel")
    ctx.wait(window_ms + 500)
    page.go_back()
    ctx.wait(30)
    slid = ctx.evaluate(ANIMATING)
    ctx.wait(800)
    ctx.check(
        "a toolbar Back after an abandoned Safari swipe still slides",
        slid and ctx.state()["screen"] == "feeds",
        {"slid": slid, "state": ctx.state()},
    )

    # The nav bar's back button sits at the edge too, and a tap there still slides.
    ctx.open_feed(feed_id)
    page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap(position={"x": 8, "y": 20})
    ctx.wait(60)
    slid = ctx.evaluate(ANIMATING)
    ctx.wait(800)
    ctx.check(
        "the back button at the edge still slides",
        slid and ctx.state()["screen"] == "feeds",
        {"slid": slid, "state": ctx.state()},
    )
    # Only the edges are Safari's. A swipe from the middle of the story list is the layout's own.
    ctx.open_feed(feed_id)
    ctx.touch.swipe(120, 420, ctx.viewport["width"] - 20, 425, steps=12)
    ctx.wait(900)
    ctx.check(
        "a swipe from the middle of the story list still goes back in Safari",
        ctx.state()["screen"] == "feeds",
    )
    check_under_toolbar(ctx, feed_id)
    ctx.check_no_page_errors()


def check_story_edge_swipe(ctx):
    """Safari's own swipe back from a story slid in its picture of the story list from before any
    stories were paged through. On the story screen the layout takes the back-edge swipe itself,
    over the live list, and gives the touch's tap and scroll back. Expects the story screen, and
    leaves the story list."""
    ctx.evaluate(
        "(() => { document.querySelector('.NB-mobile-story-page-current').scrollTop = 0; window.__nb_edge = {clicks: 0}; "
        "document.addEventListener('touchstart', function (e) { window.__nb_edge.prevented = e.defaultPrevented; }); "
        "document.querySelector('.NB-mobile-story-pager').addEventListener('click', function () { window.__nb_edge.clicks += 1; }); })()"
    )
    ctx.wait(300)
    ctx.touch.swipe(5, 600, 6, 300, steps=10)
    ctx.wait(500)
    scrolled = ctx.evaluate("Math.round(document.querySelector('.NB-mobile-story-page-current').scrollTop)")
    ctx.touch._send("touchStart", 5, 400)
    ctx.touch._send("touchEnd")
    ctx.wait(300)
    edge = ctx.evaluate("window.__nb_edge")
    ctx.check(
        "a touch at a story's back edge is taken from Safari, and still scrolls and taps",
        edge["prevented"] and scrolled > 200 and edge["clicks"] == 1 and ctx.state()["screen"] == "story",
        (edge, scrolled, ctx.state()),
    )
    release = ctx.touch.drag(5, 400, 240, 404, steps=10)
    ctx.wait(60)
    dragging = ctx.evaluate("$('.NB-mobile-story-screen.NB-mobile-dragging').length")
    release()
    ctx.wait(1000)
    ctx.check(
        "a swipe from a story's back edge slides it away over the live story list",
        dragging == 1 and ctx.state()["screen"] == "titles",
        (dragging, ctx.state()),
    )


# Where a screen, the bar of controls under its nav bar and the end of its list sit, as page
# coordinates, with the list scrolled to its end.
GEOMETRY = """((screen, nav, controls, list) => {
  var rect = function (selector) {
    var el = document.querySelector(selector);
    return el ? el.getBoundingClientRect() : null;
  };
  var scroller = document.querySelector(list);
  scroller.scrollTop = scroller.scrollHeight;
  var rows = Array.prototype.filter.call(scroller.querySelectorAll('.feed, .NB-story-title, .NB-feeds-header, p, li'),
    function (el) { return el.offsetParent && el.getBoundingClientRect().height; });
  var last = rows.length ? rows[rows.length - 1].getBoundingClientRect().bottom : null;
  return {window: window.innerHeight, screen: Math.round(rect(screen).bottom), nav_top: Math.round(rect(nav).top),
          nav_bottom: Math.round(rect(nav).bottom), controls_top: Math.round(rect(controls).top),
          under_chrome: document.body.classList.contains('NB-mobile-under-chrome'),
          page_scroll: document.body.classList.contains('NB-mobile-page-scroll'),
          page_y: Math.round(window.scrollY), last_row: last === null ? null : Math.round(last)};
})"""


def check_under_toolbar(ctx, feed_id):
    """The feed list and story list are laid out in the page at rest, which Safari draws under its
    toolbar and scrolls itself, so its toolbar shrinks (mobile.css Page scrolling). Their bars of
    controls stay stuck under the nav bar. The story screen and anything covering a screen are
    fixed, so they reach SAFARI_CHROME below the window to run under the toolbar."""
    page = ctx.page
    feeds = ctx.evaluate(
        GEOMETRY + "('.left-pane', '.left-north', '.left-south', '.left-center-content')"
    )
    ctx.shot("under-toolbar-feeds")
    ctx.check(
        "the feed list is laid out in the page, which scrolls to its last row under the stuck bars",
        feeds["page_scroll"]
        and not feeds["under_chrome"]
        and feeds["page_y"] > 0
        and feeds["nav_top"] == 0
        and feeds["controls_top"] == feeds["nav_bottom"]
        and feeds["last_row"] <= feeds["window"],
        feeds,
    )

    ctx.open_feed(feed_id)
    ctx.set_layout("list")
    titles = ctx.evaluate(
        GEOMETRY + "('.right-pane', '.NB-mobile-titles-bar', '.right-pane > .content-north', '#story_titles')"
    )
    ctx.shot("under-toolbar-titles")
    ctx.check(
        "the story list is laid out in the page, which scrolls under the stuck nav bar and pills",
        titles["page_scroll"]
        and not titles["under_chrome"]
        and titles["page_y"] > 0
        and titles["nav_top"] == 0
        and titles["controls_top"] == titles["nav_bottom"],
        titles,
    )

    ctx.set_layout("grid")
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = 0; })()")
    ctx.tap_story(1)
    ctx.wait(1500)
    story = ctx.evaluate(
        GEOMETRY
        + "('.NB-mobile-story-screen', '.NB-mobile-story-bar', '.NB-mobile-story-toolbar', '.NB-mobile-story-page-current')"
    )
    ctx.shot("under-toolbar-story")
    ctx.check(
        "an open story is laid out in the page, which scrolls its last row clear of the window's end",
        story["page_scroll"]
        and not story["under_chrome"]
        and story["nav_top"] == 0
        and story["controls_top"] == story["nav_bottom"]
        and story["last_row"] <= story["window"],
        story,
    )
    check_story_edge_swipe(ctx)

    # A full-screen modal covers the part under the toolbar too, instead of leaving the screen
    # beneath showing there.
    ctx.evaluate("NEWSBLUR.reader.open_preferences_modal()")
    page.wait_for_selector("#simplemodal-container .NB-modal", timeout=15000)
    ctx.wait(600)
    ctx.check(
        "a screen under a modal is fixed, and reaches under Safari's toolbar",
        ctx.evaluate(
            "document.body.classList.contains('NB-mobile-under-chrome') && "
            "getComputedStyle(document.body).getPropertyValue('--nb-mobile-chrome-bottom').trim()"
        )
        == f"{SAFARI_CHROME}px",
    )
    modal_bottom = ctx.evaluate("document.querySelector('#simplemodal-container').getBoundingClientRect().bottom")
    ctx.check(
        "a modal reaches under the toolbar",
        modal_bottom == ctx.evaluate("window.innerHeight") + SAFARI_CHROME,
        modal_bottom,
    )
    # Something scrolling the taller fixed page itself, here a script, is put back.
    ctx.evaluate("window.scrollTo(0, 80)")
    ctx.wait(200)
    ctx.check("the fixed page scrolls back to the top", ctx.evaluate("window.scrollY") == 0)
    ctx.close_overlays()

    # Add + Discover scrolls in its own tab panes, which kept their desktop padding and left the
    # last results under the toolbar.
    page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)
    page.locator(".NB-feeds-header-add-site").tap()
    ctx.wait(2500)
    discover = ctx.evaluate(
        """(() => {
      var pane = document.querySelector('.NB-add-site-tab-pane.NB-active');
      pane.scrollTop = pane.scrollHeight;
      var bottoms = Array.prototype.filter.call(pane.querySelectorAll('*'), function (el) {
        return el.offsetParent && el.getBoundingClientRect().height;
      }).map(function (el) { return el.getBoundingClientRect().bottom; });
      return {window: innerHeight, pane: Math.round(pane.getBoundingClientRect().bottom),
              last: Math.round(Math.max.apply(null, bottoms))};
    })()"""
    )
    ctx.shot("under-toolbar-discover")
    ctx.check(
        "Add + Discover reaches under the toolbar and scrolls its last result clear of it",
        discover["pane"] == discover["window"] + SAFARI_CHROME and discover["last"] <= discover["window"],
        discover,
    )
    page.go_back()
    ctx.wait(900)
