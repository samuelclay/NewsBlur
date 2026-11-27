"""
team.py: the team dialog (reader_team.js) on a phone, for the account run.py logs in as (--user). Every tab that
account sees opens as a full screen sheet with nothing hanging off the side, and gets screenshots from top to
bottom. Pass --args dark for the dark theme (applied in the page only, never saved).
"""

from modals import OVERFLOW

SCROLLER = "#simplemodal-container .simplemodal-wrap"


def run(ctx):
    theme = (ctx.args or "light").strip()
    ctx.login("/")
    if theme == "dark":
        ctx.use_dark_theme()
    ctx.evaluate("NEWSBLUR.reader.open_team_modal()")
    ctx.wait(2000)
    ctx.check("the team dialog opens", ctx.evaluate("$('.NB-modal-team').length") == 1)

    tabs = ctx.evaluate("$('.NB-modal-team .NB-modal-tab').map(function () { return $(this).attr('data-tab'); }).get()")
    for tab in tabs or ["none"]:
        if tab != "none":
            ctx.page.locator(f".NB-modal-team .NB-modal-tab-{tab}").tap()
            ctx.wait(1500)
        ctx.evaluate(f"document.querySelector('{SCROLLER}').scrollTop = 0")
        overflow = ctx.evaluate(OVERFLOW)
        ctx.check(f"the {tab} tab fits the screen", not overflow, overflow)
        # team.py: a page of the sheet at a time, down to its end.
        for page in range(6):
            ctx.wait(300)
            ctx.shot(f"{theme}-{ctx.user}-{tab}-{page + 1}")
            moved = ctx.evaluate(
                f"(() => {{ var el = document.querySelector('{SCROLLER}'); var top = el.scrollTop; "
                f"el.scrollTop = top + el.clientHeight - 80; return el.scrollTop > top; }})()"
            )
            if not moved:
                break
    ctx.close_overlays()
    ctx.check_no_page_errors()
