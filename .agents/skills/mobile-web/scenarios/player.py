"""
player.py: the Listen and podcast player (views/media_player_view.js) on a phone. It floats as a
one-row bar above each screen's bottom toolbar, opens as a bottom sheet when tapped, and closes
from the shade.

It uses whatever the account's player already holds (playback state restores on load), since
starting Listen would call the text-to-speech service. With an empty player it skips.
"""

PLAYER = """(() => {
    var p = document.querySelector('.NB-media-player'), r = p.getBoundingClientRect();
    return {in_body: p.parentElement === document.body, hidden: p.classList.contains('NB-hidden'),
            expanded: p.classList.contains('NB-mobile-player-expanded'),
            top: Math.round(r.top), bottom: Math.round(r.bottom), height: Math.round(r.height)};
})()"""


def run(ctx):
    page = ctx.page
    ctx.login("/")
    player = ctx.evaluate(PLAYER)
    if player["hidden"]:
        print("SKIP player: nothing is loaded in this account's player")
        return
    ctx.check("the player moves out of the feed list onto every screen", player["in_body"], player)
    taskbar_top = ctx.evaluate("Math.round(document.querySelector('.left-south .NB-taskbar-container').getBoundingClientRect().top)")
    ctx.check("on the feed list it floats above the taskbar", player["bottom"] <= taskbar_top, (player, taskbar_top))
    ctx.check("collapsed, it is a single row", player["height"] <= 72, player)
    ctx.shot("01-feeds")

    ctx.open_feed(ctx.pick_feed())
    ctx.set_layout("grid")
    ctx.tap_story(1)
    player = ctx.evaluate(PLAYER)
    toolbar_top = ctx.evaluate("Math.round(document.querySelector('.NB-mobile-story-toolbar').getBoundingClientRect().top)")
    ctx.check("on the story screen it floats above the toolbar", player["bottom"] <= toolbar_top, (player, toolbar_top))
    ctx.shot("02-story")

    page.locator(".NB-media-player .NB-media-player-title").tap()
    ctx.wait(600)
    player = ctx.evaluate(PLAYER)
    ctx.check(
        "tapping the bar opens the full player as a sheet",
        player["expanded"] and player["bottom"] == ctx.viewport["height"],
        player,
    )
    ctx.check(
        "the sheet shows the scrubber and controls",
        ctx.evaluate("$('.NB-media-player .NB-media-player-row-scrubber:visible, .NB-media-player .NB-media-player-skip-back:visible').length == 2"),
    )
    ctx.shot("03-expanded")
    page.locator(".NB-mobile-player-shade").tap(position={"x": 200, "y": 60})
    ctx.wait(500)
    ctx.check("tapping outside collapses it", not ctx.evaluate(PLAYER)["expanded"])
    ctx.check("and it stays on the story screen", ctx.state()["screen"] == "story")
    ctx.check_no_page_errors()
