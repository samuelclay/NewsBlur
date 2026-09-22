// storyImageViewer.test.cjs exercises the reader's real image bridge without network or an account.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const script = fs.readFileSync(path.join(__dirname, '../../main/assets/storyDetailView.js'), 'utf8');
const listeners = {};
const messages = [];
let generation = '7';
const attributes = {};
const image = {
    tagName: 'IMG', complete: true, naturalWidth: 1200, naturalHeight: 800,
    currentSrc: 'https://example.com/retina.jpg', src: 'https://example.com/small.jpg', alt: 'Image description',
    classList: { contains: () => false },
    closest: selector => selector === '.NB-story' ? {} : null,
    getAttribute: name => attributes[name], setAttribute: (name, value) => { attributes[name] = value; },
    getBoundingClientRect: () => ({ left: 20, top: 200, width: 360, height: 240 }),
};
const context = vm.createContext({
    window: { NewsBlurImages: { postMessage: json => messages.push(JSON.parse(json)) } },
    document: {
        documentElement: { clientWidth: 400 },
        querySelector: selector => selector.startsWith('meta') ? { content: generation } : image,
        addEventListener: (name, callback) => { listeners[name] = callback; },
    },
});
vm.runInContext(script.slice(0, script.indexOf('function setImageClass')), context);

assert.equal(context.NB_open_story_image(image), true);
assert.equal(messages[0].src, image.currentSrc);
assert.equal(messages[0].title, image.alt);
assert.equal(messages[0].generation, '7');
assert.equal(messages[0].rect.width, 360);
assert.equal(context.NB_story_image_rect('1', 6), null);
assert.equal(context.NB_story_image_rect('1\"]', 7), null);
generation = '8';
assert.equal(context.NB_story_image_rect('1', 7), null);

let prevented = false, stopped = false;
listeners.click({ target: image, preventDefault() { prevented = true; }, stopImmediatePropagation() { stopped = true; } });
assert.ok(prevented && stopped, 'Image taps must not also open an enclosing link');

for (const change of [
    { complete: false }, { naturalWidth: 1 }, { naturalHeight: 1 }, { tagName: 'VIDEO' },
    { currentSrc: 'file:///private.png' }, { currentSrc: 'data:text/html,hello' },
    { closest: () => null }, { classList: { contains: name => name === 'NB-briefing-inline-favicon' } },
]) {
    assert.equal(context.NB_open_story_image({ ...image, ...change }), false);
}
assert.equal(context.NB_open_story_image({ ...image, currentSrc: 'data:image/png;base64,AAAA' }), true);
assert.equal(context.NB_open_story_image({ ...image, currentSrc: 'https://appassets.androidplatform.net/images/123.png' }), true);
context.window.NewsBlurImages = undefined;
assert.equal(context.NB_open_story_image(image), false, 'Older WebViews retain their existing image/link behavior');
console.log('PASS: image source selection, linked-image interception, document generations, protected icons, and invalid images');
