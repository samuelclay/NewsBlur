// test_story_selection_motion.cjs exercises the real story render and selection lifecycle.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness(options = {}) {
    const frames = new Map();
    let next_frame = 0;
    const entrances = [];
    const tracked = [];
    const state = { selected: false, visible: true };
    const context = {
        NEWSBLUR: {
            Views: {},
            motion: {
                article(element) { entrances.push(element); },
                article_parts(element) { tracked.push(element); },
                pause_parts() {},
                unwatch_parts() {}
            },
            assets: { preference: name => name === 'animations' },
            reader: { story_view: 'feed', flags: {} },
            app: { taskbar_info: { hide_stories_error() {} }, story_list: { scroll_to_selected_story() {} } }
        },
        Backbone: { View: { extend: definition => definition } },
        _: { template: () => () => '', bind: (fn, owner) => fn.bind(owner), defer() {} },
        requestAnimationFrame: callback => { frames.set(++next_frame, callback); return next_frame; },
        cancelAnimationFrame: id => frames.delete(id),
        clearTimeout() {},
        gettext: text => text
    };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/views/story_detail_view.js', 'utf8'), context);
    context.NEWSBLUR.Views.StorySideoptionsView = function () {
        this.save_view = { render() {} };
        this.share_view = { extract_quote_from_comments: () => ({}), template() {} };
    };
    const view = Object.create(context.NEWSBLUR.Views.StoryDetailView);
    view.el = { isConnected: true, getClientRects: () => state.visible ? [{}] : [] };
    view.$el = { html() {}, toggleClass() {}, is: () => state.visible };
    view.model = { get: key => key === 'selected' ? state.selected : undefined, unbind() {} };
    view.$ = () => ({ tipsy() {} });
    view.remove = () => { view.el.isConnected = false; };
    view.get_render_params = () => ({});
    for (const name of ['setup_classes', 'toggle_classes', 'toggle_read_status', 'toggle_intelligence',
        'generate_gradients', 'render_comments', 'render_cluster_stories', 'render_briefing_admin_badge',
        'attach_handlers', 'update_sideoptions_sticky_state']) view[name] = () => {};
    const observed = [], animations = [], parts = [];
    function part(top = 0) {
        const node = {
            isConnected: true, className: 'NB-sideoption', textContent: 'Save', top, parentElement: view.el,
            getAttribute() { return null; }, matches(selector) { return selector === '.NB-sideoption'; },
            getClientRects() { return [{}]; },
            getBoundingClientRect() { return { top: this.top, bottom: this.top + 30, left: 0, right: 40, width: 40, height: 30 }; },
            animate() { animations.push(this); return { cancel() {} }; }
        };
        parts.push(node);
        return node;
    }
    if (options.real_motion) {
        context.window = { matchMedia: () => ({ matches: false, addEventListener() {} }), innerWidth: 1200, innerHeight: 800 };
        context.document = {};
        context.getComputedStyle = () => ({ display: 'block', visibility: 'visible', opacity: '1', overflowX: 'visible', overflowY: 'visible' });
        context.IntersectionObserver = class {
            constructor() { this.targets = new Set(); observed.push(this); }
            observe(node) { this.targets.add(node); }
            unobserve(node) { this.targets.delete(node); }
            disconnect() { this.targets.clear(); }
        };
        context.MutationObserver = class {
            constructor() { observed.push(this); this.active = false; }
            observe() { this.active = true; }
            disconnect() { this.active = false; }
        };
        view.el.querySelectorAll = selector => selector.includes('.NB-sideoption') ? parts : [];
        view.el.getBoundingClientRect = () => ({ top: 0, bottom: 400, left: 0, right: 400, width: 400, height: 400 });
        vm.runInNewContext(fs.readFileSync('media/js/newsblur/common/motion.js', 'utf8'), context);
    }
    return {
        view, state, entrances, tracked, observed, animations, part, motion: context.NEWSBLUR.motion,
        paint() { const pending = [...frames.values()]; frames.clear(); pending.forEach(callback => callback()); },
        select(selected, options) { state.selected = selected; view.toggle_selected(view.model, selected, options); }
    };
}

test('selecting the already visible first split story does not replay its entrance', () => {
    const h = harness();
    h.view.render();
    h.paint();
    h.entrances.length = 0;
    h.select(true);
    h.paint();
    assert.equal(h.entrances.length, 0);
});

test('new unselected split story content enters when rendered and tracks its visible actions', () => {
    const h = harness();
    h.view.render();
    h.paint();
    assert.deepEqual(h.entrances, [h.view.el]);
    assert.ok(h.tracked.includes(h.view.el), 'Visible actions must be tracked before selecting the story');
});

test('visible story rerenders and reselection stay steady', () => {
    const h = harness();
    h.view.render();
    h.paint();
    h.entrances.length = 0;
    h.view.render();
    h.select(true);
    h.select(false);
    h.select(true);
    h.paint();
    assert.equal(h.entrances.length, 0);
});

test('a hidden single-story document can enter when rendered again for display', () => {
    const h = harness();
    h.view.render();
    h.paint();
    h.entrances.length = 0;
    h.state.visible = false;
    h.view.render();
    h.state.visible = true;
    h.paint();
    assert.deepEqual(h.entrances, [h.view.el]);
});

test('scroll selection never adds a story entrance', () => {
    const h = harness();
    h.view.render();
    h.paint();
    h.entrances.length = 0;
    h.select(true, { selected_by_scrolling: true });
    h.paint();
    assert.equal(h.entrances.length, 0);
});


test('multiple detached renders coalesce into one entrance before the first paint', () => {
    const h = harness();
    h.view.el.isConnected = false;
    h.view.render();
    h.view.render();
    h.view.el.isConnected = true;
    h.paint();
    assert.deepEqual(h.entrances, [h.view.el]);
});

test('destroying a view cancels its pending entrance even if the element is reattached', () => {
    const h = harness();
    h.view.render();
    h.view.destroy();
    h.view.el.isConnected = true;
    h.paint();
    assert.equal(h.entrances.length, 0);
});


test('unselected Feed-view stories keep no live per-part observers after initial presentation', () => {
    const stories = Array.from({ length: 30 }, () => harness({ real_motion: true }));
    for (const h of stories) { h.part(); h.view.render(); h.paint(); }
    const active = () => stories.flatMap(h => h.observed).filter(observer => observer.active || observer.targets?.size).length;
    assert.equal(active(), 0);
    stories[0].select(true);
    assert.equal(active(), 2, 'Only the selected story should own live mutation and intersection observers');
    stories[0].select(false);
    assert.equal(active(), 0);
});

test('resuming a scrolled unselected story settles visible controls but still animates newly inserted parts', () => {
    const h = harness({ real_motion: true });
    const control = h.part(900);
    h.view.render();
    h.paint();
    assert.equal(h.animations.length, 0);
    control.top = 0;
    h.select(true);
    assert.equal(h.animations.length, 0, 'A control already visible before selection must not enter again');
    const arriving = h.part(40);
    h.motion.article_parts(h.view.el);
    assert.deepEqual(h.animations, [arriving]);
});
