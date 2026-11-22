"""
river_switch.py: on desktop, leaving a folder for All Site Stories fades both story panes out exactly as they
looked, then fades the river in.

NEWSBLUR.motion.depart (common/motion.js) snapshots the old rows' computed styles into an inert copy. Feed
titles and the wide river padding only apply under .NB-view-river (reader.css), and reader.js reset_feed
drops that class and scrolls the Split layout's story pane (story_list_view.js) to the top, so both panes have
to be copied before reset_feed changes anything. Otherwise the folder list flashes as a single feed and the
story pane departs showing the top of the list. Both panes are scrolled down first so a copy of the wrong rows
shows up. The story pane's copy also keeps a story's stuck feed header in place and draws embedded video as an
empty box instead of loading it again.
"""

from desktop import VIEWPORT  # noqa: F401  (desktop.py: a 1440x900 window without touch)

# river_switch.py describes the first title row and first story drawn inside a scroll pane, live or departing.
DESCRIBE = """
    window.river_switch_first = (rows, bounds, title_selector) => {
        const row = rows.find(row => {
            const rect = row.getBoundingClientRect();
            return rect.height && rect.bottom > bounds.top && rect.top < bounds.bottom;
        });
        if (!row) return null;
        const title = row.querySelector(title_selector);
        const header = row.querySelector('.NB-feed-story-header-feed');
        const rect = row.getBoundingClientRect();
        return {title: title ? title.textContent.trim() : null, top: Math.round(rect.top), height: Math.round(rect.height),
            header: header ? Math.round(header.getBoundingClientRect().top) : null};
    };
    // river_switch.py counts the feed titles drawn inside the titles pane; the copy leaves out the ones off screen.
    window.river_switch_feed_titles = root => {
        const pane = document.querySelector('#story_titles').getBoundingClientRect();
        return Array.from(root.querySelectorAll('.NB-story-feed')).filter(title => {
            const rect = title.getBoundingClientRect();
            return rect.height && getComputedStyle(title).display !== 'none' && getComputedStyle(title).visibility !== 'hidden' &&
                rect.bottom > pane.top && rect.top < pane.bottom;
        }).length;
    };
    window.river_switch_box = element => {
        if (!element) return null;
        const rect = element.getBoundingClientRect();
        return [Math.round(rect.left), Math.round(rect.top), Math.round(rect.width), Math.round(rect.height)];
    };
    // river_switch.py finds the departing copy's stand-in for the video frame: an empty box drawn in its place.
    window.river_switch_stand_in = (ghost, box) => box && Array.from(ghost.querySelectorAll('div'))
        .filter(node => !node.childNodes.length)
        .map(window.river_switch_box)
        .find(found => found.every((value, index) => Math.abs(value - box[index]) <= 1)) || null;
"""

WATCH_FOR_GHOSTS = (
    """(() => {
    %s
    window.river_switch_ghosts = {titles: [], stories: []};
    const observer = new MutationObserver(records => {
        for (const record of records) {
            for (const node of record.addedNodes) {
                if (node.nodeType !== 1 || !node.inert) continue;
                const everything = {top: -Infinity, bottom: Infinity};
                if (node.querySelector('.NB-story-title')) {
                    // river_switch.py freezes the departing copy on the frame it appears, to measure and photograph it.
                    if (!window.river_switch_ghosts.titles.length) node.getAnimations().forEach(animation => animation.pause());
                    const rows = node.querySelectorAll('.NB-story-title');
                    window.river_switch_ghosts.titles.push({rows: rows.length, feed_titles: window.river_switch_feed_titles(node),
                        padding_left: rows.length ? rows[0].style.paddingLeft : null,
                        first: window.river_switch_first(Array.from(node.children), everything, '.NB-storytitles-title')});
                } else if (node.querySelector('.NB-feed-story')) {
                    if (!window.river_switch_ghosts.stories.length) node.getAnimations().forEach(animation => animation.pause());
                    window.river_switch_ghosts.stories.push({
                        first: window.river_switch_first(Array.from(node.children), everything, '.NB-feed-story-title'),
                        embeds: node.querySelectorAll('iframe, video, audio, object, embed').length,
                        embed_box: window.river_switch_stand_in(node, window.river_switch_before &&
                            window.river_switch_before.embed_box)});
                }
            }
        }
    });
    observer.observe(document.body, {childList: true});
    window.river_switch_observer = observer;
})()"""
    % DESCRIBE
)

LIVE_ROWS = (
    """(() => {
    %s
    window.river_switch_live = () => {
        const rows = $('#story_titles .NB-story-title:visible');
        const titles = document.querySelector('#story_titles').getBoundingClientRect();
        const stories = document.querySelector('.NB-feed-stories-container').getBoundingClientRect();
        return {rows: rows.length, feed_titles: window.river_switch_feed_titles(document.querySelector('#story_titles')),
            padding_left: rows.length ? getComputedStyle(rows[0]).paddingLeft : null,
            first: window.river_switch_first(Array.from(document.querySelectorAll('#story_titles .NB-story-titles > .NB-story-title-container')),
                titles, '.NB-storytitles-title'),
            first_story: window.river_switch_first(Array.from(document.querySelectorAll('.NB-feed-stories > .NB-feed-story')),
                stories, '.NB-feed-story-title'),
            embed_box: window.river_switch_box(document.querySelector('.NB-feed-story-content iframe')),
            scrolled: [$('#story_titles').scrollTop(), $('.NB-feed-stories-container').scrollTop()]};
    };
    // river_switch.py measures the live panes again inside the click itself, before reader.js runs, since a pane
    // that is still settling would otherwise be compared against an older frame.
    document.addEventListener('click', event => {
        if (event.target.closest('.NB-feeds-header-river-sites')) window.river_switch_before = window.river_switch_live();
    }, {capture: true, once: true});
    return window.river_switch_live();
})()"""
    % DESCRIBE
)

# river_switch.py records every entrance so the river's rows can be shown to fade in after the old list leaves.
RECORD_ENTRANCES = """(() => {
    window.river_switch_entrances = [];
    if (window.river_switch_animate) return;
    const original = window.river_switch_animate = Element.prototype.animate;
    Element.prototype.animate = function (frames, options) {
        if (this.matches('#story_titles .NB-story-title-container')) {
            window.river_switch_entrances.push({feed: NEWSBLUR.reader.active_feed,
                from: frames[0] && frames[0].opacity,
                duration: typeof options === 'number' ? options : options.duration});
        }
        return original.apply(this, arguments);
    };
})()"""

# river_switch.py waits for both panes to stop scrolling, since selecting a story scrolls each to it with an animation.
PANES_AT_REST = """(() => {
    const now = $('#story_titles').scrollTop() + ',' + $('.NB-feed-stories-container').scrollTop();
    if (window.river_switch_scroll !== now) {
        window.river_switch_scroll = now;
        window.river_switch_scroll_since = performance.now();
    }
    return performance.now() - window.river_switch_scroll_since > 600;
})()"""

RIVER_SHOWN = (
    "NEWSBLUR.reader.active_feed == 'river:' && "
    "$('#story_titles .NB-story-title .NB-story-feed:visible').length >= 3"
)


def same_place(before, after):
    """The first row or story drawn in a pane sits at the same height with the same size. Its title may be left
    out of the copy when it is scrolled off screen, so the geometry identifies it."""
    return bool(
        before
        and after
        and abs(before["top"] - after["top"]) <= 1
        and abs(before["height"] - after["height"]) <= 1
    )


def run(ctx):
    page = ctx.page
    ctx.login("/")
    folder = page.locator(".NB-feedlist .folder > .folder_title >> visible=true").first
    folder.locator(".folder_title_text").click()
    page.wait_for_function(
        "NEWSBLUR.reader.flags.river_view && $('#story_titles .NB-story-title .NB-story-feed:visible').length >= 6",
        timeout=30000,
    )
    # river_switch.py photographs the Split layout, whose story pane shows the Feed view next to the titles.
    ctx.evaluate(
        "(() => { if (NEWSBLUR.assets.view_setting('river:', 'layout') != 'split') "
        "NEWSBLUR.assets.view_setting('river:', {layout: 'split'}); NEWSBLUR.reader.switch_story_layout('split'); })()"
    )
    ctx.wait(1200)
    ctx.check(
        "the folder opens in the Split layout's Feed view",
        ctx.evaluate("NEWSBLUR.reader.story_view") == "feed",
    )
    # river_switch.py scrolls both panes partway down so a departure drawn after a scroll reset shows the wrong rows.
    # Opening the third story scrolls the story pane to it.
    page.locator("#story_titles .NB-story-title-container").nth(2).locator(".NB-storytitles-title").click()
    ctx.wait(1500)
    # river_switch.py then wheels 200px into that story, so its feed header is stuck to the top of the pane. A wheel
    # also ends story_list_view.js maintain_scroll_position, which would pull the story back to the top.
    pane = page.locator(".NB-feed-stories-container").bounding_box()
    page.mouse.move(pane["x"] + pane["width"] / 2, pane["y"] + pane["height"] / 2)
    page.mouse.wheel(0, 200)
    page.wait_for_function(PANES_AT_REST, polling=100, timeout=10000)
    ctx.evaluate(
        "$('#story_titles').scrollTop($('#story_titles .NB-story-title-container').eq(3)[0].offsetTop + 30)"
    )
    page.wait_for_function(PANES_AT_REST, polling=100, timeout=10000)
    # river_switch.py embeds a video frame on screen, in a paragraph as feeds do; its departing copy must not load it.
    ctx.evaluate(
        """(() => {
        const bounds = document.querySelector('.NB-feed-stories-container').getBoundingClientRect();
        const story = Array.from(document.querySelectorAll('.NB-feed-stories > .NB-feed-story'))
            .find(story => story.getBoundingClientRect().bottom > bounds.top);
        const content = story.querySelector('.NB-feed-story-content');
        const next = Array.from(content.children).find(child => child.getBoundingClientRect().top > bounds.top + 40);
        const paragraph = $('<p><iframe src="about:blank" width="320" height="180"></iframe></p>')[0];
        content.insertBefore(paragraph, next || null);
    })()"""
    )
    ctx.evaluate(LIVE_ROWS)
    ctx.shot("01-folder")

    ctx.evaluate(WATCH_FOR_GHOSTS)
    ctx.evaluate(RECORD_ENTRANCES)
    page.locator(".NB-feeds-header-river-sites").click()
    # river_switch.py: reader.js reset_feed departs both panes in one task, so the titles copy marks the moment.
    page.wait_for_function("window.river_switch_ghosts.titles.length", timeout=5000)
    ghosts = ctx.evaluate("window.river_switch_ghosts")
    ctx.shot("02-departing-folder")
    before = ctx.evaluate("window.river_switch_before")
    embed_box = before["embed_box"]
    ctx.check(
        "both panes were scrolled when clicked, the story pane partway into a story",
        all(top > 0 for top in before["scrolled"])
        and before["first"]
        and before["first_story"]
        and before["first_story"]["header"] is not None
        and before["first_story"]["top"] < before["first_story"]["header"],
        before,
    )
    ctx.evaluate("document.getAnimations().forEach(animation => animation.play())")
    snapshot = ghosts["titles"][0]
    story_snapshot = ghosts["stories"][0] if ghosts["stories"] else {"first": None}

    ctx.check(
        "the departing folder list keeps its feed titles",
        snapshot["rows"] and before["feed_titles"] and snapshot["feed_titles"] == before["feed_titles"],
        (before, snapshot),
    )
    ctx.check(
        "the departing folder list keeps its river padding",
        snapshot["padding_left"] == before["padding_left"],
        (before["padding_left"], snapshot["padding_left"]),
    )
    ctx.check(
        "the departing folder list shows the rows that were on screen",
        same_place(before["first"], snapshot["first"]),
        (before["first"], snapshot["first"]),
    )
    ctx.check(
        "the story pane fades out showing the part of the story that was on screen",
        same_place(before["first_story"], story_snapshot["first"]),
        (before["first_story"], story_snapshot["first"]),
    )
    ctx.check(
        "the departing story pane draws its video frame as a box of the same size without loading it",
        embed_box and story_snapshot.get("embeds") == 0 and story_snapshot.get("embed_box") is not None,
        (story_snapshot.get("embeds"), embed_box, story_snapshot.get("embed_box")),
    )
    ctx.check(
        "the story pane's stuck feed header stays where it was stuck",
        before["first_story"]
        and story_snapshot["first"]
        and before["first_story"]["header"] == story_snapshot["first"]["header"],
        (before["first_story"], story_snapshot["first"]),
    )

    page.wait_for_function(RIVER_SHOWN, timeout=30000)
    ctx.wait(800)
    ghosts = ctx.evaluate("window.river_switch_observer.disconnect() || window.river_switch_ghosts")
    ctx.check("the folder list departs once", len(ghosts["titles"]) == 1, len(ghosts["titles"]))
    ctx.check("the story pane departs once", len(ghosts["stories"]) == 1, len(ghosts["stories"]))
    entrances = ctx.evaluate("window.river_switch_entrances")
    fades = [e for e in entrances if e["feed"] == "river:" and e["from"] in (0, "0") and e["duration"] > 0]
    ctx.check("the river's rows fade in from transparent", len(fades) >= 3, entrances[:3])
    ctx.shot("03-all-site-stories")

    # river_switch.py turns animations off in the page only (never saved): the old lists then leave at once.
    ctx.evaluate(WATCH_FOR_GHOSTS)
    ctx.evaluate(
        "window.river_switch_animations = NEWSBLUR.Preferences.animations; NEWSBLUR.Preferences.animations = false"
    )
    folder.locator(".folder_title_text").click()
    page.wait_for_function(
        "NEWSBLUR.reader.active_feed != 'river:' && $('#story_titles .NB-story-title .NB-story-feed:visible').length >= 3",
        timeout=30000,
    )
    ghosts = ctx.evaluate("window.river_switch_observer.disconnect() || window.river_switch_ghosts")
    ctx.evaluate("NEWSBLUR.Preferences.animations = window.river_switch_animations")
    ctx.check(
        "with animations off nothing departs",
        not ghosts["titles"] and not ghosts["stories"],
        (len(ghosts["titles"]), len(ghosts["stories"])),
    )

    # river_switch.py: between two single feeds the story pane still empties at once, as it always has. Both feeds
    # show the Split layout's Feed view so their stories sit in the story pane.
    single_feeds = [feed["id"] for feed in sorted(ctx.visible_feeds(), key=lambda feed: -feed["unread"])][:2]
    for feed_id in single_feeds:
        ctx.evaluate(f"NEWSBLUR.assets.view_setting({feed_id}, {{layout: 'split', view: 'feed'}})")
    open_single_feed(ctx, single_feeds[0])
    ctx.evaluate(WATCH_FOR_GHOSTS)
    open_single_feed(ctx, single_feeds[1])
    ghosts = ctx.evaluate("window.river_switch_observer.disconnect() || window.river_switch_ghosts")
    ctx.check(
        "switching between single feeds leaves the story pane without a fade",
        not ghosts["stories"],
        (single_feeds, len(ghosts["titles"]), len(ghosts["stories"])),
    )

    # river_switch.py: from a single feed into All Site Stories the story pane fades, since a river is on one side.
    ctx.evaluate(WATCH_FOR_GHOSTS)
    page.locator(".NB-feeds-header-river-sites").click()
    page.wait_for_function("window.river_switch_ghosts.titles.length", timeout=5000)
    ghosts = ctx.evaluate("window.river_switch_observer.disconnect() || window.river_switch_ghosts")
    ctx.evaluate("document.getAnimations().forEach(animation => animation.play())")
    ctx.check(
        "leaving a single feed for All Site Stories fades its story pane once",
        len(ghosts["stories"]) == 1,
        len(ghosts["stories"]),
    )
    page.wait_for_function(RIVER_SHOWN, timeout=30000)
    ctx.check_no_page_errors()


def open_single_feed(ctx, feed_id):
    """Clicks the feed's row and waits until its stories fill the Split layout's story pane."""
    ctx.feed_row(feed_id).click()
    ctx.page.wait_for_function(
        f"NEWSBLUR.reader.active_feed == {feed_id} && $('.NB-feed-stories > .NB-feed-story:visible').length > 0",
        timeout=30000,
    )
    ctx.wait(1200)
