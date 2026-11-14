// storyTraversalTap.test.cjs exercises single-tap hit testing and prevents immediate click reveals.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const listeners = {};
const messages = [];
let selected = false;
let hit;
let point;
function element(tag, parent = null, attributes = {}, classes = []) {
    return {
        tagName: tag.toUpperCase(), parentElement: parent,
        closest(selector) {
            for (let node = this; node; node = node.parentElement) {
                if (selector.split(',').some(part => {
                    if (part[0] === '.') return node.classes.includes(part.slice(1));
                    const attribute = part.match(/^\[([^=\]]+)(?:="([^"]*)")?\]$/);
                    if (attribute) return attribute[1] in node.attributes &&
                        (attribute[2] === undefined || node.attributes[attribute[1]] === attribute[2]);
                    return node.tagName === part.toUpperCase();
                })) return node;
            }
            return null;
        }, attributes, classes,
    };
}
const story = element('div', null, {}, ['NB-story']);
const text = element('p', story);
hit = text;
const context = vm.createContext({
    window: {
        NB_image_listeners_installed: true,
        NewsBlurReader: { postMessage: value => messages.push(value) },
        getSelection: () => ({ isCollapsed: !selected }),
    },
    document: {
        documentElement: { clientWidth: 400 },
        querySelector: () => ({ content: '7' }),
        elementFromPoint: (x, y) => { point = [x, y]; return hit; },
        addEventListener: (name, callback) => (listeners[name] ||= []).push(callback),
    },
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../main/assets/storyDetailView.js'), 'utf8'), context);
for (const listener of listeners.click || []) listener({ target: text, isTrusted: true, detail: 1 });
assert.deepEqual(messages, [], 'The first click of a possible native double tap must not reveal traversal');
const blankTap = () => context.NB_is_blank_story_tap_at(300, 600, 1200);
assert.equal(blankTap(), true);
assert.deepEqual(point, [100, 200], 'Native coordinates must be scaled to CSS viewport coordinates');
context.window.visualViewport = { width: 200, offsetLeft: 12, offsetTop: 24 };
assert.equal(blankTap(), true);
assert.deepEqual(point, [62, 124], 'Pinch zoom and viewport pan must hit the visible content');
for (const tag of ['a', 'img', 'video', 'audio', 'iframe', 'button', 'input', 'select', 'textarea', 'summary', 'label']) {
    hit = element('span', element(tag, story));
    assert.equal(blankTap(), false, `A descendant of ${tag} must keep its own tap action`);
}
for (const attributes of [{contenteditable: 'true'}, {role: 'button'}, {role: 'link'}]) {
    hit = element('span', element('div', story, attributes));
    assert.equal(blankTap(), false);
}
hit = element('span', element('div', story, {}, ['NB-media-card']));
assert.equal(blankTap(), false);
hit = element('p', story, {'data-nb-listen-block': '0'});
assert.equal(blankTap(), true, 'Stale Listen markers must not disable plain taps');
selected = true;
assert.equal(blankTap(), false, 'Selected text must keep its selection');
selected = false;
hit = element('p');
assert.equal(blankTap(), false, 'Native header controls are outside story content');
console.log('PASS: confirmed tap hit-testing excludes interactive content and selection');
