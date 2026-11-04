// test_reader_motion.cjs exercises first visibility, reuse, scope changes, and reduced motion.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness() {
    const observers = [];
    const mutations = [];
    const animations = [];
    const delegated_events = [];
    const frames = new Map();
    let next_frame = 0;
    function element(bounds) {
        const listeners = new Map();
        return {
            bounds, style: {}, parentElement: null, isConnected: true, textContent: '', className: '',
            attributes: {},
            getAttribute(name) { return this.attributes[name] || null; },
            setAttribute(name, value) { this.attributes[name] = value; },
            matches(selector) { return this.className.split(/\s+/).includes(selector.trim().split(/\s+/).at(-1).slice(1)); },
            getBoundingClientRect() { return this.bounds; },
            getClientRects() { return this.style.display === 'none' ? [] : [this.bounds]; },
            addEventListener(type, callback, options) { listeners.set(type, { callback, capture: options === true || !!options?.capture }); },
            removeEventListener(type, callback, options) {
                if (listeners.get(type)?.capture === (options === true || !!options?.capture)) listeners.delete(type);
            },
            dispatch(type) {
                listeners.get(type)?.callback();
                for (let parent = this.parentElement; parent; parent = parent.parentElement) {
                    if (parent.listeners.get(type)?.capture) parent.listeners.get(type).callback();
                }
            },
            listeners
        };
    }
    function visible(row, top = 0) {
        row.el.bounds = { top, bottom: top + 80, left: 0, right: 300, width: 300, height: 80 };
    }
    const preference = {
        matches: false,
        addEventListener(_, callback) { this.change = callback; }
    };
    const context = {
        NEWSBLUR: {},
        window: { ...element(), matchMedia: () => preference, IntersectionObserver: true, scrollY: 0, innerWidth: 1200, innerHeight: 800 },
        document: {}, Map, Set, Array,
        performance: { now: () => 0 },
        getComputedStyle: el => ({ display: 'block', visibility: 'visible', opacity: '1', overflowX: 'visible', overflowY: 'visible', ...el.style }),
        requestAnimationFrame: callback => { frames.set(++next_frame, callback); return next_frame; },
        cancelAnimationFrame: id => frames.delete(id),
        $: () => ({ on(event, selector, callback) { delegated_events.push({ event, selector, callback }); } }),
        IntersectionObserver: class {
            constructor(callback) {
                this.callback = callback;
                this.targets = new Set();
                observers.push(this);
            }
            observe(el) { this.targets.add(el); }
            unobserve(el) { this.targets.delete(el); }
            disconnect() { this.targets.clear(); }
        },
        MutationObserver: class {
            constructor(callback) { this.callback = callback; mutations.push(this); }
            observe() {}
            disconnect() { this.disconnected = true; }
        }
    };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/common/motion.js', 'utf8'), context);
    function record(id) {
        return {
            model: { id },
            el: {
                ...element({ top: 900, bottom: 980, left: 0, right: 300, width: 300, height: 80 }),
                animate(frames, options) {
                    const animation = {
                        element: this, frames, options,
                        cancel() { this.cancelled = true; this.oncancel?.(); }
                    };
                    animations.push(animation);
                    return animation;
                }
            }
        };
    }
    return { delegated_events, context, motion: context.NEWSBLUR.motion, document: context.document, observers, mutations, animations, preference, record, visible,
        root: () => ({ ...element({ top: 0, bottom: 200, left: 0, right: 300, width: 300, height: 200 }), scrollTop: 0 }),
        paint: () => { const pending = [...frames.values()]; frames.clear(); pending.forEach(callback => callback()); }
    };
}


test('clicking reader controls never starts a press movement', () => {
    const h = harness();
    const control = h.record('next-unread');
    h.visible(control);
    for (const handler of h.delegated_events.filter(handler => handler.event.startsWith('click'))) {
        handler.callback.call(control.el);
    }
    assert.equal(h.animations.length, 0, 'Click feedback must not scale, rotate, or slide an existing control');
});

test('visible control labels and selection states update without replaying entrances', () => {
    const h = harness(), control = h.record('save'), root = h.root();
    h.visible(control);
    control.el.className = 'NB-feed-story-save';
    control.el.textContent = 'Save';
    root.querySelectorAll = () => [control.el];
    const watcher = h.motion.watch_parts(root, '.NB-feed-story-save');
    assert.equal(h.animations.length, 1);
    control.el.textContent = 'Saved';
    control.el.attributes['aria-pressed'] = 'true';
    watcher.refresh();
    assert.equal(h.animations.length, 1, 'Already visible controls must stay still when their state changes');
});

test('classifier scope changes update selection without scaling the clicked toggle', () => {
    const h = harness(), transforms = [], data = { scope: 'feed' };
    const classifier = {
        data(key, value) { if (value !== undefined) data[key] = value; return data[key]; },
        hasClass() { return false; }, find() { return { length: 0 }; }, addClass() {}, removeClass() {}
    };
    let selected = false, saved = false;
    const toggle = {
        data() { return 'global'; }, closest() { return this; }, find() { return this; }, removeClass() { return this; },
        addClass() { selected = true; return this; }, css(key, value) { if (key === 'transform') transforms.push(value); }
    };
    Object.assign(h.context, { gettext: value => value, _: { extend: Object.assign }, $: () => classifier, setTimeout() {} });
    Object.assign(h.context.NEWSBLUR, { Globals: { is_archive: true }, Modal: function () {} });
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/reader/reader_classifier.js', 'utf8'), h.context);
    h.context.NEWSBLUR.ReaderClassifierFeed.prototype.select_scope.call({ update_save_button() { saved = true; } }, toggle, {});
    assert.equal(data.scope, 'global');
    assert.ok(selected && saved, 'The actual scope action and save affordance still update');
    assert.deepEqual(transforms, [], 'Scope selection must not resize or move the visible toggle');
});

test('archive voice input keeps recording feedback without scaling its button', () => {
    const h = harness(), transforms = [], classes = new Set();
    const control = {
        addClass(name) { classes.add(name); return this; }, removeClass(name) { classes.delete(name); return this; },
        attr() { return this; }, css(key, value) { if (key === 'transform') transforms.push(value); return this; }
    };
    Object.assign(h.context, { gettext: value => value, Backbone: { View: { extend: value => value } } });
    Object.assign(h.context.NEWSBLUR, { Views: {}, VoiceRecorder: class {
        constructor(callbacks) { this.callbacks = callbacks; }
        start_recording() { this.callbacks.on_recording_start(); this.callbacks.on_audio_level?.(1); }
    } });
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/views/archive_view.js', 'utf8'), h.context);
    h.context.NEWSBLUR.Views.ArchiveView.start_voice_recording.call({ $: () => control });
    assert.ok(classes.has('NB-recording'), 'Recording remains visibly indicated');
    assert.deepEqual(transforms, [], 'Audio levels must not resize the visible recording button');
});

test('article actions enter individually rather than moving their entire bar', () => {
    const h = harness();
    const bar = h.record('bar');
    bar.el.className = 'NB-feed-story-sideoptions';
    h.visible(bar, 100);
    const actions = ['train', 'save', 'share', 'ask-ai', 'listen'].map((name, index) => {
        const action = h.record(name);
        action.el.className = `NB-sideoption NB-feed-story-${name}`;
        h.visible(action, 100);
        action.el.bounds.left = index * 50;
        action.el.bounds.right = index * 50 + 40;
        action.el.parentElement = bar.el;
        return action;
    });
    const nodes = [bar, ...actions].map(record => record.el);
    const article = {
        querySelectorAll(selector) {
            // test_reader_motion.cjs uses the real selector against the action markup classes.
            const classes = selector.split(',').map(part => part.trim().split(/\s+/).at(-1).slice(1));
            return nodes.filter(node => classes.some(name => node.className.split(' ').includes(name)));
        }
    };
    h.motion.article(article);
    assert.deepEqual(h.animations.map(animation => animation.element), actions.map(action => action.el));
    assert.ok(h.animations.every((animation, index) => index === 0 || animation.options.delay > h.animations[index - 1].options.delay));
});

test('article entrance includes every visible header metadata item exactly once', () => {
    const h = harness();
    const classes = ['NB-feed-story-header-feed', 'NB-feed-story-title-container',
        'NB-feed-story-show-changes', 'NB-feed-story-date', 'NB-feed-story-author-wrapper',
        'NB-feed-story-tags', 'NB-feed-story-url-match', 'NB-feed-story-ai-classifiers',
        'NB-feed-story-starred-date', 'NB-feed-story-content'];
    const nodes = classes.map((name, index) => {
        const row = h.record(name + index);
        row.el.className = name;
        h.visible(row, index * 40);
        return row.el;
    });
    const children = ['NB-feed-story-tags', 'NB-feed-story-ai-classifiers'].flatMap((group_class, group_index) => {
        const parent = nodes.find(node => node.className === group_class);
        const child_class = group_index === 0 ? 'NB-feed-story-tag' : 'NB-feed-story-ai-classifier';
        return ['NB-middot', child_class, child_class].map((name, index) => {
            const child = h.record(group_class + index);
            child.el.className = name;
            h.visible(child, parent.bounds.top);
            child.el.parentElement = parent;
            return child.el;
        });
    });
    const hidden_group = h.record('hidden-tags');
    hidden_group.el.className = 'NB-feed-story-tags';
    hidden_group.el.style.display = 'none';
    const article = {
        querySelectorAll(selector) {
            return [...nodes, ...children, hidden_group.el].filter(node => selector.split(',').some(part => node.matches(part)));
        }
    };
    h.motion.article(article);
    assert.deepEqual(h.animations.map(animation => animation.element.className), classes,
        'Header metadata must enter once, with tags and AI classifiers moving as groups including their separators');
    assert.ok(h.animations.every(animation => !children.includes(animation.element)),
        'Grouped tags and classifiers must not also animate their children separately');
    assert.ok(h.animations.every((animation, index) => index === 0 ||
        animation.options.delay > h.animations[index - 1].options.delay));
});

test('dashboard without an active feed waits for visibility and only enters once', () => {
    const h = harness(), owner = {}, a = h.record('a');
    h.motion.watch(owner, [a], null, undefined);
    const observer = h.observers[0];
    observer.callback([{ target: a.el, isIntersecting: false }]);
    assert.equal(h.animations.length, 0);
    h.visible(a);
    observer.callback([{ target: a.el, isIntersecting: true }]);
    assert.equal(h.animations.length, 1);
    const replacement = h.record('a');
    h.motion.watch(owner, [replacement], null, undefined);
    assert.equal(observer.targets.size, 0);
});

test('newly inserted visible feed and story rows start their entrance before the observer callback', () => {
    for (const scope of ['feeds', 'story-feed']) {
        const h = harness(), owner = {};
        const rows = [h.record('first'), h.record('second')];
        rows.forEach((row, index) => {
            row.el.getBoundingClientRect = () => ({ top: index * 80, bottom: (index + 1) * 80, left: 0, right: 300, width: 300, height: 80 });
        });
        h.motion.watch(owner, rows, null, scope);
        // test_reader_motion.cjs models the first paint before IntersectionObserver delivers visibility.
        assert.equal(h.animations.length, 2, 'Rows must not paint fully visible and then restart at opacity zero');
        assert.equal(h.animations[0].frames[0].opacity, 0);
        assert.ok(h.animations[1].options.delay > h.animations[0].options.delay);
    }
});

test('a new feed resets identity and a large batch caps the delay', () => {
    const h = harness(), owner = {};
    const rows = Array.from({ length: 30 }, (_, i) => h.record(i + 1));
    h.motion.watch(owner, rows, null, 'one');
    rows.forEach(row => h.visible(row));
    h.observers[0].callback(rows.map(r => ({ target: r.el, isIntersecting: true })));
    assert.equal(Math.max(...h.animations.map(a => a.options.delay)), 175);
    assert.ok(h.animations.every((animation, index) => index === 0 || animation.options.delay > h.animations[index - 1].options.delay));
    h.motion.watch(owner, [rows[0]], null, 'two');
    assert.equal(h.animations.length, 31);
    assert.equal(h.observers[1].targets.size, 0);
});

test('visible rows cascade in screen order with a distinct bounded delay for every row', () => {
    for (const method of ['watch', 'cascade']) {
        const h = harness(), owner = {};
        const rows = Array.from({ length: 30 }, (_, index) => {
            const row = h.record(index + 1);
            h.visible(row, Math.floor(index / 5) * 80);
            row.el.bounds.left = (index % 5) * 100;
            row.el.bounds.right = row.el.bounds.left + 100;
            row.el.bounds.width = 100;
            return row;
        });
        const reverse_order = [...rows].reverse();
        if (method === 'watch') h.motion.watch(owner, reverse_order, null, 'feed');
        else h.motion.cascade(reverse_order.map(row => row.el), 8);
        assert.deepEqual(h.animations.map(animation => rows.findIndex(row => row.el === animation.element)), rows.map((_, index) => index));
        assert.equal(h.animations[0].options.delay, 0);
        assert.ok(h.animations.every((animation, index) => index === 0 || animation.options.delay > h.animations[index - 1].options.delay));
        assert.ok(h.animations.every(animation => animation.options.delay <= (method === 'watch' ? 175 : 180)));
    }
});

test('dialog sections outside the scroll viewport do not compress the visible cascade', () => {
    const h = harness(), root = h.root();
    root.style.overflowY = 'auto';
    const rows = Array.from({ length: 18 }, (_, index) => {
        const row = h.record(index + 1);
        h.visible(row, index * 80);
        row.el.parentElement = root;
        return row;
    });
    h.motion.cascade(rows.map(row => row.el), 8);
    assert.equal(h.animations.length, 3, 'Clipped Preferences sections should wait until visible');
    assert.deepEqual(h.animations.map(animation => animation.options.delay), [0, 30, 60]);
});

test('scrolling into a new batch reveals every row without a stagger backlog', () => {
    const h = harness(), owner = {}, root = h.root();
    const rows = Array.from({ length: 8 }, (_, i) => h.record(i + 1));
    h.motion.watch(owner, rows, root, 'feed');
    root.scrollTop = 1000;
    rows.forEach(row => h.visible(row));
    h.observers[0].callback(rows.map(r => ({ target: r.el, isIntersecting: true })));
    assert.equal(h.animations.length, rows.length);
    assert.equal(h.animations[0].options.delay, 0);
    assert.ok(h.animations[1].options.delay > 0);
    assert.ok(h.animations.every(a => a.options.delay <= 90));
    assert.ok(h.animations.every((animation, index) => index === 0 || animation.options.delay > h.animations[index - 1].options.delay));
});

test('nested dialog scrolling reveals unseen sections once and tab changes disconnect the old observer', () => {
    const h = harness(), owner = {}, dialog = h.root(), form = h.root();
    form.style.overflowY = 'auto';
    form.parentElement = dialog;
    const rows = Array.from({ length: 6 }, (_, index) => {
        const row = h.record(index + 1);
        h.visible(row, index * 80);
        row.el.parentElement = form;
        return row;
    });
    h.motion.watch(owner, rows, dialog, 'general', { distance: 8, spacing: 30, spread: 180 });
    assert.deepEqual(h.animations.map(animation => animation.options.delay), [0, 30, 60]);
    rows.forEach((row, index) => h.visible(row, index * 80 - 240));
    form.dispatch('scroll');
    assert.equal(h.animations.length, 6, 'Nested scrolling reveals the next batch synchronously');
    form.dispatch('scroll');
    assert.equal(h.animations.length, 6, 'Initial and newly visible sections never replay');
    h.motion.watch(owner, [], dialog, 'another-tab');
    assert.equal(h.observers[0].targets.size, 0);
    assert.equal(dialog.listeners.size, 0, 'The old tab leaves no scroll listener behind');
});

test('hidden roots keep identities pending until visible before paint', () => {
    for (const hidden_style of [{ display: 'none' }, { visibility: 'hidden' }, { opacity: '0' }]) {
        const h = harness(), owner = {}, root = h.root(), row = h.record('hidden');
        h.visible(row);
        root.style = hidden_style;
        row.el.parentElement = root;
        h.motion.watch(owner, [row], root, 'feed');
        h.observers[0].callback([{ target: row.el, isIntersecting: true }]);
        assert.equal(h.animations.length, 0);
        assert.equal(h.observers[0].targets.size, 1);
        root.style = {};
        h.paint();
        assert.equal(h.animations.length, 1);
        assert.equal(h.observers[0].targets.size, 0);
    }
});

test('first scrolling into the clipped viewport starts motion before the observer and never replays', () => {
    const h = harness(), owner = {}, root = h.root(), row = h.record('below-root');
    h.visible(row, 300);
    row.el.parentElement = root;
    h.motion.watch(owner, [row], root, 'feed');
    assert.equal(h.animations.length, 0, 'Inside the window is not enough when the scroll root clips the row');
    h.visible(row, 100);
    root.scrollTop = 200;
    root.dispatch('scroll');
    assert.equal(h.animations.length, 1);
    h.observers[0].callback([{ target: row.el, isIntersecting: true }]);
    root.dispatch('scroll');
    assert.equal(h.animations.length, 1);
    owner.motion_observer.disconnect();
    assert.equal(root.listeners.size, 0);
});

test('absolutely positioned reader rows use the viewport when body has zero layout height', () => {
    const h = harness(), owner = {}, root = h.root(), body = h.root();
    // test_reader_motion.cjs reproduces NewsBlur's absolute layout inside an overflow-hidden body.
    body.tagName = 'BODY';
    h.document.body = body;
    body.bounds = { top: 0, bottom: 0, left: 0, right: 1200, width: 1200, height: 0 };
    body.style = { overflowX: 'hidden', overflowY: 'hidden' };
    root.parentElement = body;
    const rows = [h.record('first'), h.record('second')];
    rows.forEach((row, index) => { h.visible(row, index * 80); row.el.parentElement = root; });
    h.motion.watch(owner, rows, root, 'feed');
    assert.equal(h.animations.length, 2, 'Visible stories must start before paint despite the zero-height body box');
    assert.ok(h.animations[1].options.delay > h.animations[0].options.delay);
});

test('document viewport clipping preserves nested overflow and hidden document ancestors', () => {
    const h = harness(), owner = {}, root = h.root(), nested = h.root(), body = h.root(), html = h.root();
    h.document.body = body;
    h.document.documentElement = html;
    root.parentElement = nested;
    nested.parentElement = body;
    body.parentElement = html;
    for (const node of [body, html, nested]) {
        node.bounds.height = 0;
        node.bounds.bottom = 0;
        node.style = { overflowX: 'hidden', overflowY: 'hidden' };
    }
    const row = h.record('nested');
    h.visible(row);
    row.el.parentElement = root;
    h.motion.watch(owner, [row], root, 'feed');
    assert.equal(h.animations.length, 0, 'A zero-height nested container still clips its descendants');
    assert.equal(owner.motion_seen.size, 0);
    nested.bounds.height = nested.bounds.bottom = 200;
    body.style.visibility = 'hidden';
    owner.motion_observer.reveal();
    assert.equal(h.animations.length, 0, 'Document ancestors still suppress hidden content');
    body.style.visibility = 'visible';
    owner.motion_observer.reveal();
    assert.equal(h.animations.length, 1, 'Document boxes use the viewport once nested content becomes visible');
});

test('interrupting an exit or enabling reduced motion finishes its cleanup exactly once', () => {
    const h = harness(), row = h.record('a');
    let cleaned = 0;
    h.motion.exit(row.el, () => cleaned++);
    h.motion.enter(row.el);
    assert.equal(cleaned, 1);
    h.motion.exit(row.el, () => cleaned++);
    h.preference.matches = true;
    h.preference.change();
    assert.equal(cleaned, 2);
    h.motion.exit(row.el, () => cleaned++);
    assert.equal(cleaned, 3);
});

test('reduced motion cancels active effects and does not hide subsequent content', () => {
    const h = harness(), row = h.record('a');
    h.motion.enter(row.el);
    assert.equal(h.animations.length, 1);
    h.preference.matches = true;
    h.preference.change();
    assert.equal(h.animations[0].cancelled, true);
    h.motion.enter(row.el);
    assert.equal(h.animations.length, 1);
});

test('story title scrolling finishes opening effects and keeps later rows and pagination fully rendered', () => {
    const h = harness(), owner = {}, root = h.root();
    const first = h.record('opening'), later = h.record('later');
    h.visible(first);
    h.motion.watch(owner, [first, later], root, 'feed-one', { animate_on_scroll: false });
    assert.equal(h.animations.length, 1, 'Opening a feed still animates its visible titles');
    h.visible(later, 80);
    root.scrollTop = 100;
    root.dispatch('scroll');
    assert.equal(h.animations.length, 1, 'Scrolling reveals titles without starting new effects');
    assert.equal(h.animations[0].cancelled, true, 'Scrolling finishes the opening cascade immediately');
    assert.equal(owner.motion_seen.has('later'), true);
    const paginated = h.record('next-page');
    h.visible(paginated);
    h.motion.watch(owner, [paginated], root, 'feed-one', { animate_on_scroll: false });
    h.paint();
    assert.equal(h.animations.length, 1, 'A page arriving after scrolling stops must not fade in');
    h.motion.watch(owner, [paginated], root, 'feed-two', { animate_on_scroll: false });
    assert.equal(h.animations.length, 2, 'Opening another feed gets a new cascade');
});

test('a queued scroll reset from the previous feed does not cancel a new feed cascade', () => {
    const h = harness(), owner = {}, root = h.root();
    const previous = h.record('previous');
    h.visible(previous);
    h.motion.watch(owner, [previous], root, 'feed-one', { animate_on_scroll: false });
    root.scrollTop = 200;
    root.dispatch('scroll');
    root.scrollTop = 0;
    const next = h.record('next');
    h.visible(next);
    h.motion.watch(owner, [next], root, 'feed-two', { animate_on_scroll: false });
    const opening = h.animations.at(-1);
    root.dispatch('scroll');
    assert.notEqual(opening.cancelled, true, 'The queued reset must preserve the new opening cascade');
    assert.equal(owner.motion_scrolled, false);
    root.scrollTop = 40;
    root.dispatch('scroll');
    assert.equal(opening.cancelled, true, 'Actual scrolling must still finish the cascade');
});

test('persistent controls stay fixed across label and decorative class updates', () => {
    const h = harness(), root = h.root();
    const save = h.record('save'), share = h.record('share');
    save.el.textContent = 'Save'; share.el.textContent = 'Share';
    h.visible(save); h.visible(share, 80);
    root.querySelectorAll = () => [save.el, share.el];
    h.motion.watch_parts(root, '.NB-sideoption');
    assert.equal(h.animations.length, 2);
    h.animations.forEach(animation => animation.onfinish());
    save.el.className = 'NB-sideoption NB-hover';
    h.mutations[0].callback();
    h.paint();
    assert.equal(h.animations.length, 2, 'Decorative classes must not replay action entrances');
    save.el.textContent = 'Saved';
    h.mutations[0].callback();
    h.paint();
    assert.equal(h.animations.length, 2, 'Saving updates the label without moving the visible action');
    h.motion.watch_parts(root, '.NB-sideoption');
    assert.equal(h.animations.length, 2, 'Selecting another story must not replay persistent controls');
});

test('async comments and cluster rows cascade on first visibility without replaying existing actions', () => {
    const h = harness(), root = h.root(), action = h.record('action');
    h.visible(action);
    const nodes = [action.el];
    root.querySelectorAll = () => nodes;
    h.motion.watch_parts(root, '.parts');
    const comment = h.record('comment'), second_comment = h.record('second-comment'), cluster = h.record('cluster');
    h.visible(comment, 80);
    h.visible(second_comment, 120);
    nodes.push(comment.el, second_comment.el, cluster.el);
    h.mutations[0].callback();
    h.paint();
    assert.deepEqual(h.animations.map(animation => animation.element), [action.el, comment.el, second_comment.el]);
    assert.ok(h.animations[2].options.delay > h.animations[1].options.delay, 'Async rows enter successively in screen order');
    h.visible(cluster, 160);
    h.observers[0].callback([{ target: cluster.el, isIntersecting: true }]);
    assert.deepEqual(h.animations.map(animation => animation.element), [action.el, comment.el, second_comment.el, cluster.el]);
    h.observers[0].callback([{ target: cluster.el, isIntersecting: true }]);
    assert.equal(h.animations.length, 4);
    h.motion.unwatch_parts(root);
    assert.equal(h.observers[0].targets.size, 0);
    assert.equal(h.mutations[0].disconnected, true);
});

test('controls honor reduced motion and still remember their presented state', () => {
    const h = harness(), root = h.root(), action = h.record('action');
    h.preference.matches = true;
    h.visible(action);
    root.querySelectorAll = () => [action.el];
    h.motion.watch_parts(root, '.parts');
    assert.equal(h.animations.length, 0);
    h.preference.matches = false;
    h.mutations[0].callback();
    h.paint();
    assert.equal(h.animations.length, 0, 'Enabling motion must not replay the current bar');
});

test('control mutations share one prepaint scan and disconnect cancels queued work', () => {
    const h = harness(), root = h.root(), action = h.record('action');
    let scans = 0;
    h.visible(action);
    root.querySelectorAll = () => { scans++; return [action.el]; };
    h.motion.watch_parts(root, '.parts');
    h.mutations[0].callback(); h.mutations[0].callback(); h.mutations[0].callback();
    assert.equal(scans, 1, 'Several mutations must not synchronously rescan every comment and action');
    h.paint();
    assert.equal(scans, 2, 'Coalesced work runs before the next paint');
    action.el.textContent = 'Changed';
    h.mutations[0].callback();
    h.motion.unwatch_parts(root);
    h.paint();
    h.observers[0].callback([{ target: action.el, isIntersecting: true }]);
    h.mutations[0].callback(); h.paint();
    assert.equal(scans, 2, 'A deselected/destroyed story must not retain pending observer work');
    assert.equal(h.animations.length, 1);
});

test('rebuilt controls and comments retain their appearance history even when their content changes', () => {
    const h = harness(), root = h.root();
    function part(id, label, top) {
        const record = h.record(id);
        record.el.attributes['data-motion-key'] = id;
        record.el.textContent = label;
        h.visible(record, top);
        return record.el;
    }
    let nodes = [part('save', 'Save', 0), part('comment:23', 'A comment', 80)];
    root.querySelectorAll = () => nodes;
    h.motion.watch_parts(root, '.parts');
    assert.equal(h.animations.length, 2);
    nodes = [part('save', 'Save', 0), part('comment:23', 'A comment', 80)];
    h.mutations[0].callback(); h.paint();
    assert.equal(h.animations.length, 2, 'Rebuilt identical markup must not replay the entire action or social section');
    const changed = part('save', 'Saved', 0);
    nodes = [changed, part('comment:23', 'A comment', 80)];
    h.mutations[0].callback(); h.paint();
    assert.equal(h.animations.length, 2, 'Replacing a visible control with its updated state must not replay its entrance');
    assert.equal(h.observers[0].targets.size, 2, 'Replaced elements must not accumulate in the visibility observer');
});

test('deselecting and reselecting a story preserves visible actions even when their state changes', () => {
    const h = harness(), root = h.root(), save = h.record('save'), share = h.record('share');
    save.el.textContent = 'Save'; share.el.textContent = 'Share';
    h.visible(save); h.visible(share, 80);
    root.querySelectorAll = () => [save.el, share.el];
    h.motion.watch_parts(root, '.parts');
    assert.equal(h.animations.length, 2);
    h.motion.pause_parts(root);
    assert.equal(h.observers[0].targets.size, 0);
    h.motion.watch_parts(root, '.parts');
    assert.equal(h.animations.length, 2, 'Scrolling back over the same story must not replay all its controls');
    h.motion.pause_parts(root);
    save.el.textContent = 'Saved';
    h.motion.watch_parts(root, '.parts');
    assert.equal(h.animations.length, 2, 'A state change while paused must not replay visible controls when the story resumes');
});

// test_reader_motion.cjs renders the real header against floated search markup and persistent traversal controls.
function feed_toolbar_fixture(with_identity = false) {
    const h = harness(), bar = h.root(), header_element = h.root();
    bar.bounds = { top: 0, bottom: 40, left: 0, right: 1000, width: 1000, height: 40 };
    let controls, identities;
    function rebuild() {
        controls = ['NB-feedbar-options', 'NB-story-title-search', 'NB-feedbar-mark-feed-read-container', 'NB-task-story-next-unread'].map((name, index) => {
            const control = h.record(name).el;
            control.className = name;
            control.textContent = ['All · Newest', '', '', 'Next unread'][index];
            control.bounds = { top: index === 3 ? 0 : 3, bottom: 25, left: 100 + index * 100, right: 180 + index * 100, width: 80, height: 22 };
            control.parentElement = bar;
            return control;
        });
        const wrapper = h.record('search-wrapper').el;
        wrapper.className = 'NB-search-container';
        wrapper.bounds = { top: 0, bottom: 0, left: 0, right: 1000, width: 1000, height: 0 };
        wrapper.parentElement = bar;
        controls[1].parentElement = wrapper;
        identities = with_identity ? ['feed_favicon', 'feed_title'].map((name, index) => {
            const record = h.record(name);
            record.el.className = name;
            h.visible(record);
            record.el.bounds.left = index * 30;
            record.el.parentElement = header_element;
            return record.el;
        }) : [];
        const match = (nodes, selector) => nodes.filter(node => selector.split(',').some(part => node.matches(part.trim())));
        bar.querySelectorAll = selector => match(controls, selector);
        header_element.querySelectorAll = selector => match([...controls.slice(0, 3), ...identities], selector);
        header.$el.find = selector => ({ toArray: () => match([...controls.slice(0, 3), wrapper, ...identities], selector) });
    }
    h.context.Backbone = { View: { extend: definition => definition } };
    h.context._ = { extend: Object.assign, bind: (fn, receiver) => fn.bind(receiver) };
    Object.assign(h.context.NEWSBLUR, {
        Views: { FeedTitleView: class { render() { return { $el: {} }; } } },
        reader: { flags: {}, active_feed: 1, $s: { $feedbar: [bar], $story_titles_header: [header_element] } },
        assets: { get_feed: () => ({}) }
    });
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/views/story_titles_header_view.js', 'utf8'), h.context);
    const header = Object.create(h.context.NEWSBLUR.Views.StoryTitlesHeader);
    header.options = {};
    header.$el = { 0: header_element, html() {}, closest: () => [bar] };
    rebuild();
    return { h, bar, header, header_element, rebuild, controls: () => controls, identities: () => identities,
        render: () => { header.render({ feed_id: h.context.NEWSBLUR.reader.active_feed }); h.paint(); } };
}

test('visible feed identity stays fixed on same-feed rebuilds but a new feed identity enters', () => {
    const f = feed_toolbar_fixture(true);
    f.render();
    f.h.animations.length = 0;
    f.rebuild();
    f.render();
    assert.equal(f.h.animations.length, 0, 'The visible title and favicon must not replay when the same feed reloads');
    f.h.context.NEWSBLUR.reader.active_feed = 2;
    f.rebuild();
    f.render();
    assert.deepEqual(f.h.animations.map(animation => animation.element), f.identities(),
        'A newly opened feed may introduce its own title and favicon');
});

test('feed header cascades All/Newest, floated Search, Mark Read, and persistent Next Unread together', () => {
    const f = feed_toolbar_fixture();
    f.render();
    assert.deepEqual(f.h.animations.map(animation => animation.element), f.controls(),
        'All visible toolbar controls enter together in horizontal reading order, despite differing top margins');
    assert.ok(f.h.animations.every((animation, index, all) => index === 0 || animation.options.delay > all[index - 1].options.delay));
});

test('rebuilding a visible feed header keeps controls steady even when the filter changes', () => {
    const f = feed_toolbar_fixture();
    f.render();
    f.h.animations.length = 0;
    f.rebuild();
    f.render();
    assert.equal(f.h.animations.length, 0, 'Opening another feed must not replay an unchanged toolbar');
    f.controls()[0].textContent = 'Unread · Newest';
    f.render();
    assert.equal(f.h.animations.length, 0, 'A filter change updates the label without moving it');
});

test('feed and folder template indentation does not replay unchanged filter and mark-read controls', () => {
    const f = feed_toolbar_fixture();
    // test_reader_motion.cjs models the text nodes from feed_title_view.js and story_titles_header_view.js,
    // including the hidden mark-read day labels retained in textContent.
    f.controls()[0].textContent = ['All', '·', 'Newest'].join(' '.repeat(22));
    f.controls()[2].textContent = ['1d', '3d', '7d', '14d'].join(' '.repeat(19));
    f.render();
    f.h.animations.length = 0;
    f.rebuild();
    f.controls()[0].textContent = ['All', '·', 'Newest'].join(' '.repeat(32));
    f.controls()[2].textContent = ['1d', '3d', '7d', '14d'].join(' '.repeat(24));
    f.render();
    assert.equal(f.h.animations.length, 0, 'HTML indentation is not a visible control change');
    f.controls()[0].textContent = ['Unread', '·', 'Newest'].join(' '.repeat(32));
    f.render();
    assert.equal(f.h.animations.length, 0, 'A visible filter stays fixed for whitespace and label changes alike');
});

test('feed toolbar uses RTL reading order and batches view switching with a later header rebuild', () => {
    const f = feed_toolbar_fixture();
    f.bar.style.direction = 'rtl';
    f.h.motion.feedbar_parts(f.bar);
    f.rebuild();
    f.render();
    assert.deepEqual(f.h.animations.map(animation => animation.element), [...f.controls()].reverse(),
        'Only the final visible controls animate, right to left, even when view switching runs first');
    assert.equal(f.h.mutations.length, 2, 'Toolbar controls share one observer, separate from the header identity');
});

test('returning from the dashboard cascades the whole toolbar even before visibility observers fire', () => {
    const f = feed_toolbar_fixture(true);
    f.render();
    f.h.animations.length = 0;
    f.h.context.Backbone.Router = { extend: definition => definition };
    f.h.context.jQuery = f.h.context.$;
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/reader/reader.js', 'utf8'), f.h.context);
    const reader = Object.assign(Object.create(f.h.context.NEWSBLUR.Reader), {
        reset_feed() {}, open_sidebar() {}, flags: {},
        $s: { $feedbar: [f.bar], $story_titles_header: [f.header_element],
            $body: { removeClass() { f.bar.style.display = 'none'; } },
            $header_dashboard: { addClass() {} } }
    });
    reader.show_splash_page(true);
    f.bar.style.display = 'block';
    f.rebuild();
    f.render();
    assert.deepEqual(f.h.animations.map(animation => animation.element), [...f.identities(), ...f.controls()],
        'A real toolbar disappearance resets all controls, including the persistent Next Unread button');
});

test('a hidden toolbar waits for appearance and starts all controls before painting', () => {
    const f = feed_toolbar_fixture();
    f.bar.style.display = 'none';
    f.render();
    assert.equal(f.h.animations.length, 0);
    f.bar.style.display = 'block';
    f.h.mutations[0].callback();
    f.h.paint();
    assert.deepEqual(f.h.animations.map(animation => animation.element), f.controls());
    assert.ok(f.h.animations.every(animation => animation.frames[0].opacity === 0 && animation.options.fill === 'backwards'),
        'Delayed controls are already transparent throughout their stagger delay');
});


test('initial pagination continues one title cascade across arriving batches', () => {
    const h = harness(), owner = {}, root = h.root();
    root.bounds = { top: 0, bottom: 800, left: 0, right: 300, width: 300, height: 800 };
    let now = 0;
    h.context.performance = { now: () => now };
    const starts = [];
    for (let page = 0; page < 5; page++) {
        now = page * 20;
        const rows = Array.from({ length: 12 }, (_, index) => {
            const row = h.record(page * 12 + index + 1);
            const top = (page * 12 + index) * 12;
            row.el.bounds = { top, bottom: top + 12, left: 0, right: 300, width: 300, height: 12 };
            return row;
        });
        const before = h.animations.length;
        h.motion.watch(owner, rows, root, 'feed', { animate_on_scroll: false });
        starts.push(...h.animations.slice(before).map(animation => now + animation.options.delay));
    }
    assert.equal(starts.length, 60);
    assert.ok(starts.every((start, index) => index === 0 || start > starts[index - 1]),
        'A later page must continue below the previous page instead of starting another wave');
    assert.ok(starts[12] < starts[11] + 350,
        'The next page overlaps the previous row fade instead of waiting for the page to finish');
    assert.ok(h.animations.every(animation => animation.options.fill === 'backwards'),
        'Queued rows must already be hidden before their first paint, not flash before their turn');
});

test('switching feeds cancels every old opening effect and starts the new feed without its queue', () => {
    const h = harness(), owner = {}, root = h.root();
    const rows = ['old-first', 'old-last'].map(id => h.record(id));
    rows.forEach((row, index) => h.visible(row, index * 80));
    h.motion.watch(owner, rows, root, 'old-feed', { animate_on_scroll: false });
    const old = h.animations.slice();
    const next = h.record('new-first');
    h.visible(next);
    h.motion.watch(owner, [next], root, 'new-feed', { animate_on_scroll: false });
    assert.ok(old.every(animation => animation.cancelled), 'Leaving a feed must cancel both active and delayed rows');
    assert.equal(h.animations.at(-1).options.delay, 0, 'The new feed cannot inherit the previous opening backlog');
});

test('scrolling ends queued title pages and later pages remain fully visible', () => {
    const h = harness(), owner = {}, root = h.root();
    for (let page = 0; page < 3; page++) {
        const rows = [h.record(page + '-a'), h.record(page + '-b')];
        rows.forEach((row, index) => h.visible(row, index * 80));
        h.motion.watch(owner, rows, root, 'feed', { animate_on_scroll: false });
    }
    assert.equal(h.animations.length, 6);
    root.scrollTop = 20;
    root.dispatch('scroll');
    assert.ok(h.animations.every(animation => animation.cancelled), 'Scrolling reveals the entire queued opening immediately');
    const next = h.record('later-page');
    h.visible(next);
    h.motion.watch(owner, [next], root, 'feed', { animate_on_scroll: false });
    h.paint();
    assert.equal(h.animations.length, 6, 'Pagination after scrolling must not hide new titles');
});

test('reduced motion clears an opening backlog without delaying later content when reenabled', () => {
    const h = harness(), owner = {}, root = h.root();
    const first = h.record('first'), second = h.record('second');
    h.visible(first); h.visible(second, 80);
    h.motion.watch(owner, [first, second], root, 'feed', { animate_on_scroll: false });
    h.preference.matches = true;
    h.preference.change();
    assert.ok(h.animations.every(animation => animation.cancelled));
    const reduced = h.record('reduced');
    h.visible(reduced);
    h.motion.watch(owner, [reduced], root, 'feed', { animate_on_scroll: false });
    assert.equal(h.animations.length, 2, 'Reduced Motion presents arriving content immediately');
    h.preference.matches = false;
    const next = h.record('next');
    h.visible(next);
    h.motion.watch(owner, [next], root, 'feed', { animate_on_scroll: false });
    assert.equal(h.animations.at(-1).options.delay, 0);
});

test('feed and dialog rows retain independent batch cascades', () => {
    const h = harness(), owner = {}, root = h.root();
    const first = h.record('first'), second = h.record('second'), next = h.record('next');
    h.visible(first); h.visible(second, 80); h.visible(next);
    h.motion.watch(owner, [first, second], root, 'dialog');
    h.motion.watch(owner, [next], root, 'dialog');
    assert.equal(h.animations.at(-1).options.delay, 0, 'Only initial story-title pagination shares an opening timeline');
});
