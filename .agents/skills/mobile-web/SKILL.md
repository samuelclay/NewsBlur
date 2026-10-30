---
name: mobile-web
description: End-to-end tests and screenshots of the NewsBlur web reader's phone layout (body.NB-mobile at 768px and narrower, or a phone held sideways). Use when changing anything the phone layout touches (views/mobile_*.js, css/reader/mobile.css, common/mobile_utils.js, reader.js layout code, story title/detail views, modals or popovers), when asked to test or screenshot the site on a phone, or to attach phone screenshots to a PR. Runs Playwright with iPhone emulation and real touch events against a running dev stack, and restores the dev account's settings afterwards.
---

# Mobile web

The web reader turns into a phone app at 768px and narrower, and on short touch screens such as a phone held sideways. The desktop panes become stacked full-screen screens that slide over one another: feed list, dashboard, story list, and a swipeable story screen for grid layouts. `views/mobile_layout_view.js` runs it, with the gesture and history helpers in `common/mobile_utils.js` and every style in `css/reader/mobile.css`.

This skill drives that layout the way a thumb would, in the Playwright docker image on the stack's network. Swipes, edge swipes, long presses and pull to refresh are real CDP touch events, so `touch-action` and pointer events behave as on a phone.

## Running

From the repo root or a worktree, with its stack running (`make`, or `make worktree` in a worktree):

```bash
python3 .agents/skills/mobile-web/run.py smoke                 # the regression suite
python3 .agents/skills/mobile-web/run.py all                   # every scenario except next_unread
python3 .agents/skills/mobile-web/run.py tour --args dark --out /tmp/phone-dark
python3 .agents/skills/mobile-web/run.py smoke --workspace mobile-web --feed 476
```

The workspace defaults to the checkout you run it from. Each scenario prints `PASS` and `FAIL` lines and a count. Any failure or exception makes `run.py` exit non-zero, and a crash leaves a `<scenario>-crash.png` behind. Screenshots go to `--out` (default `/tmp/newsblur-mobile-web`) as `<scenario>-<name>.png`. Read them after a run; a passing check does not prove a screen looks right.

Node unit tests for the pure helpers are separate: `node --test node/tests/mobile_utils.test.js`.

## Scenarios

| Scenario | What it covers |
|---|---|
| `smoke` | Every reader flow with assertions: screens and history, the Dashboard screen, long-press sheets, list inline expansion, grid → story screen, swipe paging, toolbar previous/next, Text view, Train modal, edge-swipe back (cancel and complete), browser back/forward, back from a search, pull to refresh, modal close, then `regressions` |
| `regressions` | Bugs from code review, each confirmed failing before its fix. Add a check here for every phone layout bug you fix |
| `tour` | Screenshots of every screen in order. `--args dark` for the dark theme, applied in the page and never saved |
| `modals` | The 19 modals plus the activity sheet: each opens full width with nothing hanging off the screen |
| `player` | The Listen and podcast player floats as a one-row bar above each screen's toolbar, opens as a bottom sheet and closes from the shade. Uses whatever the account's player already holds and skips when it's empty |
| `rtl` | Arabic: screens slide from the left, swipe directions reverse, the edge swipe starts at the right edge |
| `landscape` | 852×393 keeps the phone layout |
| `tablet` | iPad portrait gets the phone layout with a two-column grid |
| `resize` | Narrowing a desktop window switches to the phone layout with the open feed, widening switches back, and the feed's desktop layout is untouched |
| `desktop` | A desktop window never sees the phone layout, its chrome, or tagged history entries |
| `next_unread` | Next unread reads to the end of a feed, moves on to the next feed with unreads and stays on the story screen. It marks every story it passes as read, so `all` skips it. It only starts in a visible feed with 1 to 6 unread stories that has another unread feed below it, and fails up front when there is none |

Scenarios pick the active visible feed with the most unread stories, then the busiest one that shows read stories too. When the account hides read feeds and everything is read, the harness switches the feed list to All first. A feed showing fewer than four stories is switched to all stories so there is something to swipe through. Both changes save to the account and are put back after the run. Pass `--feed <id>` to choose the feed yourself. A scenario is `scenarios/<name>.py` with a `run(ctx)` function and an optional `VIEWPORT` override. `harness.py` documents the `ctx` helpers (`login`, `open_feed`, `set_layout`, `tap_story`, `state`, `check`, `shot`, and `ctx.touch.swipe/drag/long_press`).

## Settings the runs change

Toggling list and grid, choosing Feed or Text on the story screen, and switching themes all save to the dev account. Every worktree shares one database, so these are the same settings the main checkout shows. `run.py` snapshots the account's `view_settings` and `preferences` in the web container before the first scenario, restores every key that changed afterwards (even when a scenario fails), and prints what it put back. Don't run scenarios with the `run_in_background` flag and then edit settings in the browser at the same time; the restore would undo your edits.

Other data does change and is not restored: opening stories marks them read, and `next_unread` reads through a whole feed.

## Gotchas

- **Adding a stylesheet to `newsblur_web/assets.yml`** needs `docker restart newsblur_web_<worktree>` before the page links it. JavaScript under `media/js/newsblur/views/` is picked up by glob, with no restart.
- **A tap during momentum scrolling only stops the scroll**, as on a real phone. Wait about a second after a vertical swipe before tapping a button, or the tap is swallowed.
- **`page.evaluate` invokes a snippet whose value is a function.** Wrap snippets that assign functions in `(() => { ... })()`.
- **A feed can appear in several folders.** Locate rows with `>> visible=true` (`ctx.feed_row` does).
- **Emulated Chromium is not Safari.** iOS Safari's own edge swipe-back, rubber banding and the soft keyboard still need a real iPhone. When the browser animates its own swipe-back, popstate carries `hasUAVisualTransition` and the layout switches screens without a second slide.
- **CDP touch events never set `:hover` or `:active`**, but real phones apply both the moment a thumb lands. To test what a touch looks like, force the states with `CSS.forcePseudoState` (`hover_changes` in `scenarios/regressions.py`).
- **A `backdrop-filter`, like `transform` or `filter`, makes an element the containing block** of its absolutely positioned descendants. The story list's search pill drops its glass while its field is open for that reason.

## Screenshots on a PR

Attach images with `gh` 2.99.0 or newer, referencing the same local paths in the body so they get rewritten to hosted URLs. Build the argument list as an array; zsh does not split a string of flags:

```bash
ARGS=(); for f in /tmp/newsblur-mobile-web/tour-light-*.png; do ARGS+=(--attach "$f"); done
gh pr comment <number> --body-file body.md "${ARGS[@]}"
```
