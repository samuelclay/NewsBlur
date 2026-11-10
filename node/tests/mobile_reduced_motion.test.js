// mobile_reduced_motion.test.js exercises the real mobile timing declarations and completion paths.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

// Resolve the timing declarations for the exact reader selectors under each motion setting.
function css_rules(css, reduced, rules = []) {
    css = css.replace(/\/\*[\s\S]*?\*\//g, '');
    let offset = 0;
    while (offset < css.length) {
        const open = css.indexOf('{', offset);
        if (open < 0) break;
        let depth = 1, end = open + 1;
        for (; end < css.length && depth; end++) {
            if (css[end] === '{') depth++;
            if (css[end] === '}') depth--;
        }
        const selector = css.slice(offset, open).trim();
        const body = css.slice(open + 1, end - 1);
        if (selector.startsWith('@media')) {
            if (selector.includes('prefers-reduced-motion') && reduced) css_rules(body, reduced, rules);
        } else if (!selector.startsWith('@')) {
            const declarations = Object.fromEntries(body.split(';').filter(s => s.includes(':')).map(s => {
                const colon = s.indexOf(':');
                return [s.slice(0, colon).trim(), s.slice(colon + 1).trim().replace(/\s*!important$/, '')];
            }));
            rules.push({ selectors: selector.split(',').map(s => s.trim()), declarations });
        }
        offset = end;
    }
    return rules;
}
function timing(selector, property, reduced, disabled) {
    const rules = css_rules(read('media/css/reader/mobile.css'), reduced);
    const vars = {}, style = {};
    for (const rule of rules) {
        if (rule.selectors.includes('body.NB-mobile') ||
            disabled && rule.selectors.includes('body.NB-mobile.NB-no-animations')) Object.assign(vars, rule.declarations);
        if (rule.selectors.includes(selector)) Object.assign(style, rule.declarations);
    }
    let value = style[property];
    assert.ok(value, `${selector}: ${property} exists`);
    for (let i = 0; i < 10 && value.includes('var('); i++) {
        value = value.replace(/var\((--[\w-]+)\)/g, (_, name) => vars[name] ?? 'unresolved');
    }
    value = value.replace(/calc\((\d+(?:\.\d+)?)ms\s*\*\s*(\d+(?:\.\d+)?)\)/g, (_, time, scale) => Number(time) * Number(scale) + 'ms');
    const durations = [...value.matchAll(/\b(\d+(?:\.\d+)?)ms\b/g)].map(match => Number(match[1]));
    assert.ok(durations.length, `${selector}: timing resolves (${value})`);
    return Math.max(...durations);
}

const css_cases = [
    ['body.NB-mobile .NB-mobile-story-track.NB-mobile-animating', 'transition'],
    ['body.NB-mobile #simplemodal-container', 'animation'],
    ['body.NB-mobile .NB-popover.popover', 'transition'],
    ['body.NB-mobile .NB-menu-manage-container.NB-mobile-sheet', 'animation'],
    ['body.NB-mobile .NB-menu-ask-ai-container', 'animation'],
    ['body.NB-mobile .NB-media-player.NB-mobile-player.NB-mobile-player-expanded', 'animation']
];
for (const [selector, property] of css_cases) {
    test(`${selector} stops automatically moving for either motion opt-out`, () => {
        assert.ok(timing(selector, property, false, false) > 0);
        assert.equal(timing(selector, property, true, false), 0, 'system Reduce Motion');
        assert.equal(timing(selector, property, false, true), 0, 'NewsBlur no animations');
    });
}

function fixture(disabled = true) {
    const timers = [];
    const context = {
        NEWSBLUR: { Views: {}, Globals: {}, utils: { is_rtl: () => false },
            motion: { duration: value => disabled ? 0 : value } },
        Backbone: { View: { extend: definition => definition }, Router: { extend: definition => definition } },
        _: { delay: (fn, ms) => timers.push({ fn, ms }), isNaN: Number.isNaN },
        setTimeout: (fn, ms) => timers.push({ fn, ms }), clearTimeout() {},
        document: { body: {} },
        getComputedStyle: () => ({ getPropertyValue: () => disabled ? '0ms' : '380ms' }),
        $() {}, jQuery() {}
    };
    for (const file of ['views/mobile_layout_view.js', 'views/mobile_story_pager_view.js', 'reader/reader.js']) {
        vm.runInNewContext(read('media/js/newsblur/' + file), context);
    }
    function element() {
        const classes = new Set();
        const element = {
            0: { style: {} }, classes,
            addClass(value) { value.split(' ').forEach(c => classes.add(c)); return this; },
            removeClass(value) { value.split(' ').forEach(c => classes.delete(c)); return this; },
            toggleClass(value, on) { if (on) classes.add(value); else classes.delete(value); return this; },
            css(name, value) { if (typeof name === 'object') Object.assign(this[0].style, name); else this[0].style[name] = value; return this; },
            on() { return this; }, off() { return this; }
        };
        return element;
    }
    return { context, timers, element, layout: context.NEWSBLUR.Views.MobileLayout, pager: context.NEWSBLUR.Views.MobileStoryPager };
}

test('reader body follows the animations preference on load and after a save', () => {
    const f = fixture();
    const body = f.element();
    let enabled = false;
    const reader = { $s: { $body: body }, model: { preference: name => name === 'animations' ? enabled : undefined } };
    f.context.NEWSBLUR.Reader.add_body_classes.call(reader);
    assert.ok(body.classes.has('NB-no-animations'));
    enabled = 0;
    f.context.NEWSBLUR.Reader.add_body_classes.call(reader);
    assert.ok(body.classes.has('NB-no-animations'));
    enabled = true;
    f.context.NEWSBLUR.Reader.add_body_classes.call(reader);
    assert.ok(!body.classes.has('NB-no-animations'));
});

for (const dismiss of [false, true]) {
    test(`sheet ${dismiss ? 'dismissal' : 'snapback'} finishes without a delayed slide when motion is disabled`, () => {
        const f = fixture();
        const sheet = f.element(), overlay = f.element();
        let closed = false;
        const view = { sheet_drag: { axis: 'vertical', $sheet: sheet, $overlay: overlay,
            sheet: { close: () => { closed = true; }, reused: true }, held: false,
            samples: [{ y: 0, t: 0 }, { y: 120, t: 100 }], dy: 120, height: 500 },
            utils: { swipe_completes: () => dismiss } };
        f.layout.handle_sheet_touchend.call(view);
        assert.equal(f.timers.length, 0, 'no delayed cleanup or close');
        assert.equal(closed, dismiss);
        assert.equal(sheet[0].style.transform, '');
        assert.equal(sheet[0].style.transition, '');
    });
}

test('Next selects the next story immediately when the CSS transition cannot emit transitionend', () => {
    const f = fixture();
    const target = {};
    let selected;
    const view = { mobile: { sync_page_scroll: () => {} }, $track: f.element(), neighbors: () => ({ next: target }), finish_page: (step, story) => { selected = story; } };
    f.pager.page_to.call(view, 1);
    assert.equal(selected, target);
    assert.equal(f.timers.length, 0);
    assert.equal(view.page_turn, null);
});

test('a cancelled story swipe clears its animating class immediately with motion disabled', () => {
    const f = fixture();
    const view = { $track: f.element() };
    f.pager.snap_back.call(view);
    assert.ok(!view.$track.classes.has('NB-mobile-animating'));
    assert.equal(f.timers.length, 0);
});

test('Next still waits for the animated page turn when motion is enabled', () => {
    const f = fixture(false);
    const target = {};
    let selected;
    const view = { mobile: { sync_page_scroll: () => {} }, $track: f.element(), neighbors: () => ({ next: target }), finish_page: (step, story) => { selected = story; } };
    f.pager.page_to.call(view, 1);
    assert.equal(selected, undefined);
    assert.ok(view.$track.classes.has('NB-mobile-animating'));
    assert.equal(f.timers.length, 1);
    assert.ok(f.timers[0].ms >= 320);
    f.timers[0].fn();
    assert.equal(selected, target);
});

test('a screen change with motion disabled completes synchronously', () => {
    const f = fixture();
    let completed = false;
    const view = { active: true, screen: 'feeds', transition_duration: () => 0,
        set_screen: value => { view.screen = value; }, finish_transition() { throw new Error('must not begin animated transition'); } };
    f.layout.show_screen.call(view, 'titles', { complete: () => { completed = true; } });
    assert.equal(view.screen, 'titles');
    assert.equal(completed, true);
    assert.equal(f.timers.length, 0);
});
