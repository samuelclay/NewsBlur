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
assert.equal(messages[0].browserSrc, image.currentSrc, 'Open Image must use the displayed photo, not its enclosing article link');
function linked_image(href, source = image) {
    const anchor = new URL(href);
    return { ...source, closest: selector => selector === 'a[href]' ? anchor : source.closest(selector) };
}
const linked_thumbnail = linked_image('https://example.com/article?preview=photo.jpg');
context.NB_open_story_image(linked_thumbnail, true);
assert.equal(messages.at(-1).link, 'https://example.com/article?preview=photo.jpg');
assert.equal(messages.at(-1).browserSrc, image.currentSrc, 'Linked photos keep distinct image and article actions');
attributes['data-nb-original-src'] = 'https://example.com/offline-original.jpg';
context.NB_open_story_image({ ...image, currentSrc: 'https://appassets.androidplatform.net/images/123.jpg' }, true);
assert.equal(messages.at(-1).browserSrc, attributes['data-nb-original-src'], 'A cached image must retain its public browser URL');
context.NB_open_story_image(image, true);
assert.equal(messages.at(-1).browserSrc, image.currentSrc, 'A responsive remote image must use currentSrc even if another source was cached');
delete attributes['data-nb-original-src'];
assert.equal(context.NB_story_image_rect('1', 6), null);
assert.equal(context.NB_story_image_rect('1\"]', 7), null);
generation = '8';
assert.equal(context.NB_story_image_rect('1', 7), null);

let prevented = false, stopped = false;
listeners.click({ target: image, preventDefault() { prevented = true; }, stopImmediatePropagation() { stopped = true; } });
assert.ok(prevented && stopped, 'A standalone photo tap opens the viewer');

const before_tap = messages.length;
prevented = stopped = false;
listeners.click({ target: linked_thumbnail, preventDefault() { prevented = true; }, stopImmediatePropagation() { stopped = true; } });
assert.equal(prevented || stopped, false, 'A single tap on a linked thumbnail must follow its article link');
assert.equal(messages.length, before_tap, 'Following the article must not also open the photo viewer');

const full_size_photo = linked_image('https://example.com/photo-full.jpg?width=1800');
const before_photo = messages.length;
listeners.click({ target: full_size_photo, preventDefault() { prevented = true; }, stopImmediatePropagation() { stopped = true; } });
assert.ok(prevented && stopped, 'Tapping a full-size photo link keeps the reader open');
assert.equal(messages.length, before_photo + 1, 'A link directly to a full-size photo opens the viewer');

const full_url = full_size_photo.closest('a[href]').href;
assert.equal(messages.at(-1).src, full_url, 'The viewer loads the full-size linked photo');
assert.equal(messages.at(-1).browserSrc, full_url, 'Open Image in Browser uses the full-size photo too');

const original_url = 'https://example.com/media/1234';
const cached_photo = linked_image(original_url, { ...image, currentSrc: 'https://appassets.androidplatform.net/images/123.jpg' });
attributes['data-nb-original-src'] = original_url;
assert.equal(context.NB_open_story_image(cached_photo, false), true, 'An offline photo keeps its extensionless original URL in the viewer');
assert.equal(messages.at(-1).src, cached_photo.currentSrc, 'Use the cached file when it is already the link target');
assert.equal(messages.at(-1).browserSrc, original_url);
context.NB_open_story_image(linked_image(full_url, cached_photo), false);
assert.equal(messages.at(-1).src, full_url);
assert.equal(messages.at(-1).thumbnailSrc, cached_photo.currentSrc, 'Keep a smaller cached photo available for an offline fallback');
assert.equal(context.NB_open_story_image(linked_image('file:///private/photo.jpg'), false), false);
delete attributes['data-nb-original-src'];

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
console.log('PASS: image source selection, linked-thumbnail navigation, document generations, protected icons, and invalid images');
