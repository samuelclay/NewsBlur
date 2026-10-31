"""
harness.py: Runs one mobile-web scenario inside the Playwright docker image
(.agents/skills/mobile-web/run.py starts it). Not meant to be run on the host.

A scenario is scenarios/<name>.py with an optional VIEWPORT dict and a run(ctx) function.
ctx (Context below) wraps the Playwright page with the helpers every scenario needs: login,
screenshots, PASS/FAIL checks, real touch gestures over CDP, and reads of the phone layout's
state (views/mobile_layout_view.js).
"""

import argparse
import importlib.util
import pathlib
import sys
import traceback
from urllib.parse import quote

from playwright.sync_api import sync_playwright

SCENARIO_DIR = pathlib.Path(__file__).resolve().parent / "scenarios"
BASE_URL = "https://localhost"
IPHONE_UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
    "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
)
# harness.py: an iPhone 15-sized viewport with touch, the default for every scenario.
PHONE = {
    "width": 393,
    "height": 852,
    "mobile": True,
    "touch": True,
    "user_agent": IPHONE_UA,
    "locale": "en-US",
}


class Touch:
    """Real touch events over the DevTools protocol, so the browser also derives pointer events
    and touch-action applies exactly as on a phone."""

    def __init__(self, page):
        self.page = page
        self.cdp = page.context.new_cdp_session(page)

    def _send(self, kind, x=None, y=None):
        points = [] if x is None else [{"x": x, "y": y}]
        self.cdp.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": points})

    def drag(self, x1, y1, x2, y2, steps=12, step_ms=16):
        """Presses and moves without lifting. Returns a function that lifts the finger."""
        self._send("touchStart", x1, y1)
        for i in range(1, steps + 1):
            self._send("touchMove", x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
            self.page.wait_for_timeout(step_ms)
        return lambda: self._send("touchEnd")

    def swipe(self, x1, y1, x2, y2, steps=12, step_ms=16):
        self.drag(x1, y1, x2, y2, steps, step_ms)()

    def long_press(self, x, y, ms=700):
        self._send("touchStart", x, y)
        self.page.wait_for_timeout(ms)
        self._send("touchEnd")


class Context:
    def __init__(self, page, viewport, args):
        self.page = page
        self.viewport = viewport
        self.args = args.args
        self.out = pathlib.Path(args.out)
        self.user = args.user
        self.requested_feed = args.feed
        self.scenario = args.scenario
        self.touch = Touch(page) if viewport.get("touch") else None
        self.errors = []
        self.results = []
        page.on("pageerror", lambda error: self.errors.append(str(error)))

    # ============
    # = Basics   =
    # ============

    def evaluate(self, js):
        return self.page.evaluate(js)

    def wait(self, ms):
        self.page.wait_for_timeout(ms)

    def shot(self, name):
        path = self.out / f"{self.scenario}-{name}.png"
        self.page.screenshot(path=str(path))
        print(f"shot {path.name}")

    def check(self, name, passed, detail=""):
        self.results.append((name, bool(passed)))
        if passed:
            print(f"PASS {name}")
        else:
            print(f"FAIL {name}" + (f"  [{detail}]" if detail != "" else ""))
        return passed

    def check_no_page_errors(self):
        self.check("no page errors", not self.errors, self.errors[:3])

    def login(self, path="/"):
        url = f"{BASE_URL}/reader/dev/autologin/{self.user}/?next={quote(path, safe='/?=&')}"
        self.page.goto(url, wait_until="load", timeout=90000)
        self.page.wait_for_function(
            "window.NEWSBLUR && NEWSBLUR.reader && NEWSBLUR.assets.feeds && NEWSBLUR.assets.feeds.length",
            timeout=60000,
        )
        self.wait(1500)

    def use_dark_theme(self):
        """Applies the dark theme in this page only, without saving it to the account."""
        self.evaluate("(() => { NEWSBLUR.Preferences.theme = 'dark'; NEWSBLUR.reader.load_theme(); })()")
        self.wait(2200)

    # ===================
    # = Phone layout    =
    # ===================

    def state(self):
        """Where the phone layout thinks it is, and the history entry it wrote."""
        return self.evaluate(
            """(() => ({
                active: !!(NEWSBLUR.app.mobile && NEWSBLUR.app.mobile.is_active()),
                screen: NEWSBLUR.app.mobile && NEWSBLUR.app.mobile.screen,
                depth: NEWSBLUR.app.mobile && NEWSBLUR.app.mobile.depth,
                path: location.pathname + location.search,
                entry: history.state && history.state.nb_mobile,
                story: NEWSBLUR.reader.active_story && NEWSBLUR.reader.active_story.get('story_hash'),
                transitioning: document.body.classList.contains('NB-mobile-transitioning')
            }))()"""
        )

    def screen_left(self, selector):
        """Left edge of a screen in px; 0 means it fills the viewport."""
        return self.evaluate(
            f"(() => {{ var el = document.querySelector('{selector}'); "
            f"return el ? Math.round(el.getBoundingClientRect().left) : null; }})()"
        )

    VISIBLE_FEEDS = """(() => {
        var feeds = [];
        document.querySelectorAll('.NB-feedlist li.feed').forEach(function (row) {
            if (!row.offsetParent) return;
            var feed = NEWSBLUR.assets.get_feed(parseInt(row.dataset.id, 10));
            // harness.py: muted (inactive) feeds and broken ones have no stories to swipe through.
            if (!feed || feed.get('has_exception') || !feed.get('active')) return;
            feeds.push({
                id: feed.id,
                unread: (feed.get('nt') || 0) + (feed.get('ps') || 0),
                shows_read: NEWSBLUR.assets.view_setting(feed.id, 'read_filter') == 'all',
                recent: feed.get('stories_last_month') || 0
            });
        });
        return feeds;
    })()"""

    def visible_feeds(self):
        """Active feed rows on screen as {id, unread, shows_read, recent}. When the account hides read feeds and
        everything is read, the list is empty, so this switches the feed list to All first."""
        feeds = self.evaluate(self.VISIBLE_FEEDS)
        if not feeds:
            self.page.locator(".NB-intelligence-slider-red").tap()
            self.wait(1200)
            feeds = self.evaluate(self.VISIBLE_FEEDS)
        return feeds

    def pick_feed(self):
        """The --feed given to run.py, or the visible feed with the most unread stories, then the
        busiest one that shows read stories too, so there are always stories to swipe through."""
        if self.requested_feed:
            return self.requested_feed
        feeds = self.visible_feeds()
        if not feeds:
            raise RuntimeError("No visible feed to test with; pass --feed to run.py")
        best = max(
            feeds, key=lambda feed: (feed["unread"] > 0, feed["shows_read"], feed["unread"], feed["recent"])
        )
        return best["id"]

    def press_point(self, locator):
        """Scrolls an element to the middle of its scroller and returns its center. A row only
        partly in view has coordinates over whatever sits below the list, such as the Listen
        player in the feed list's footer, and a touch there lands on that instead."""
        locator.evaluate("(el) => el.scrollIntoView({block: 'center'})")
        self.wait(300)
        box = locator.bounding_box()
        return box["x"] + min(150, box["width"] / 2), box["y"] + min(20, box["height"] / 2)

    def long_press(self, locator):
        x, y = self.press_point(locator)
        self.touch.long_press(x, y)

    def feed_title(self, feed_id):
        return self.evaluate(f"NEWSBLUR.assets.get_feed({feed_id}).get('feed_title')")

    def feed_row(self, feed_id):
        return self.page.locator(f".NB-feedlist .feed[data-id='{feed_id}'] >> visible=true").first

    def open_feed(self, feed_id, min_stories=4):
        """Taps the feed's row in the feed list and waits for its stories. A feed that hides read
        stories may show too few to swipe through, so it is switched to all stories (prefs_guard.py
        puts the read filter back after the run)."""
        row = self.feed_row(feed_id)
        self.press_point(row)
        row.tap()
        self.page.wait_for_function(
            "NEWSBLUR.assets.stories.length > 0 || NEWSBLUR.assets.stories.no_more_stories", timeout=30000
        )
        self.wait(1200)
        if self.evaluate("NEWSBLUR.assets.stories.length") < min_stories:
            self.evaluate(
                f"(() => {{ NEWSBLUR.assets.view_setting({feed_id}, {{read_filter: 'all'}}); "
                "NEWSBLUR.reader.reload_feed({}); })()"
            )
            self.page.wait_for_function(f"NEWSBLUR.assets.stories.length >= {min_stories}", timeout=30000)
            self.wait(1200)

    def set_layout(self, layout):
        """Picks the open feed's phone layout, list (inline), page (full screen) or grid, from the
        nav bar's layout menu."""
        if self.evaluate("NEWSBLUR.app.mobile.layout()") == layout:
            return
        self.page.locator(".NB-mobile-layout-toggle").tap()
        self.wait(500)
        self.page.locator(f".NB-mobile-layout-option[data-layout='{layout}']").tap()
        self.wait(1400)

    def tap_story(self, index):
        titles = self.page.locator("#story_titles .NB-story-title")
        index = min(index, titles.count() - 1)
        titles.nth(index).tap()
        self.wait(1300)

    def close_overlays(self):
        self.evaluate(
            "(() => { if ($.modal && $.modal.close) $.modal.close(); "
            "if (NEWSBLUR.ReaderPopover.close) NEWSBLUR.ReaderPopover.close(); })()"
        )
        self.wait(600)


def load_scenario(name):
    spec = importlib.util.spec_from_file_location(f"scenario_{name}", SCENARIO_DIR / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.path.insert(0, str(SCENARIO_DIR))
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--user", default="samuel")
    parser.add_argument("--out", default="/out")
    parser.add_argument("--args", default="")
    parser.add_argument("--feed", type=int)
    args = parser.parse_args()

    scenario = load_scenario(args.scenario)
    viewport = dict(PHONE, **getattr(scenario, "VIEWPORT", {}))
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        context = browser.new_context(
            viewport={"width": viewport["width"], "height": viewport["height"]},
            device_scale_factor=2,
            is_mobile=viewport["mobile"],
            has_touch=viewport["touch"],
            user_agent=viewport["user_agent"],
            locale=viewport["locale"],
            ignore_https_errors=True,
        )
        page = context.new_page()
        ctx = Context(page, viewport, args)
        crashed = False
        try:
            scenario.run(ctx)
        except Exception:
            crashed = True
            traceback.print_exc()
            try:
                ctx.shot("crash")
            except Exception:
                print("harness.py: could not capture a crash screenshot", file=sys.stderr)
        finally:
            browser.close()

    failed = [name for name, passed in ctx.results if not passed]
    print(f"{args.scenario}: {len(ctx.results) - len(failed)}/{len(ctx.results)} checks passed")
    sys.exit(1 if crashed or failed else 0)


if __name__ == "__main__":
    main()
