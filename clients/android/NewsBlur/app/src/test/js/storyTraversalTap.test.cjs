// storyTraversalTap.test.cjs exercises the actual DOM event path for traversal reveal.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const listeners = {};
const messages = [];
let selected = false;
const context = vm.createContext({
    window: {
        NB_image_listeners_installed: true,
        NewsBlurReader: { postMessage: value => messages.push(value) },
        getSelection: () => ({ isCollapsed: !selected }),
    },
    document: {
        querySelector: () => ({ content: '7' }),
        addEventListener: (name, callback) => (listeners[name] ||= []).push(callback),
    },
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../main/assets/storyDetailView.js'), 'utf8'), context);
const text = { tagName: 'P', closest: selector => selector === '.NB-story' ? {} : null };
function click(target = text, options = {}) {
    for (const listener of listeners.click || []) {
        listener({ target, isTrusted: true, detail: 1, defaultPrevented: false,
            preventDefault() { throw new Error('Traversal must not consume clicks'); },
            stopImmediatePropagation() { throw new Error('Traversal must not consume clicks'); }, ...options });
    }
}
click();
assert.deepEqual(messages, ['7'], 'A plain story tap must request traversal for the current document');
messages.length = 0;
click({ ...text, closest: selector => selector === '[data-nb-listen-block]' ? {} : text.closest(selector) });
assert.deepEqual(messages, ['7'], 'Listen paragraph markers must not disable plain taps after playback');
messages.length = 0;
for (const tagName of ['A', 'IMG', 'VIDEO', 'AUDIO', 'BUTTON', 'INPUT', 'SELECT', 'TEXTAREA', 'SUMMARY']) {
    click({ tagName, closest: selector => selector === '.NB-story' ? {} : { tagName } });
}
click(text, { defaultPrevented: true });
click(text, { isTrusted: false });
click(text, { detail: 2 });
selected = true;
click();
assert.deepEqual(messages, [], 'Interactive, double, synthetic and selection taps must keep their own behavior');
console.log('PASS: blank taps reveal traversal without consuming interactive content or selection');
