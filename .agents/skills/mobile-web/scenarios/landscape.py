"""
landscape.py: a phone held sideways (852x393) is wider than the 768px breakpoint but keeps the
phone layout, because short touch screens count as phones (common/mobile_utils.js).
"""

VIEWPORT = {"width": 852, "height": 393}


def run(ctx):
    ctx.login("/")
    ctx.check("the phone layout stays active sideways", ctx.state()["active"])
    feed_id = ctx.pick_feed()
    ctx.shot("01-feeds")
    ctx.open_feed(feed_id)
    ctx.set_layout("list")
    ctx.check("the story list fills the screen", ctx.screen_left(".right-pane") == 0)
    ctx.shot("02-story-list")
    ctx.tap_story(1)
    ctx.shot("03-expanded")
    ctx.check_no_page_errors()
