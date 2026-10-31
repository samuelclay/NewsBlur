"""
next_unread.py: Next unread on the story screen reads to the end of a feed and moves on to the
next feed with unreads, staying on the story screen. Back then lands on that feed's list.

It marks every story it passes as read in the dev account, so it only starts in a feed with a
few unread stories (MAX_UNREAD) and run.py all skips it. Mark a few stories unread in a feed that
has another unread feed below it if no feed qualifies.
"""

MAX_UNREAD = 6


def run(ctx):
    page = ctx.page
    ctx.login("/")
    candidates = sorted(
        (feed for feed in ctx.visible_feeds() if 1 <= feed["unread"] <= MAX_UNREAD),
        key=lambda feed: feed["unread"],
    )
    if ctx.requested_feed:
        candidates = [feed for feed in candidates if feed["id"] == ctx.requested_feed]
    if not ctx.check(f"a visible feed has 1 to {MAX_UNREAD} unread stories", candidates):
        return
    feed_id, unread = candidates[0]["id"], candidates[0]["unread"]
    print(f"   starting in feed {feed_id} with {unread} unread")
    ctx.open_feed(feed_id)
    # reader.js get_next_unread_feed only walks visible feed rows, as on desktop.
    next_feed = ctx.evaluate(
        f"(() => {{ var next = NEWSBLUR.reader.get_next_unread_feed(1); "
        f"return next && next.length && next.data('id') != {feed_id} ? next.data('id') : null; }})()"
    )
    if not ctx.check("another visible feed below it has unread stories", next_feed):
        return
    ctx.set_layout("grid")
    first_unread = ctx.evaluate(
        "[...document.querySelectorAll('#story_titles .NB-story-title')].findIndex(function (e) { return !e.classList.contains('read'); })"
    )
    ctx.tap_story(max(first_unread, 0))

    for _ in range(unread + 1):
        if ctx.state()["path"].find(f"/site/{feed_id}/") != 0:
            break
        page.locator(".NB-mobile-story-next-unread").tap()
        ctx.wait(3500)
    state = ctx.state()
    ctx.shot("01-next-feed")
    ctx.check("Next unread moved on to another feed", f"/site/{feed_id}/" not in state["path"], state)
    ctx.check(
        "and stayed on the story screen",
        state["screen"] == "story" and state["entry"]["screen"] == "story",
        state,
    )
    page.go_back()
    ctx.wait(1200)
    state = ctx.state()
    ctx.check(
        "back lands on the new feed's story list",
        state["screen"] == "titles" and f"/site/{feed_id}/" not in state["path"],
        state,
    )
    ctx.check_no_page_errors()
