"""
safari.py: iOS Safari's browser mode, where Safari swipes back and forward from the screen's
edges itself. navigator.standalone is false there (true for a home screen web app, undefined in
the Chromium the other scenarios run), so this scenario sets it before the reader loads.
"""

ANIMATING = (
    "document.querySelectorAll('.NB-mobile-animating, .NB-mobile-dragging').length > 0 || "
    "document.body.classList.contains('NB-mobile-transitioning')"
)


def run(ctx):
    page = ctx.page
    page.add_init_script("Object.defineProperty(navigator, 'standalone', {value: false, configurable: true})")
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
    ctx.check_no_page_errors()
