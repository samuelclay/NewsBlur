"""reduce_motion.py: saved Reduce motion removes movement while retaining reader fades."""

RECORD_ANIMATIONS = """(() => {
    window.readerAnimationSamples = [];
    const original = Element.prototype.animate;
    Element.prototype.animate = function(frames, options) {
        const region = this.closest('.NB-feedlist') ? 'feeds' :
            this.closest('.NB-feed-story-content, .NB-feed-story, .NB-story-detail') ? 'detail' :
            this.closest('#story_titles') ? 'titles' : 'other';
        window.readerAnimationSamples.push({region, frames,
            duration: typeof options === 'number' ? options : options.duration});
        return original.apply(this, arguments);
    };
})()"""


def open_preferences(ctx):
    ctx.evaluate("NEWSBLUR.reader.open_preferences_modal()")
    ctx.page.locator(".NB-modal-tab-general").click()
    ctx.wait(300)


def save_toggle(ctx, checked):
    control = ctx.page.locator("#NB-preference-reduce-motion")
    control.set_checked(checked)
    with ctx.page.expect_response(lambda response: "/profile/set_preference" in response.url):
        ctx.page.locator(".NB-modal-preferences .NB-modal-submit-button").click()
    ctx.page.wait_for_function("!document.querySelector('.NB-modal-preferences')")


def check_fades(ctx, region):
    samples = ctx.evaluate("window.readerAnimationSamples").copy()
    relevant = [sample for sample in samples if sample["region"] == region]
    fades = [sample for sample in relevant if sample["duration"] > 0
             and any("opacity" in frame for frame in sample["frames"])]
    moves = [sample for sample in relevant
             if any(any(key in frame for key in ("transform", "translate", "scale", "rotate"))
                    for frame in sample["frames"])]
    ctx.check(f"{region} retains nonzero fades", bool(fades), len(relevant))
    ctx.check(f"{region} has no movement keyframes", not moves, moves[:1])


def run(ctx):
    ctx.page.add_init_script(RECORD_ANIMATIONS)
    ctx.login("/")
    open_preferences(ctx)
    control = ctx.page.locator("#NB-preference-reduce-motion")
    if not ctx.check("Appearance contains a Reduce motion toggle", control.count() == 1):
        ctx.shot("missing-toggle")
        return
    ctx.check("toggle begins off for the unchanged QA account", not control.is_checked())
    ctx.shot("phone-off")
    save_toggle(ctx, True)
    ctx.login("/")
    ctx.check("Reduce motion persists after reload", ctx.evaluate("NEWSBLUR.assets.preference('reduce_motion')") is True)
    check_fades(ctx, "feeds")
    open_preferences(ctx)
    ctx.check("saved toggle remains checked", ctx.page.locator("#NB-preference-reduce-motion").is_checked())
    ctx.shot("phone-on")
    ctx.close_overlays()
    feed = ctx.pick_feed()
    # reduce_motion.py opens the article explicitly so its entrance is measured separately from titles.
    ctx.evaluate("new Promise(resolve => NEWSBLUR.assets.save_preferences({open_feed_action: 0}, resolve))")
    ctx.evaluate(f"NEWSBLUR.assets.view_setting({feed}, {{layout: 'list'}})")
    ctx.evaluate("window.readerAnimationSamples = []")
    ctx.open_feed(feed)
    check_fades(ctx, "titles")
    ctx.evaluate("window.readerAnimationSamples = []")
    ctx.tap_story(0)
    ctx.wait(600)
    check_fades(ctx, "detail")
    ctx.shot("story-fade-only")
    ctx.close_overlays()
    ctx.page.set_viewport_size({"width": 1280, "height": 900})
    ctx.wait(500)
    open_preferences(ctx)
    ctx.shot("desktop-on")
    save_toggle(ctx, False)
    ctx.check("turning the toggle off restores spatial duration", ctx.evaluate("NEWSBLUR.motion.duration(350)") == 350)
    ctx.page.emulate_media(reduced_motion="reduce")
    ctx.check("system Reduce motion removes spatial duration", ctx.evaluate("NEWSBLUR.motion.duration(350)") == 0)
    ctx.check("system Reduce motion retains fade duration", ctx.evaluate("NEWSBLUR.motion.fade_duration(350)") == 350)
    ctx.page.emulate_media(reduced_motion="no-preference")
    ctx.page.set_viewport_size({"width": 393, "height": 852})
    for language in ("de", "ar", "he"):
        ctx.evaluate(f"new Promise(resolve => NEWSBLUR.assets.save_preferences({{language: '{language}'}}, resolve))")
        ctx.login("/")
        open_preferences(ctx)
        label = ctx.page.locator("label[for='NB-preference-reduce-motion']")
        ctx.check(f"{language} renders the translated toggle", label.inner_text() != "Reduce motion")
        expected_direction = "rtl" if language in ("ar", "he") else "ltr"
        ctx.check(f"{language} uses {expected_direction} layout",
                  ctx.evaluate("getComputedStyle(document.documentElement).direction") == expected_direction)
        bounds = label.bounding_box()
        ctx.check(f"{language} label stays within phone width", bounds["x"] >= 0 and bounds["x"] + bounds["width"] <= 393)
        ctx.page.locator("#NB-preference-reduce-motion").click(trial=True)
        ctx.shot(f"phone-{language}")
        ctx.close_overlays()
    ctx.check_no_page_errors()
