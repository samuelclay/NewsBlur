"""
safari.py: iOS Safari's browser mode, where Safari swipes back and forward from the screen's
edges itself. navigator.standalone is false there (true for a home screen web app, undefined in
the Chromium the other scenarios run), so this scenario sets it before the reader loads.

Safari's toolbar and the status bar also take SAFARI_CHROME pixels of the screen that the page
doesn't get, so the screen is made that much taller than the window, and the screens have to
reach under the toolbar with their controls above it (mobile.css Under Safari's toolbar).
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


# Where a screen, its bottom controls and the end of its list sit, as page coordinates.
GEOMETRY = """((screen, controls, list) => {
  var rect = function (selector) {
    var el = document.querySelector(selector);
    return el ? el.getBoundingClientRect() : null;
  };
  var scroller = document.querySelector(list);
  scroller.scrollTop = scroller.scrollHeight;
  var rows = Array.prototype.filter.call(scroller.querySelectorAll('.feed, .NB-story-title, .NB-feeds-header, p, li'),
    function (el) { return el.offsetParent && el.getBoundingClientRect().height; });
  var last = rows.length ? rows[rows.length - 1].getBoundingClientRect().bottom : null;
  return {window: window.innerHeight, screen: rect(screen).bottom, controls_top: rect(controls).top,
          controls_bottom: rect(controls).bottom, last_row: last};
})"""


def check_under_toolbar(ctx, feed_id):
    """The screens reach SAFARI_CHROME below the window, under Safari's toolbar, while the feed
    list's filter pills, the story list's pills and the story toolbar stay 8px above it, and
    each list scrolls its last row clear of them."""
    page = ctx.page
    ctx.check(
        "the screens reach under Safari's toolbar",
        ctx.evaluate(
            "document.body.classList.contains('NB-mobile-under-chrome') && "
            "getComputedStyle(document.body).getPropertyValue('--nb-mobile-chrome-bottom').trim()"
        )
        == f"{SAFARI_CHROME}px",
    )
    feeds = ctx.evaluate(GEOMETRY + "('.left-pane', '.left-south .NB-intelligence-slider', '.left-center-content')")
    ctx.shot("under-toolbar-feeds")
    ctx.check(
        "the feed list runs under the toolbar with its filter pills above it",
        feeds["screen"] == feeds["window"] + SAFARI_CHROME
        and feeds["controls_bottom"] == feeds["window"] - 8
        and feeds["last_row"] <= feeds["controls_top"],
        feeds,
    )

    ctx.open_feed(feed_id)
    ctx.set_layout("list")
    titles = ctx.evaluate(GEOMETRY + "('.right-pane', '.right-pane > .content-north .NB-feedbar-options', '#story_titles')")
    ctx.shot("under-toolbar-titles")
    ctx.check(
        "the story list runs under the toolbar with its pills above it",
        titles["screen"] == titles["window"] + SAFARI_CHROME
        and titles["controls_bottom"] == titles["window"] - 8
        and titles["last_row"] <= titles["controls_top"],
        titles,
    )

    ctx.set_layout("grid")
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = 0; })()")
    ctx.tap_story(1)
    ctx.wait(1500)
    story = ctx.evaluate(
        GEOMETRY + "('.NB-mobile-story-screen', '.NB-mobile-story-toolbar', '.NB-mobile-story-page-current')"
    )
    ctx.shot("under-toolbar-story")
    ctx.check(
        "the story runs under the toolbar with its own toolbar above it",
        story["screen"] == story["window"] + SAFARI_CHROME
        and story["controls_bottom"] == story["window"] - 8
        and story["last_row"] <= story["controls_top"],
        story,
    )

    # Something scrolling the taller page itself, here a script, is put back.
    ctx.evaluate("window.scrollTo(0, 80)")
    ctx.wait(200)
    ctx.check("the page scrolls back to the top", ctx.evaluate("window.scrollY") == 0)
    page.locator(".NB-mobile-story-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)

    # A full-screen modal covers the part under the toolbar too, instead of leaving the screen
    # beneath showing there.
    ctx.evaluate("NEWSBLUR.reader.open_preferences_modal()")
    page.wait_for_selector("#simplemodal-container .NB-modal", timeout=15000)
    ctx.wait(600)
    modal_bottom = ctx.evaluate("document.querySelector('#simplemodal-container').getBoundingClientRect().bottom")
    ctx.check(
        "a modal reaches under the toolbar",
        modal_bottom == ctx.evaluate("window.innerHeight") + SAFARI_CHROME,
        modal_bottom,
    )
    ctx.close_overlays()
