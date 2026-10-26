"""
desktop.py: a desktop-sized window never sees the phone layout or its chrome.
"""

DESKTOP_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36"
)
VIEWPORT = {"width": 1440, "height": 900, "mobile": False, "touch": False, "user_agent": DESKTOP_UA}


def run(ctx):
    ctx.login("/")
    ctx.check("the phone layout is inactive", not ctx.state()["active"])
    ctx.shot("01-dashboard")
    ctx.evaluate(f"NEWSBLUR.reader.open_feed({ctx.pick_feed()})")
    ctx.wait(3000)
    ctx.evaluate("(() => { var story = NEWSBLUR.assets.stories.at(1); if (story) story.set('selected', true); })()")
    ctx.wait(1500)
    ctx.check(
        "no phone chrome is visible",
        ctx.evaluate("$('.NB-mobile-bar:visible, .NB-mobile-story-screen:visible, .NB-mobile-toolbar:visible').length == 0"),
    )
    ctx.check("history entries are left untagged", not (ctx.state()["entry"]))
    ctx.shot("02-feed")
    ctx.check_no_page_errors()
