const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const LIGHT = { 'NB-dark': false, 'NB-gray': false, 'NB-sepia': false };
const GRAY = { 'NB-dark': true, 'NB-gray': true, 'NB-sepia': false };

// theme_switch.test.js: reader_utils.js switch_theme_classes on a page that is only two class lists
// and, when the browser has them, view transitions that record what the page looked like when asked.
function theme_fixture(options) {
    const class_list = names => {
        const classes = new Set(names);
        return {
            classes,
            contains: name => classes.has(name),
            add: name => { classes.add(name); },
            remove: name => { classes.delete(name); },
            toggle: (name, force) => { force ? classes.add(name) : classes.delete(name); },
        };
    };
    const body = class_list(options.body || []);
    const html = class_list([]);
    const transitions = [];
    const delayed = [];
    const document = { body: { classList: body }, documentElement: { classList: html } };
    if (options.view_transitions) {
        document.startViewTransition = update => {
            const transition = { body_when_asked: [...body.classes].sort(), html_when_asked: [...html.classes].sort() };
            transition.finished = new Promise((resolve, reject) => {
                transition.finish = resolve;
                transition.skip = reject;
            });
            transitions.push(transition);
            update();
            return transition;
        };
    }
    const context = {
        NEWSBLUR: {},
        _: {
            memoize: fn => fn, map: (list, fn) => list.map(fn),
            range: count => Array.from({ length: count }, (unused, i) => i),
            each: (object, fn) => Object.keys(object).forEach(key => fn(object[key], key)),
            delay: fn => { delayed.push(fn); },
        },
        gettext: text => text,
        document,
        setTimeout: fn => { delayed.push(fn); },
    };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/reader/reader_utils.js'), 'utf8'), context);
    return {
        utils: context.NEWSBLUR.utils, transitions, delayed,
        body: () => [...body.classes].sort(),
        html: () => [...html.classes].sort(),
    };
}

test('the page is pictured in its old theme before the theme classes change', async () => {
    const page = theme_fixture({ view_transitions: true, body: ['NB-body-main', 'NB-sepia'] });

    page.utils.switch_theme_classes(GRAY, true);

    // A fade from the old picture to the new one needs the old one taken first. Classes changed
    // before the browser is asked leave it two pictures of the new theme and nothing to fade.
    assert.deepEqual(page.transitions[0].body_when_asked, ['NB-body-main', 'NB-sepia']);
    assert.deepEqual(page.body(), ['NB-body-main', 'NB-dark', 'NB-gray']);
    assert.deepEqual(page.html(), ['NB-theme-fading']);
    page.transitions[0].finish();
    await new Promise(resolve => setImmediate(resolve));
    assert.deepEqual(page.html(), []);
});

test('a fade cut short still gives the page back', async () => {
    const page = theme_fixture({ view_transitions: true, body: ['NB-body-main'] });

    page.utils.switch_theme_classes(GRAY, true);
    page.transitions[0].skip(new Error('skipped'));
    await new Promise(resolve => setImmediate(resolve));

    assert.deepEqual(page.html(), []);
    assert.deepEqual(page.body(), ['NB-body-main', 'NB-dark', 'NB-gray']);
});

test('a browser without view transitions still changes theme', () => {
    const page = theme_fixture({ view_transitions: false, body: ['NB-body-main', 'NB-dark', 'NB-gray'] });

    page.utils.switch_theme_classes(LIGHT, true);

    assert.deepEqual(page.body(), ['NB-body-main', 'NB-theme-transitioning']);
    page.delayed.forEach(fn => fn());
    assert.deepEqual(page.body(), ['NB-body-main']);
});

test('a styling change that leaves the theme alone fades nothing', () => {
    const page = theme_fixture({ view_transitions: true, body: ['NB-body-main', 'NB-dark', 'NB-gray'] });

    page.utils.switch_theme_classes(GRAY, true);

    assert.equal(page.transitions.length, 0);
    assert.deepEqual(page.body(), ['NB-body-main', 'NB-dark', 'NB-gray']);
});

test('with animations off, or on first load, the theme changes at once', () => {
    const page = theme_fixture({ view_transitions: true, body: ['NB-body-main'] });

    page.utils.switch_theme_classes(GRAY, false);

    assert.equal(page.transitions.length, 0);
    assert.deepEqual(page.body(), ['NB-body-main', 'NB-dark', 'NB-gray']);
    assert.deepEqual(page.html(), []);
});
