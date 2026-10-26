"""
tablet.py: an iPad in portrait (768x1024) gets the phone layout with a two-column grid.
"""

VIEWPORT = {
    "width": 768,
    "height": 1024,
    "user_agent": "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
                  "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
}


def run(ctx):
    ctx.login("/")
    ctx.check("the phone layout is active in portrait", ctx.state()["active"])
    ctx.open_feed(ctx.pick_feed())
    ctx.set_layout("grid")
    columns = ctx.evaluate(
        "getComputedStyle(document.querySelector('#story_titles > .NB-story-titles')).gridTemplateColumns.split(' ').length"
    )
    ctx.check("the grid has two columns", columns == 2, columns)
    ctx.shot("01-grid")
    ctx.tap_story(1)
    ctx.check("cards push the story screen", ctx.state()["screen"] == "story")
    ctx.shot("02-story")
    ctx.check_no_page_errors()
