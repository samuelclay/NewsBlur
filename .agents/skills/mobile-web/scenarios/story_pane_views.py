"""
story_pane_views.py: on desktop, the Split layout's story pane holds the Original, Feed, Text and Story views side
by side, and reader.js position_story_pane moves it to show one. When the reader picks the view itself, the pane
jumps straight there: selecting a story in a folder whose site keeps a different view than the folder, or opening
a folder whose saved view differs from the one showing. Sliding across from the old view looked like the story
scrolling in from the side. Choosing a view with its taskbar button still slides between them.
"""

from desktop import VIEWPORT  # noqa: F401  (desktop.py: a 1440x900 window without touch)

# story_pane_views.py samples the story pane's left edge on every frame until stop_pane_trace() is called.
START_TRACE = """(() => {
    const pane = document.querySelector('#story_pane .NB-story-pane-container');
    window.pane_trace = [pane.style.left];
    window.pane_tracing = true;
    (function sample() {
        window.pane_trace.push(pane.style.left);
        if (window.pane_tracing) requestAnimationFrame(sample);
    })();
})()"""
STOP_TRACE = "(() => { window.pane_tracing = false; return window.pane_trace; })()"

FOLDER_SHOWN = (
    "NEWSBLUR.reader.flags.river_view && $('#story_titles .NB-story-title:visible').length >= 3 && "
    "!NEWSBLUR.reader.active_story"
)


def in_between(trace):
    """Left edges the pane passed through on its way from the first value to the last."""
    return [left for left in trace if left not in (trace[0], trace[-1])]


def traced(ctx, action, ms=900):
    ctx.evaluate(START_TRACE)
    action()
    ctx.wait(ms)
    return ctx.evaluate(STOP_TRACE)


def run(ctx):
    page = ctx.page
    ctx.login("/")
    # story_pane_views.py opens folders with no story selected, so the folder's own view shows first. run.py puts
    # the account's preferences back afterwards.
    ctx.evaluate("NEWSBLUR.assets.preference('open_feed_action', 0)")
    ctx.check(
        "animations are on, so a slide would show",
        ctx.evaluate(
            "NEWSBLUR.assets.preference('animations') !== false && !NEWSBLUR.assets.preference('reduce_motion')"
        ),
    )
    folder = page.locator(".NB-feedlist .folder > .folder_title >> visible=true").first
    folder_title = folder.locator(".folder_title_text")
    folder_title.click()
    page.wait_for_function(FOLDER_SHOWN, timeout=30000)

    # story_pane_views.py gives the folder the Text view and the first story's site the Feed view, in the Split
    # layout, then opens the folder again so it shows the Text view with no story selected.
    river = ctx.evaluate("NEWSBLUR.reader.active_feed")
    story_feed = ctx.evaluate("NEWSBLUR.assets.stories.at(0).get('story_feed_id')")
    ctx.evaluate(
        f"""(() => {{
        NEWSBLUR.assets.view_setting('{river}', {{layout: 'split', view: 'text'}});
        NEWSBLUR.assets.view_setting({story_feed}, {{view: 'feed'}});
        NEWSBLUR.reader.switch_story_layout('split');
    }})()"""
    )
    ctx.evaluate("NEWSBLUR.reader.open_river_stories()")
    page.wait_for_function("NEWSBLUR.reader.active_feed == 'river:'", timeout=30000)
    ctx.wait(1200)
    folder_title.click()
    page.wait_for_function(FOLDER_SHOWN, timeout=30000)
    ctx.wait(1200)
    ctx.check(
        "the folder opens in the Text view with no story selected",
        ctx.evaluate("NEWSBLUR.reader.story_view") == "text",
        ctx.evaluate("NEWSBLUR.reader.story_view"),
    )

    title = ctx.evaluate(
        """(() => {
        const rect = NEWSBLUR.assets.stories.at(0).story_title_view.$('.NB-storytitles-title')[0].getBoundingClientRect();
        return {x: rect.left + Math.min(rect.width / 2, 120), y: rect.top + rect.height / 2};
    })()"""
    )
    trace = traced(ctx, lambda: page.mouse.click(title["x"], title["y"]))
    ctx.check(
        "selecting a story whose site keeps the Feed view switches the story pane to it",
        ctx.evaluate("NEWSBLUR.reader.story_view") == "feed" and trace[0] != trace[-1],
        (ctx.evaluate("NEWSBLUR.reader.story_view"), trace[0], trace[-1]),
    )
    ctx.check(
        "the story pane jumps to the story's view instead of sliding across",
        not in_between(trace),
        in_between(trace)[:8],
    )
    ctx.shot("01-story-selected")

    # story_pane_views.py: the Text button is a choice made by hand, so the pane slides over to it.
    text_button = page.locator(".NB-taskbar-view .task_view_text >> visible=true").first
    trace = traced(ctx, lambda: text_button.click())
    ctx.check(
        "choosing the Text view with its button slides the story pane over",
        len(set(in_between(trace))) >= 3,
        (trace[0], trace[-1], len(set(in_between(trace)))),
    )
    ctx.evaluate(f"NEWSBLUR.assets.view_setting({story_feed}, {{view: 'feed'}})")

    # story_pane_views.py: opening the folder again goes back to its Text view from the story's Feed view.
    page.locator(".NB-taskbar-view .task_view_feed >> visible=true").first.click()
    ctx.wait(1200)
    trace = traced(ctx, lambda: folder_title.click(), ms=1500)
    ctx.check(
        "opening a folder that keeps another view switches the story pane to it",
        ctx.evaluate("NEWSBLUR.reader.story_view") == "text" and trace[0] != trace[-1],
        (ctx.evaluate("NEWSBLUR.reader.story_view"), trace[0], trace[-1]),
    )
    ctx.check(
        "the story pane jumps to the folder's view instead of sliding across",
        not in_between(trace),
        in_between(trace)[:8],
    )
    ctx.check_no_page_errors()
