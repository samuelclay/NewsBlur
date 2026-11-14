"""
sheets.py: a story's Share form, its Save tags and notes, and its Related stories opened inside
the story on a phone, at its end, and iOS zoomed the page in on the share field. Each now slides
up as a bottom sheet over the shade, like Ask AI (mobile_layout_view.js Sideoption sheets).

Saving and unsaving the test story is undone before the scenario ends. Nothing is shared.
"""

SHEET = """(() => {
  var sheet = document.querySelector('.NB-mobile-sideoption-sheet');
  var shade = document.querySelector('.NB-mobile-sheet-shade');
  var panel = function (selector) {
    var el = sheet && sheet.querySelector(selector);
    return !!el && el.offsetHeight > 0;
  };
  var inline = Array.prototype.filter.call(
    document.querySelectorAll('.NB-mobile-story-page-current .NB-sideoption-share-wrapper, ' +
      '.NB-mobile-story-page-current .NB-sideoption-save-wrapper, ' +
      '.NB-mobile-story-page-current .NB-story-content-discover-wrapper'),
    function (el) { return el.offsetHeight > 0; }).length;
  var box = sheet && sheet.getBoundingClientRect();
  var field = document.activeElement;
  return {
    open: !!sheet,
    left: box && Math.round(box.left), right: box && Math.round(box.right),
    bottom: box && Math.round(box.bottom), top: box && Math.round(box.top),
    window_width: window.innerWidth, window_height: window.innerHeight,
    shade: getComputedStyle(shade).display !== 'none',
    share: panel('.NB-sideoption-share-wrapper'), save: panel('.NB-sideoption-save-wrapper'),
    related: panel('.NB-story-content-discover-wrapper'),
    inline: inline,
    focused: field && field.className, focused_in_sheet: !!field && !!field.closest('.NB-mobile-sideoption-sheet'),
    focused_font: field ? parseFloat(getComputedStyle(field).fontSize) : null,
    page_scroll: document.body.classList.contains('NB-mobile-page-scroll'),
    starred: !!NEWSBLUR.app.mobile.story_pager.story.get('starred')
  };
})()"""


def sideoption(ctx, name):
    """Taps one of the buttons at the end of the open story."""
    button = ctx.page.locator(f".NB-mobile-story-page-current .NB-sideoption.NB-feed-story-{name}").first
    button.scroll_into_view_if_needed()
    ctx.wait(300)
    button.tap()
    ctx.wait(900)


def close_sheet(ctx):
    ctx.page.locator(".NB-mobile-sheet-shade").tap(position={"x": 40, "y": 60})
    ctx.wait(900)


def as_sheet(state):
    return (
        state["open"]
        and state["shade"]
        and state["left"] == 0
        and state["right"] == state["window_width"]
        and state["bottom"] == state["window_height"]
        and state["top"] > 0
        and not state["inline"]
    )


def run(ctx):
    page = ctx.page
    ctx.login("/")
    ctx.open_feed(ctx.pick_feed())
    ctx.set_layout("grid")
    ctx.tap_story(1)
    ctx.wait(800)
    was_starred = ctx.evaluate(SHEET)["starred"]

    sideoption(ctx, "share")
    state = ctx.evaluate(SHEET)
    ctx.check("Share slides up as a bottom sheet, not inside the story", as_sheet(state) and state["share"], state)
    ctx.check(
        "the share field takes the cursor at a text size iOS doesn't zoom in on",
        state["focused_in_sheet"] and state["focused_font"] >= 16,
        state,
    )
    page.keyboard.type("worth reading")
    ctx.wait(400)
    typed = ctx.evaluate(
        "(() => ({value: document.querySelector('.NB-mobile-sideoption-sheet .NB-sideoption-share-comments').value, "
        "button: document.querySelector('.NB-mobile-sideoption-sheet .NB-sideoption-share-save').offsetHeight > 0}))()"
    )
    ctx.check(
        "the share form in the sheet still takes a comment and offers its Share button",
        typed["value"] == "worth reading" and typed["button"],
        typed,
    )
    ctx.shot("01-share")
    ctx.evaluate(
        "(() => { var view = NEWSBLUR.app.mobile.sideoption.view; "
        "NEWSBLUR.app.mobile.close_sideoption_sheet(); "
        "view.toggle_feed_story_share_dialog(); })()"
    )
    ctx.wait(600)
    state = ctx.evaluate(SHEET)
    ctx.check("Share can reopen while its previous sheet is still closing", as_sheet(state) and state["share"], state)
    close_sheet(ctx)
    state = ctx.evaluate(SHEET)
    ctx.check(
        "tapping the shade closes the share sheet and leaves nothing open in the story",
        not state["open"] and not state["shade"] and not state["inline"] and state["page_scroll"],
        state,
    )

    sideoption(ctx, "discover")
    state = ctx.evaluate(SHEET)
    ctx.check("Related slides up as a bottom sheet", as_sheet(state) and state["related"], state)
    ctx.shot("02-related")
    close_sheet(ctx)
    ctx.check("the related sheet closes", not ctx.evaluate(SHEET)["open"])

    if was_starred:
        sideoption(ctx, "save")
        state = ctx.evaluate(SHEET)
        ctx.check("Saved opens existing tags and notes without unsaving", as_sheet(state) and state["save"] and state["starred"], state)
        ctx.shot("03-existing-save")
        close_sheet(ctx)
    else:
        sideoption(ctx, "save")
        state = ctx.evaluate(SHEET)
        ctx.check(
            "Save saves the story and slides up its tags and notes as a bottom sheet",
            as_sheet(state) and state["save"] and state["starred"],
            state,
        )
        ctx.shot("03-save")
        close_sheet(ctx)
        state = ctx.evaluate(SHEET)
        ctx.check(
            "closing the save sheet keeps the story saved, with its tags out of the story",
            not state["open"] and state["starred"] and not state["inline"],
            state,
        )
        sideoption(ctx, "save")
        state = ctx.evaluate(SHEET)
        ctx.check("tapping Saved reopens tags and notes without unsaving", as_sheet(state) and state["save"] and state["starred"], state)
        close_sheet(ctx)

        page.locator(".NB-mobile-story-save").tap()
        ctx.wait(900)
        ctx.check("the toolbar's star still unsaves without a sheet", not ctx.evaluate(SHEET)["starred"])

        page.locator(".NB-mobile-story-save").tap()
        ctx.wait(900)
        state = ctx.evaluate(SHEET)
        ctx.check("the toolbar's star saves without a sheet", not state["open"] and state["starred"], state)
        page.locator(".NB-mobile-story-save").tap()
        ctx.wait(900)
        ctx.check("the test story is left unsaved", not ctx.evaluate(SHEET)["starred"])
    ctx.check_no_page_errors()
