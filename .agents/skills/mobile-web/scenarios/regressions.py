"""
regressions.py: bugs found in code review of the phone layout (PR #2189), each confirmed failing
before its fix. smoke.py runs these too.
"""

FEEDS_SCREEN_X = (
    "(() => { var m = getComputedStyle(document.querySelector('.left-pane')).transform; "
    "return m === 'none' ? 0 : parseFloat(m.split(',')[4]); })()"
)
STORY_LISTENERS = (
    "(() => { var s = NEWSBLUR.reader.active_story; "
    "return (s._events['change:selected'] || []).length + (s._events['change'] || []).length; })()"
)
# Everything visible about a row and its contents, to compare a row at rest with the same row
# under a forced :hover and :active.
ROW_LOOKS = """(el) => {
  var looks = {};
  [el].concat(Array.from(el.querySelectorAll('*'))).forEach(function (node, i) {
    var s = getComputedStyle(node);
    looks[i + ' ' + (typeof node.className === 'string' ? node.className : node.tagName)] = [
      s.display, s.visibility, s.opacity, s.backgroundColor, s.color, s.transform, s.boxShadow
    ].join(' | ');
  });
  return looks;
}"""
STORY_ROW = "#story_titles .NB-story-title-container:nth-child(5) .NB-story-title"


def check_regressions(ctx, feed_id):
    """Expects to start on the feeds screen."""
    # The header back button once animated as an edge swipe, sliding the feeds screen in from the
    # trailing edge instead of from behind on the leading edge.
    ctx.open_feed(feed_id)
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(90)
    x = ctx.evaluate(FEEDS_SCREEN_X)
    rtl = ctx.evaluate("document.documentElement.dir === 'rtl'")
    ctx.check("header back slides the feed list in from the leading edge", x > 0 if rtl else x < 0, x)
    ctx.wait(900)

    # Text-mode story pages leaked their StoryDetailView, which kept its bindings on the story.
    ctx.open_feed(feed_id)
    ctx.set_layout("grid")
    ctx.tap_story(1)
    before = ctx.evaluate(STORY_LISTENERS)
    for _ in range(3):
        ctx.page.locator(".NB-mobile-story-view-option[data-view='text']").tap()
        ctx.wait(900)
        ctx.page.locator(".NB-mobile-story-view-option[data-view='feed']").tap()
        ctx.wait(500)
    after = ctx.evaluate(STORY_LISTENERS)
    ctx.check("switching Feed and Text doesn't leak story listeners", after <= before, (before, after))

    # Closing the story screen mid page turn (Safari's own swipe-back is instant) used to finish
    # the turn anyway: it repopulated the pager and selected, so marked read, the next story.
    story_before = ctx.state()["story"]
    ctx.page.locator(".NB-mobile-story-next").tap()
    ctx.wait(60)
    ctx.evaluate("(() => { NEWSBLUR.app.mobile.story_pager.close(); })()")
    ctx.wait(1200)
    pager = ctx.evaluate(
        "({story: !!NEWSBLUR.app.mobile.story_pager.story, "
        "views: $('.NB-mobile-story-page .NB-feed-story-content').length})"
    )
    ctx.check(
        "closing mid page turn leaves the pager empty", not pager["story"] and pager["views"] == 0, pager
    )
    ctx.check("closing mid page turn doesn't select the next story", ctx.state()["story"] == story_before)
    # Leave the story screen through history, the way a pop really happens.
    ctx.page.go_back()
    ctx.wait(1000)

    # A screen change during an edge swipe (reader_opened, feed_reset) used to leave the drag's
    # classes behind, and NB-mobile-transitioning makes every screen ignore taps.
    release = ctx.touch.drag(5, 400, 160, 400, steps=8)
    ctx.wait(60)
    ctx.evaluate("(() => { NEWSBLUR.app.mobile.set_screen(NEWSBLUR.app.mobile.screen); })()")
    release()
    ctx.wait(900)
    stuck = ctx.evaluate(
        "({transitioning: document.body.classList.contains('NB-mobile-transitioning'), "
        "dragging: $('.NB-mobile-dragging').length, "
        "inline: $('.NB-mobile-screen').filter(function () { return this.style.transform; }).length})"
    )
    ctx.check(
        "a screen change mid edge-swipe clears the drag",
        not stuck["transitioning"] and not stuck["dragging"] and not stuck["inline"],
        stuck,
    )
    ctx.set_layout("list")
    check_story_list_pills(ctx)
    check_story_iframe_sandbox(ctx, feed_id)
    check_story_toolbar_fits(ctx)
    check_cross_feed_back(ctx, feed_id)
    check_touch_hover(ctx, feed_id)
    check_discovery_back(ctx)
    check_folder_pills(ctx)


def hover_changes(ctx, selector):
    """What a forced :hover and :active changes on the first match. Touch browsers apply both
    the moment a thumb lands, before they know it's a scroll."""
    cdp = ctx.touch.cdp
    cdp.send("DOM.enable")
    cdp.send("CSS.enable")
    root = cdp.send("DOM.getDocument", {"depth": 0})["root"]["nodeId"]
    node = cdp.send("DOM.querySelector", {"nodeId": root, "selector": selector})["nodeId"]
    row = ctx.page.locator(selector).first
    rest = row.evaluate(ROW_LOOKS)
    cdp.send("CSS.forcePseudoState", {"nodeId": node, "forcedPseudoClasses": ["hover", "active"]})
    ctx.wait(50)
    touched = row.evaluate(ROW_LOOKS)
    cdp.send("CSS.forcePseudoState", {"nodeId": node, "forcedPseudoClasses": []})
    return {key: (rest.get(key), touched.get(key)) for key in rest if rest.get(key) != touched.get(key)}


def check_touch_hover(ctx, feed_id):
    """A thumb landing on a row to scroll the list lit it up with the desktop hover (its manage
    arrow, a darker background, a shrunken grid card), as if half selected. Rows now show a
    press only once a finger rests on them. Expects to be on the story list."""
    feed_row = f".NB-feedlist .feed[data-id='{feed_id}']"
    for theme in ("light", "dark"):
        ctx.evaluate(
            f"(() => {{ document.body.classList.toggle('NB-dark', {str(theme == 'dark').lower()}); }})()"
        )
        for layout in ("list", "grid"):
            ctx.set_layout(layout)
            changes = hover_changes(ctx, STORY_ROW)
            ctx.check(f"a touch doesn't light up a {layout} story ({theme})", not changes, changes)
        changes = hover_changes(ctx, feed_row)
        ctx.check(f"a touch doesn't light up a feed row ({theme})", not changes, changes)
        # Folder titles and the Saved Stories header showed their collapse arrow and pushed their
        # counts aside on hover.
        for name, selector in (
            ("folder title", ".NB-feedlist .folder > .folder_title"),
            ("collapsible header", ".NB-feeds-header:has(.NB-feedlist-collapse-icon)"),
        ):
            if not ctx.evaluate(f"!!document.querySelector({selector!r})"):
                continue
            changes = hover_changes(ctx, selector)
            ctx.check(f"a touch doesn't change a {name} ({theme})", not changes, changes)
    ctx.evaluate("(() => { document.body.classList.remove('NB-dark'); })()")
    ctx.set_layout("list")

    # A finger that rests on a row shows a press, and one that moves off to scroll clears it.
    row = ctx.page.locator(STORY_ROW).first
    ctx.press_point(row)
    story_before = ctx.state()["story"]
    box = row.bounding_box()
    x, y = box["x"] + box["width"] / 2, box["y"] + box["height"] / 2
    pressed = "document.querySelector('" + STORY_ROW + "').classList.contains('NB-mobile-pressed')"
    ctx.touch._send("touchStart", x, y)
    ctx.wait(40)
    early = ctx.evaluate(pressed)
    ctx.wait(200)
    resting = ctx.evaluate(pressed)
    for step in range(1, 6):
        ctx.touch._send("touchMove", x, y - step * 12)
        ctx.wait(16)
    scrolled = ctx.evaluate(pressed)
    ctx.touch._send("touchEnd")
    ctx.wait(300)
    ctx.check(
        "a resting finger presses a row, and scrolling releases it",
        not early and resting and not scrolled,
        {"early": early, "resting": resting, "scrolled": scrolled},
    )
    ctx.check("scrolling off a pressed row doesn't open it", ctx.state()["story"] == story_before)


TOOLBAR_FIT = """(() => {
  var bar = document.querySelector('.NB-mobile-story-toolbar').getBoundingClientRect();
  var buttons = Array.from(document.querySelectorAll('.NB-mobile-story-toolbar .NB-mobile-toolbar-button'));
  var label = document.querySelector('.NB-mobile-story-next-unread span');
  return {
    clipped: buttons.filter(function (b) {
      var r = b.getBoundingClientRect();
      return r.left < bar.left - 0.5 || r.right > bar.right + 0.5 || r.width < 36;
    }).map(function (b) { return b.className; }),
    label_visible: label.getBoundingClientRect().width > 0
  };
})()"""


def check_story_toolbar_fits(ctx):
    """The story toolbar needed about 384px, so 320 and 360px phones clipped Next unread. Every
    button must fit, with a long translation too. Expects to be on the story list."""
    page = ctx.page
    ctx.set_layout("grid")
    ctx.tap_story(1)
    for width in (320, 360):
        page.set_viewport_size({"width": width, "height": 700})
        ctx.wait(400)
        fit = ctx.evaluate(TOOLBAR_FIT)
        ctx.check(
            f"every story toolbar button fits at {width}px", not fit["clipped"] and fit["label_visible"], fit
        )
    ctx.evaluate(
        "(() => { document.querySelector('.NB-mobile-story-next-unread span').textContent = "
        "'N\u00e4chste ungelesene Geschichte'; })()"
    )
    ctx.wait(100)
    fit = ctx.evaluate(TOOLBAR_FIT)
    ctx.check("a long Next unread translation still fits at 320px", not fit["clipped"], fit)
    page.set_viewport_size({"width": ctx.viewport["width"], "height": ctx.viewport["height"]})
    ctx.wait(400)
    ctx.page.locator(".NB-mobile-story-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)
    ctx.set_layout("list")


def cross_into_next_feed(ctx, feed_id, other):
    """Opens a story in feed_id, then does what Next unread does once that feed runs out: opens
    the next feed and selects its story. Returns the first story's hash."""
    ctx.set_layout("grid")
    ctx.tap_story(1)
    story_a = ctx.state()["story"]
    ctx.evaluate(
        f"(() => {{ NEWSBLUR.app.mobile.follow_next_unread(); NEWSBLUR.reader.open_feed({other}); }})()"
    )
    ctx.page.wait_for_function(
        f"NEWSBLUR.reader.active_feed == {other} && NEWSBLUR.assets.stories.length > 0", timeout=30000
    )
    ctx.evaluate("(() => { NEWSBLUR.assets.stories.at(0).set('selected', true); })()")
    ctx.wait(800)
    return story_a


def check_cross_feed_back(ctx, feed_id):
    """Next unread can carry the story screen into the next feed. Back from there to the first
    feed's story entry found its story missing from the next feed's stories, still loaded at
    that moment, and showed the list under a story entry. When the first feed then failed to
    load, the story screen sat on Loading... for good. Expects to be on the story list."""
    feeds = ctx.visible_feeds()
    others = [feed for feed in feeds if feed["id"] != feed_id and (feed["unread"] or feed["shows_read"])]
    if not others:
        ctx.check("cross-feed back has a second feed to test with", False, feeds)
        return
    other = max(others, key=lambda feed: (feed["shows_read"], feed["unread"]))["id"]
    story_a = cross_into_next_feed(ctx, feed_id, other)
    state = ctx.state()
    ctx.check(
        "Next unread's story in the next feed has its own entry",
        state["screen"] == "story" and state["entry"]["screen"] == "story" and state["story"] != story_a,
        state,
    )
    ctx.page.go_back()
    ctx.wait(1200)
    ctx.check("Back from it shows the next feed's list", ctx.state()["screen"] == "titles", ctx.state())
    ctx.page.go_back()
    ctx.page.wait_for_function(f"NEWSBLUR.reader.active_feed == {feed_id}", timeout=30000)
    ctx.wait(2500)
    state = ctx.state()
    ctx.check(
        "Back again reopens the first feed's story",
        state["screen"] == "story" and state["story"] == story_a and state["entry"]["story_hash"] == story_a,
        state,
    )
    if state["screen"] == "story":
        ctx.page.locator(".NB-mobile-story-bar .NB-mobile-bar-back").tap()
        ctx.wait(900)
        ctx.check("and its back button returns to the first feed's list", ctx.state()["screen"] == "titles")

    # The same walk back, with the first feed's request failing.
    cross_into_next_feed(ctx, feed_id, other)
    ctx.page.go_back()
    ctx.wait(1200)
    route = f"**/reader/feed/{feed_id}**"
    ctx.page.route(route, lambda request: request.fulfill(status=500, body="error"))
    try:
        ctx.page.go_back()
        ctx.wait(3000)
        state = ctx.state()
    finally:
        ctx.page.unroute(route)
    ctx.check(
        "a failed load while reopening a story falls back to the list",
        state["screen"] == "titles" and state["entry"]["screen"] == "titles",
        state,
    )
    ctx.evaluate("(() => { NEWSBLUR.reader.open_feed(%d); })()" % feed_id)
    ctx.page.wait_for_function("NEWSBLUR.assets.stories.length > 0", timeout=30000)
    ctx.wait(1200)
    ctx.set_layout("list")


PILL_BAR = """(() => {
  var pane = document.querySelector('.right-pane').getBoundingClientRect();
  var row = document.querySelector('.right-pane .NB-story-titles-header > .feed, .right-pane .NB-story-titles-header > .NB-folder');
  var names = ['NB-feedbar-discover-container', 'NB-feedbar-options-container', 'NB-search-container',
               'NB-story-title-indicator', 'NB-feedbar-mark-feed-read-container'];
  var pills = names.map(function (name) {
    var el = row.querySelector('.' + name);
    if (!el || !el.offsetWidth) return null;
    var r = el.getBoundingClientRect();
    return {name: name, left: r.left, right: r.right, top: Math.round(r.top), bottom: Math.round(r.bottom)};
  }).filter(Boolean);
  var options = row.querySelector('.NB-feedbar-options');
  row.classList.add('NB-mobile-options-measure');
  var natural = options.offsetWidth, room = options.parentNode.clientWidth;
  row.classList.remove('NB-mobile-options-measure');
  var player = document.querySelector('.NB-media-player.NB-mobile-player');
  var player_box = player && player.offsetWidth && getComputedStyle(player).display !== 'none' ? player.getBoundingClientRect() : null;
  return {
    pane: {left: pane.left, right: pane.right, bottom: pane.bottom},
    pills: pills,
    options_fits: natural <= room + 1,
    options_mode: row.classList.contains('NB-mobile-options-icon') ? 'icon' :
      row.classList.contains('NB-mobile-options-compact') ? 'compact' : 'full',
    player_bottom: player_box && Math.round(player_box.bottom)
  };
})()"""


def check_story_list_pills(ctx):
    """The story list's controls were a single scrolling row under the nav bar that hid mark read
    off screen. They now float at the bottom as the iOS app's pills. Expects the story list."""
    page = ctx.page
    for width in (393, 360, 320):
        page.set_viewport_size({"width": width, "height": 760})
        ctx.wait(500)
        bar = ctx.evaluate(PILL_BAR)
        pills, pane = bar["pills"], bar["pane"]
        ordered = all(a["right"] <= b["left"] for a, b in zip(pills, pills[1:]))
        one_row = len({pill["top"] for pill in pills}) == 1
        inside = pills[0]["left"] >= pane["left"] and pills[-1]["right"] <= pane["right"]
        at_bottom = pane["bottom"] - pills[0]["bottom"] <= 12
        ctx.check(
            f"the story list's pills sit in one row along the bottom at {width}px",
            ordered and one_row and inside and at_bottom and pills[-1]["name"].startswith("NB-feedbar-mark"),
            bar,
        )
        ctx.check(f"the story options pill never clips its label at {width}px", bar["options_fits"], bar)
        if bar["player_bottom"]:
            ctx.check(
                f"the Listen player sits above the pills at {width}px",
                bar["player_bottom"] <= pills[0]["top"],
                bar,
            )
    page.set_viewport_size({"width": ctx.viewport["width"], "height": ctx.viewport["height"]})
    ctx.wait(500)

    clearance = ctx.evaluate(
        "(() => { var list = document.querySelector('#story_titles'); list.scrollTop = list.scrollHeight; "
        "var rows = list.querySelectorAll('.NB-story-title'); var last = rows[rows.length - 1].getBoundingClientRect(); "
        "var bar = document.querySelector('.right-pane .NB-feedbar-mark-feed-read-container, "
        ".right-pane .NB-search-container').getBoundingClientRect(); "
        "return {last_bottom: Math.round(last.bottom), bar_top: Math.round(bar.top)}; })()"
    )
    ctx.check(
        "the last story scrolls clear of the pills",
        clearance["last_bottom"] <= clearance["bar_top"],
        clearance,
    )
    ctx.evaluate("(() => { document.querySelector('#story_titles').scrollTop = 0; })()")

    page.locator(".right-pane .NB-search-container").tap()
    ctx.wait(500)
    field = ctx.evaluate(
        "(() => { var input = document.querySelector('.right-pane .NB-story-title-search-input'); "
        "var r = input.getBoundingClientRect(); var bar = document.querySelector('.right-pane .NB-search-container').getBoundingClientRect(); "
        "var hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); "
        "return {focused: document.activeElement === input, width: Math.round(r.width), above: r.bottom <= bar.top, "
        "uncovered: hit === input, pane: document.querySelector('.right-pane').clientWidth}; })()"
    )
    ctx.check(
        "tapping search opens an uncovered field across the bar above the pills",
        field["focused"] and field["above"] and field["uncovered"] and field["width"] >= field["pane"] - 40,
        field,
    )
    ctx.evaluate("(() => { document.activeElement.blur(); })()")
    ctx.wait(400)
    ctx.check(
        "an empty search closes again",
        not ctx.evaluate(
            "document.querySelector('.right-pane .NB-story-titles-header').classList.contains('NB-searching')"
        ),
    )

    page.locator(".right-pane .NB-feedbar-mark-feed-read-expand").tap()
    ctx.wait(300)
    days = ctx.evaluate(
        "(() => ({days: $('.right-pane .NB-feedbar-mark-feed-read-time:visible').length, "
        "others: $('.right-pane .NB-feedbar-options-container:visible, .right-pane .NB-search-container:visible').length}))()"
    )
    page.locator(".right-pane .NB-feedbar-mark-feed-read-expand").tap()
    ctx.wait(300)
    closed = ctx.evaluate("$('.right-pane .NB-feedbar-mark-feed-read-time:visible').length")
    ctx.check(
        "+ lays the mark read day choices across the bar and closes them",
        days["days"] == 4 and days["others"] == 0 and closed == 0,
        (days, closed),
    )


def check_folder_pills(ctx):
    """A named folder wraps its controls in .folder_title (folder_view.js), so they stacked over
    each other, and opening the mark read day choices or confirmation hid the whole wrapper. And
    curated rivers like Global Shared Stories showed a mark read button that throws. Expects the
    feed list."""
    page = ctx.page
    title = page.locator(".NB-feedlist .folder > .folder_title >> visible=true").first
    ctx.press_point(title)
    title.locator(".folder_title_text").tap()
    page.wait_for_function(
        "NEWSBLUR.reader.flags.river_view && NEWSBLUR.assets.stories.length > 0", timeout=30000
    )
    ctx.wait(1200)
    bar = ctx.evaluate(PILL_BAR)
    pills = bar["pills"]
    ordered = all(a["right"] <= b["left"] for a, b in zip(pills, pills[1:]))
    ctx.check(
        "a folder's pills sit in one row along the bottom",
        len(pills) >= 3 and ordered and len({pill["top"] for pill in pills}) == 1,
        bar,
    )
    page.locator(".right-pane .NB-feedbar-mark-feed-read-expand").tap()
    ctx.wait(300)
    days = ctx.evaluate("$('.right-pane .NB-feedbar-mark-feed-read-time:visible').length")
    page.locator(".right-pane .NB-feedbar-mark-feed-read-expand").tap()
    ctx.wait(300)
    ctx.check("a folder's + shows its mark read day choices", days == 4, days)
    # The confirmation depends on a preference, set here in the page only.
    ctx.evaluate("(() => { NEWSBLUR.Preferences.mark_read_river_confirm = 'folders_only'; })()")
    page.locator(".right-pane .NB-feedbar-mark-feed-read").tap()
    ctx.wait(400)
    confirm = ctx.evaluate(
        "(() => ({yes: $('.right-pane .NB-confirm-yes:visible').length, no: $('.right-pane .NB-confirm-no:visible').length}))()"
    )
    ctx.check("a folder's mark read confirmation shows Yes and No", confirm == {"yes": 1, "no": 1}, confirm)
    if confirm["no"]:
        page.locator(".right-pane .NB-confirm-no").tap()
        ctx.wait(300)

    ctx.evaluate("(() => { NEWSBLUR.reader.open_river_blurblogs_stories({global: true}); })()")
    page.wait_for_function("NEWSBLUR.reader.active_feed == 'river:global'", timeout=30000)
    ctx.wait(2000)
    shown = ctx.evaluate("$('.right-pane .NB-feedbar-mark-feed-read-container:visible').length")
    ctx.check("Global Shared Stories has no mark read button, as on desktop", shown == 0, shown)
    page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(1200)


def check_story_iframe_sandbox(ctx, feed_id):
    """The phone Story view's iframe once had allow-same-origin. /rss_feeds/original_story serves
    the publisher's page from NewsBlur's origin, so its scripts could act as the signed-in reader.
    Expects to be on the story list."""
    ctx.set_layout("grid")
    ctx.tap_story(1)
    # The test feed may block framing; the iframe's sandbox is what matters, so allow it here.
    ctx.evaluate(
        f"(() => {{ NEWSBLUR.assets.get_feed({feed_id}).set('disabled_page', false, {{silent: true}}); "
        "NEWSBLUR.app.mobile.story_pager.update_chrome(); })()"
    )
    ctx.page.locator(".NB-mobile-story-view-option[data-view='story']").tap()
    ctx.wait(1500)
    sandbox = ctx.evaluate(
        "(() => { var f = document.querySelector('.NB-mobile-story-page-current iframe'); "
        "return f ? {sandbox: f.getAttribute('sandbox'), reachable: !!f.contentDocument} : null; })()"
    )
    ctx.check(
        "the Story view iframe can't reach the reader's origin",
        sandbox and "allow-same-origin" not in sandbox["sandbox"] and not sandbox["reachable"],
        sandbox,
    )
    ctx.page.locator(".NB-mobile-story-view-option[data-view='feed']").tap()
    ctx.wait(500)
    ctx.page.locator(".NB-mobile-story-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)
    ctx.set_layout("list")


def check_discovery_back(ctx):
    """Add + Discover's tab entries were tagged as the feed list, so browser Back between two tabs
    hid discovery and showed the feeds. Expects to be on the story list."""
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(900)
    ctx.page.locator(".NB-feeds-header-add-site").tap()
    ctx.wait(2500)
    # A phone shows only the current tab; the rest live under More (add_site_view.js). Visit two
    # other tabs so Back crosses an entry written by a tab change.
    paths = [ctx.evaluate("location.pathname")]
    tags = []
    for index in (1, 2):
        ctx.page.locator(".NB-add-site-tabs-overflow-button").tap()
        ctx.wait(500)
        ctx.page.locator(".NB-add-site-tabs-overflow-item >> visible=true").nth(index).tap()
        ctx.wait(1200)
        paths.append(ctx.evaluate("location.pathname"))
        tags.append(ctx.state()["entry"]["screen"])
    ctx.check("discovery tabs each write their own history entry", len(set(paths)) == 3, paths)
    ctx.check("discovery tab entries belong to the story list screen", tags == ["titles", "titles"], tags)
    ctx.page.go_back()
    ctx.wait(1200)
    state = ctx.state()
    ctx.check(
        "browser Back between discovery tabs stays in Add + Discover",
        state["screen"] == "titles" and ctx.evaluate("!!NEWSBLUR.reader.flags.add_site_view"),
        state,
    )
    ctx.page.locator(".NB-mobile-titles-bar .NB-mobile-bar-back").tap()
    ctx.wait(1200)


def run(ctx):
    ctx.login("/")
    check_regressions(ctx, ctx.pick_feed())
    ctx.check_no_page_errors()
