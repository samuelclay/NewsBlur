// test_reader_motion.cjs exercises first visibility, reuse, scope changes, and reduced motion.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness() {
    const observers = [];
    const animations = [];
    const frames = new Map();
    let next_frame = 0;
    function element(bounds) {
        const listeners = new Map();
        return {
            bounds, style: {}, parentElement: null, isConnected: true,
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
        getComputedStyle: el => ({ display: 'block', visibility: 'visible', opacity: '1', overflowX: 'visible', overflowY: 'visible', ...el.style }),
        requestAnimationFrame: callback => { frames.set(++next_frame, callback); return next_frame; },
        cancelAnimationFrame: id => frames.delete(id),
        $: () => ({ on() {} }),
        IntersectionObserver: class {
            constructor(callback) {
                this.callback = callback;
                this.targets = new Set();
                observers.push(this);
            }
            observe(el) { this.targets.add(el); }
            unobserve(el) { this.targets.delete(el); }
            disconnect() { this.targets.clear(); }
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
    return { motion: context.NEWSBLUR.motion, document: context.document, observers, animations, preference, record, visible,
        root: () => ({ ...element({ top: 0, bottom: 200, left: 0, right: 300, width: 300, height: 200 }), scrollTop: 0 }),
        paint: () => { const pending = [...frames.values()]; frames.clear(); pending.forEach(callback => callback()); }
    };
}

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
    h.motion.pop(row.el);
    assert.equal(h.animations.length, 1);
});
