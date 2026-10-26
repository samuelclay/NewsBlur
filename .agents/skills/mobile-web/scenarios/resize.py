"""
resize.py: a desktop window narrowed past the breakpoint switches to the phone layout with the
open feed, and widening it switches back, leaving the feed's desktop layout untouched.
"""

DESKTOP_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36"
)
VIEWPORT = {"width": 1280, "height": 800, "mobile": False, "touch": False, "user_agent": DESKTOP_UA}


def run(ctx):
    page = ctx.page
    ctx.login("/")
    feed_id = ctx.pick_feed()
    ctx.evaluate(f"NEWSBLUR.reader.open_feed({feed_id})")
    ctx.wait(2500)
    layout = ctx.evaluate(f"NEWSBLUR.Preferences.view_settings['{feed_id}'] && NEWSBLUR.Preferences.view_settings['{feed_id}'].l")
    ctx.check("desktop starts without the phone layout", not ctx.state()["active"])
    ctx.shot("01-desktop")

    page.set_viewport_size({"width": 390, "height": 844})
    ctx.wait(2500)
    state = ctx.state()
    ctx.check("narrowing switches to the phone layout", state["active"], state)
    ctx.check("the open feed shows as its story list", state["screen"] == "titles", state)
    ctx.shot("02-narrow")

    page.set_viewport_size({"width": 1280, "height": 800})
    ctx.wait(2500)
    ctx.check(
        "widening switches back",
        not ctx.state()["active"] and not ctx.evaluate("document.body.classList.contains('NB-mobile')"),
    )
    ctx.check(
        "the feed's desktop layout is unchanged",
        ctx.evaluate(f"NEWSBLUR.Preferences.view_settings['{feed_id}'] && NEWSBLUR.Preferences.view_settings['{feed_id}'].l") == layout,
    )
    ctx.shot("03-desktop-again")
    ctx.check_no_page_errors()
