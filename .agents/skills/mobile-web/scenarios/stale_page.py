"""
stale_page.py: opening a feed or folder cancels the page of stories still loading for the last one.

The story list loads its next page through assetmodel.js's feed_page ajax group, one request at a time. A page
still in flight when a feed or folder opens used to keep running: the new first page queued behind it, and
when the same folder or feed was reopened the old page's stories were added to the fresh list, so it opened
showing page 4. Each case holds the server's answer for every page after the first, reopens, then releases.
"""

import json
from urllib.parse import parse_qs, urlparse

from desktop import VIEWPORT  # noqa: F401  (desktop.py: a 1440x900 window without touch)

SETTLED = "!NEWSBLUR.reader.flags.opening_feed && NEWSBLUR.assets.stories.length > 0"


def page_of(request):
    """The page a story request asks for. make_request (assetmodel.js) turns a GET whose parameters run past
    2000 characters, like a big folder's feed list, into a POST."""
    query = parse_qs(urlparse(request.url).query)
    if request.post_data:
        query.update(parse_qs(request.post_data))
    return int(query.get("page", ["1"])[0])


class Pages:
    """Holds every request for a later page of stories and records what the page asks for meanwhile."""

    def __init__(self, ctx, url_glob):
        self.ctx, self.url_glob = ctx, url_glob
        self.held, self.first_pages, self.failed = [], [], []
        ctx.page.on("request", self.on_request)
        ctx.page.on("requestfailed", self.on_failed)
        ctx.page.route(url_glob, self.on_route)

    def on_route(self, route):
        if page_of(route.request) >= 2:
            self.held.append(route)
        else:
            route.continue_()

    def on_request(self, request):
        if self.matches(request) and page_of(request) == 1:
            self.first_pages.append(request)

    def on_failed(self, request):
        if self.matches(request):
            self.failed.append(request)

    def matches(self, request):
        return urlparse(request.url).path.startswith(self.url_glob.strip("*").split("**")[0])

    def wait_for_held(self):
        if not self.held:
            self.ctx.evaluate("NEWSBLUR.reader.load_page_of_feed_stories({scroll_to_loadbar: false})")
        for _ in range(40):
            if self.held:
                return self.held[0]
            self.ctx.wait(250)
        raise RuntimeError(f"No later page of {self.url_glob} was requested")

    def wait_for_new_list(self, stale_routes):
        """Waits for the reopened list's first page. A short list then asks for its own next page to fill the
        screen, which is held like every later page, so it stays loading until the case ends."""
        for _ in range(120):
            own_page_held = any(route not in stale_routes for route in self.held)
            if self.ctx.evaluate(SETTLED):
                return
            if own_page_held and self.ctx.evaluate("NEWSBLUR.assets.stories.length > 0"):
                return
            self.ctx.wait(250)
        raise RuntimeError(f"The reopened list never loaded from {self.url_glob}")

    def release(self, routes):
        """Sends each held request on to the server and returns the story hashes it answered with. A request
        the page cancelled can't be answered any more, which is what the fix is for."""
        hashes = set()
        for route in routes:
            try:
                response = route.fetch()
                hashes.update(story["story_hash"] for story in json.loads(response.text()).get("stories", []))
                route.fulfill(response=response)
            except Exception:
                pass
        return hashes

    def stop(self):
        self.release(list(self.held))
        self.ctx.page.unroute_all(behavior="ignoreErrors")
        self.ctx.page.remove_listener("request", self.on_request)
        self.ctx.page.remove_listener("requestfailed", self.on_failed)


def reopen_case(ctx, name, url_glob, open_first, open_next):
    page = ctx.page
    open_first()
    page.wait_for_function(SETTLED, timeout=30000)
    ctx.wait(1500)
    pages = Pages(ctx, url_glob)
    try:
        page.wait_for_function("!NEWSBLUR.reader.flags.opening_feed", timeout=30000)
        stale = pages.wait_for_held()
        stale_routes = list(pages.held)
        pages.first_pages.clear()

        open_next()
        ctx.wait(1500)
        ctx.check(
            f"{name}: the next page still loading is cancelled",
            stale.request in pages.failed,
            [request.url[:80] for request in pages.failed],
        )
        ctx.check(
            f"{name}: the first page is requested without waiting for the old page",
            len(pages.first_pages) >= 1,
            len(pages.first_pages),
        )

        stale_hashes = pages.release(stale_routes)
        pages.wait_for_new_list(stale_routes)
        ctx.wait(1500)
        shown = set(ctx.evaluate("NEWSBLUR.assets.stories.pluck('story_hash')"))
        ctx.check(
            f"{name}: no stories from the old page land in the new list",
            not (shown & stale_hashes),
            (len(shown & stale_hashes), len(stale_hashes)),
        )
        ctx.shot(name.replace(" ", "-"))
    finally:
        pages.stop()


def run(ctx):
    page = ctx.page
    ctx.login("/")
    folders = page.locator(".NB-feedlist .folder > .folder_title >> visible=true")

    def click_folder(index):
        return lambda: folders.nth(index).locator(".folder_title_text").click()

    reopen_case(ctx, "same folder", "**/reader/river_stories**", click_folder(0), click_folder(0))
    reopen_case(ctx, "another folder", "**/reader/river_stories**", click_folder(0), click_folder(1))

    feed_id = ctx.pick_feed()

    def click_feed():
        row = ctx.feed_row(feed_id)
        row.scroll_into_view_if_needed()
        row.click()

    reopen_case(ctx, "same feed", f"**/reader/feed/{feed_id}**", click_feed, click_feed)
    ctx.check_no_page_errors()
