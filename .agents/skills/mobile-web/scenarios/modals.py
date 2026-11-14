"""
modals.py: every modal and popover sheet on a phone. Each opens full width with nothing hanging
off the side of the screen, and gets a screenshot.
"""

MODALS = [
    ("preferences", "NEWSBLUR.reader.open_preferences_modal()"),
    ("account", "NEWSBLUR.reader.open_account_modal()"),
    ("site-settings", "NEWSBLUR.reader.open_feed_exception_modal({feed})"),
    ("statistics", "NEWSBLUR.reader.open_feed_statistics_modal({feed})"),
    ("notifications", "NEWSBLUR.reader.open_notifications_modal({feed})"),
    ("trainer", "NEWSBLUR.reader.open_trainer_modal()"),
    ("organizer", "NEWSBLUR.reader.open_organizer_modal()"),
    ("premium", "NEWSBLUR.reader.open_premium_upgrade_modal()"),
    ("newsletters", "NEWSBLUR.reader.open_newsletters_modal()"),
    ("goodies", "NEWSBLUR.reader.open_goodies_modal()"),
    ("friends", "NEWSBLUR.reader.open_friends_modal()"),
    ("mark-read", "NEWSBLUR.reader.open_mark_read_modal()"),
    ("add-site", "NEWSBLUR.reader.open_add_feed_modal()"),
    ("feedchooser", "NEWSBLUR.reader.open_feedchooser_modal()"),
    ("profile-editor", "NEWSBLUR.reader.open_profile_editor_modal()"),
    ("social-profile", "NEWSBLUR.reader.open_social_profile_modal(NEWSBLUR.Globals.user_id)"),
    ("intro", "NEWSBLUR.reader.open_intro_modal()"),
    ("keyboard", "NEWSBLUR.reader.open_keyboard_shortcuts_modal()"),
    ("faq", "NEWSBLUR.reader.open_faq_modal()"),
]

# modals.py: elements reaching past the screen edge that aren't inside something that scrolls
# sideways on purpose. Only the outermost offender of each branch is reported.
OVERFLOW = """(() => {
    var root = document.querySelector('#simplemodal-container .simplemodal-wrap') ||
        document.querySelector('.NB-popover .popover-inner');
    if (!root) return null;
    var width = innerWidth, found = [];
    root.querySelectorAll('*').forEach(function (el) {
        var r = el.getBoundingClientRect();
        if (!r.width || (r.right <= width + 1 && r.left >= -1)) return;
        for (var p = el.parentElement; p && p !== root; p = p.parentElement) {
            var overflow = getComputedStyle(p).overflowX;
            if (overflow === 'auto' || overflow === 'scroll' || overflow === 'hidden') return;
        }
        var parent = el.parentElement.getBoundingClientRect();
        if (el.parentElement !== root && (parent.right > width + 1 || parent.left < -1)) return;
        found.push((typeof el.className === 'string' && el.className || el.tagName) +
            ' ' + Math.round(r.left) + '..' + Math.round(r.right));
    });
    return found.slice(0, 5);
})()"""


def check_dialog_actions(ctx):
    # modals.py: phone users must be able to reach dialog navigation and subscription actions.
    # A desktop flex header or fixed-width onboarding table can hide them behind overflow:hidden.
    original = ctx.page.viewport_size
    try:
        for width in (393, 320):
            ctx.page.set_viewport_size({"width": width, "height": 852})
            for name, opening, selector in (
                ("trainer navigation", "open_trainer_modal()", ".NB-modal-tab-manage"),
                (
                    "onboarding subscription",
                    "open_intro_modal({page_number: 3})",
                    ".NB-intro-uptodate-follow-blog",
                ),
            ):
                ctx.evaluate("NEWSBLUR.reader." + opening)
                ctx.wait(800)
                control = ctx.page.locator(selector)
                reach = control.evaluate(
                    "el => { const r = el.getBoundingClientRect(); "
                    "return {left: r.left, right: r.right, width: innerWidth}; }"
                )
                reachable = reach["left"] >= 0 and reach["right"] <= reach["width"]
                ctx.check(f"{name} is touch-reachable at {width}px", reachable, reach)
                if reachable:
                    # modals.py: trial checks hit testing without subscribing the dev account.
                    control.click(trial=True, timeout=3000)
                    if name == "trainer navigation":
                        control.tap()
                        ctx.wait(500)
                        ctx.check(
                            f"Manage Training activates at {width}px",
                            "NB-active" in (control.get_attribute("class") or ""),
                        )
                ctx.close_overlays()
    finally:
        ctx.close_overlays()
        ctx.page.set_viewport_size(original)


def run(ctx):
    ctx.login("/")
    feed_id = ctx.pick_feed()
    for name, js in MODALS:
        ctx.evaluate(js.format(feed=feed_id))
        ctx.wait(1800)
        ctx.shot(name)
        overflow = ctx.evaluate(OVERFLOW)
        ctx.check(f"{name} opens", overflow is not None)
        ctx.check(f"{name} fits the screen", not overflow, overflow)
        ctx.close_overlays()

    ctx.page.locator(".NB-feeds-header-user-interactions").tap()
    ctx.wait(1500)
    ctx.shot("activity-sheet")
    sheet = ctx.evaluate(
        "(() => { var p = document.querySelector('.NB-popover'); if (!p) return null; "
        "var r = p.getBoundingClientRect(); return Math.round(innerHeight - r.bottom); })()"
    )
    ctx.check("the activity popover is a bottom sheet", sheet is not None and abs(sheet) <= 1, sheet)
    ctx.close_overlays()
    check_dialog_actions(ctx)
    ctx.check_no_page_errors()
