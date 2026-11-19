"""
feed_list_entrance.py: on desktop, the feed list enters as one cascade from the top down, like the iOS and Android
apps, both when it is drawn from the server's answer and when it is drawn from its localStorage copy.

The Unread and Focus filters hide read sites with CSS: the body's NB-feedlist-hide-read-feeds class and the
sidebar's unread_view_* class. If the list's entrance (feed_list_view.js make_feeds, NEWSBLUR.motion.watch) starts
before the sidebar has its unread_view_* class, it staggers rows the filter is about to hide, and the rows that
slide up into view once they are hidden start a second cascade of their own, so the list fills in two waves.
"""

from desktop import VIEWPORT  # noqa: F401  (desktop.py: a 1440x900 window without touch)

# feed_list_entrance.py records when each feed list row's entrance is asked to start, before the page's scripts run.
RECORD_ENTRANCES = """(() => {
    window.feed_list_entrances = [];
    const original = Element.prototype.animate;
    Element.prototype.animate = function (frames, options) {
        if (this.matches && this.matches('.NB-feedlist .feed, .NB-feedlist .folder_title')) {
            const label = this.querySelector('.feed_title, .folder_title_text');
            const title = label ? label.textContent.trim() : '';
            // feed_list_entrance.py keys rows the way feed_list_view.js does, since the list can be drawn again.
            window.feed_list_entrances.push({key: this.getAttribute('data-id') || 'folder:' + title, title: title,
                start: performance.now() + ((options && options.delay) || 0)});
        }
        return original.apply(this, arguments);
    };
})()"""

# feed_list_entrance.py describes each entrance once the list has settled: whether a row with its key is still
# shown, and where it ended up.
SETTLED = """(() => {
    const rows = Array.from(document.querySelectorAll('.NB-feedlist .feed, .NB-feedlist .folder_title'));
    const key_of = row => {
        const label = row.querySelector('.feed_title, .folder_title_text');
        return row.getAttribute('data-id') || 'folder:' + (label ? label.textContent.trim() : '');
    };
    const shown = row => !!row.getClientRects().length && getComputedStyle(row).display !== 'none';
    return window.feed_list_entrances.map(entry => {
        const row = rows.find(row => key_of(row) === entry.key && shown(row));
        return {start: entry.start, shown: !!row, top: row ? row.getBoundingClientRect().top : null,
            title: entry.title.slice(0, 40)};
    });
})()"""

HIDDEN_SITES = (
    "Array.from(document.querySelectorAll('.NB-feedlist .feed'))"
    ".filter(row => getComputedStyle(row).display === 'none').length"
)


def pauses(entrances):
    """Neighbouring shown rows whose entrances start far apart: a second wave after the first cascade ended. One
    cascade staggers rows at most 35ms apart (common/motion.js watch)."""
    rows = sorted((entry for entry in entrances if entry["shown"]), key=lambda entry: entry["top"])
    return [
        (upper["title"], lower["title"], round(lower["start"] - upper["start"]))
        for upper, lower in zip(rows, rows[1:])
        if lower["start"] - upper["start"] > 100
    ]


def load_and_check(ctx, label, clear_cache):
    page = ctx.page
    if clear_cache:
        ctx.evaluate("localStorage.clear()")
    page.reload(wait_until="load")
    page.wait_for_function(
        "window.NEWSBLUR && NEWSBLUR.assets && NEWSBLUR.assets.feeds && NEWSBLUR.assets.feeds.length", timeout=60000
    )
    ctx.wait(3500)
    entrances = ctx.evaluate(SETTLED)
    hidden = [entry["title"] for entry in entrances if not entry["shown"]]
    ctx.check(f"{label}: the feed list's rows enter", len(entrances) >= 10, len(entrances))
    ctx.check(
        f"{label}: every row that enters is still shown once the Unread filter applies",
        not hidden,
        hidden[:6],
    )
    ctx.check(
        f"{label}: no second wave of rows starts after the first cascade",
        not pauses(entrances),
        pauses(entrances)[:4],
    )


def run(ctx):
    page = ctx.page
    ctx.login("/")
    # feed_list_entrance.py uses the Unread filter, which hides read sites. run.py puts the preferences back.
    ctx.evaluate(
        "(() => { NEWSBLUR.assets.preference('hide_read_feeds', 1); NEWSBLUR.assets.preference('unread_view', 0); })()"
    )
    ctx.check(
        "animations are on, so the entrance runs",
        ctx.evaluate(
            "NEWSBLUR.assets.preference('animations') !== false && !NEWSBLUR.assets.preference('reduce_motion')"
        ),
    )
    page.add_init_script(RECORD_ENTRANCES)
    page.reload(wait_until="load")
    page.wait_for_function("NEWSBLUR.assets && NEWSBLUR.assets.feeds && NEWSBLUR.assets.feeds.length", timeout=60000)
    ctx.wait(3000)
    ctx.check(
        "the Unread filter hides some read sites, so the test can tell",
        ctx.evaluate(HIDDEN_SITES) > 0,
        ctx.evaluate(HIDDEN_SITES),
    )

    load_and_check(ctx, "drawn from the server", clear_cache=True)
    ctx.shot("01-from-server")
    load_and_check(ctx, "drawn from its copy", clear_cache=False)
    ctx.shot("02-from-copy")

    # feed_list_entrance.py: reader.js applies the saved filter before the feeds arrive and must leave the Saved
    # filter for load_intelligence_slider to pick up, without turning it back into Unread.
    ctx.evaluate("NEWSBLUR.assets.preference('unread_view', 2)")
    page.reload(wait_until="load")
    page.wait_for_function("NEWSBLUR.assets && NEWSBLUR.assets.feeds && NEWSBLUR.assets.feeds.length", timeout=60000)
    ctx.wait(3000)
    saved = ctx.evaluate(
        "({unread_view: NEWSBLUR.assets.preference('unread_view'), starred: NEWSBLUR.reader.flags.feed_list_showing_starred,"
        " active: $('.NB-intelligence-slider .NB-active').attr('class')})"
    )
    ctx.check(
        "a reload keeps the Saved filter selected",
        saved["unread_view"] == 2 and saved["starred"] and "NB-intelligence-slider-blue" in (saved["active"] or ""),
        saved,
    )
    ctx.check_no_page_errors()
