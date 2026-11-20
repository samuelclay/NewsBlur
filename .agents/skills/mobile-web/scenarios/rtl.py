"""
rtl.py: the phone layout in Arabic. Screens slide in from the left, the next story is to the
left (a swipe to the right reveals it), and the edge swipe back starts at the right edge.
"""

VIEWPORT = {"locale": "ar"}


def run(ctx):
    page = ctx.page
    width = ctx.viewport["width"]
    ctx.login("/")
    ctx.check("the page is right to left", ctx.evaluate("document.documentElement.dir") == "rtl")
    ctx.check("the phone layout is active", ctx.state()["active"])
    feed_id = ctx.pick_feed()
    ctx.shot("01-feeds")

    row = ctx.feed_row(feed_id)
    ctx.press_point(row)
    row.tap()
    ctx.wait(150)
    x = ctx.evaluate(
        "(() => { var m = getComputedStyle(document.querySelector('.right-pane')).transform; "
        "return m === 'none' ? 0 : parseFloat(m.split(',')[4]); })()"
    )
    ctx.check("the story list slides in from the left", x < 0, x)
    page.wait_for_function("NEWSBLUR.assets.stories.length > 0", timeout=30000)
    ctx.wait(1500)
    ctx.shot("02-story-list")

    ctx.set_layout("grid")
    ctx.tap_story(1)
    ctx.shot("03-story")
    first = ctx.state()["story"]
    ctx.touch.swipe(60, 600, width - 60, 605, steps=10)
    ctx.wait(900)
    second = ctx.state()["story"]
    ctx.check("swiping right pages to the next story", second != first and second, (first, second))
    ctx.touch.swipe(width - 60, 600, 60, 605, steps=10)
    ctx.wait(900)
    ctx.check("swiping left pages back", ctx.state()["story"] == first)

    release = ctx.touch.drag(width - 5, 400, width - 200, 400, steps=10)
    ctx.wait(80)
    ctx.shot("04-edge-swipe-back-mid")
    release()
    ctx.wait(900)
    ctx.check("an edge swipe from the right goes back", ctx.state()["screen"] == "titles", ctx.state())
    ctx.set_layout("list")
    ctx.check_no_page_errors()
