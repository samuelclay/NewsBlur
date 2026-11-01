const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// listen_follow_along.test.js: Just enough DOM for the block walk in
// media/js/newsblur/common/listen_follow_along.js, which only reads tags, attributes, text and
// child lists, and moves loose text into wrapper spans.
class FakeText {
    constructor(value) {
        this.nodeType = 3;
        this.nodeValue = value;
        this.parentNode = null;
    }

    get textContent() {
        return this.nodeValue;
    }
}

class FakeElement {
    constructor(tag, attributes) {
        this.nodeType = 1;
        this.tagName = tag.toUpperCase();
        this.attributes = Object.assign({}, attributes);
        this.childNodes = [];
        this.parentNode = null;
    }

    getAttribute(name) {
        return Object.prototype.hasOwnProperty.call(this.attributes, name) ? this.attributes[name] : null;
    }

    setAttribute(name, value) {
        this.attributes[name] = String(value);
    }

    removeAttribute(name) {
        delete this.attributes[name];
    }

    get className() {
        return this.getAttribute('class') || '';
    }

    set className(value) {
        this.setAttribute('class', value);
    }

    get classes() {
        return this.className.split(/\s+/).filter(Boolean);
    }

    get textContent() {
        return this.childNodes.map(function (child) { return child.textContent; }).join('');
    }

    detach(node) {
        if (!node.parentNode) return;
        const siblings = node.parentNode.childNodes;
        siblings.splice(siblings.indexOf(node), 1);
        node.parentNode = null;
    }

    appendChild(node) {
        this.detach(node);
        node.parentNode = this;
        this.childNodes.push(node);
        return node;
    }

    insertBefore(node, reference) {
        this.detach(node);
        node.parentNode = this;
        this.childNodes.splice(this.childNodes.indexOf(reference), 0, node);
        return node;
    }

    matches(selector) {
        return selector.split(',').some(function (part) {
            part = part.trim();
            if (part.charAt(0) === '.') return this.classes.indexOf(part.slice(1)) !== -1;
            return this.tagName.toLowerCase() === part.toLowerCase();
        }, this);
    }

    descendants() {
        const found = [];
        this.childNodes.forEach(function (child) {
            if (child.nodeType !== 1) return;
            found.push(child);
            found.push.apply(found, child.descendants());
        });
        return found;
    }

    querySelectorAll(selector) {
        return this.descendants().filter(function (el) { return el.matches(selector); });
    }

    querySelector(selector) {
        return this.querySelectorAll(selector)[0] || null;
    }
}

function h(tag, attributes) {
    const el = new FakeElement(tag, attributes);
    Array.prototype.slice.call(arguments, 2).forEach(function (child) {
        el.appendChild(typeof child === 'string' ? new FakeText(child) : child);
    });
    return el;
}

// listen_follow_along.test.js: The few jQuery calls listen_follow_along.js makes on these nodes.
function fake_jquery(target) {
    const nodes = Array.isArray(target) ? target.slice() : [target];
    const $nodes = Object.assign(nodes, {
        hasClass: function (name) {
            return nodes.some(function (node) { return node.classes.indexOf(name) !== -1; });
        },
        is: function (selector) {
            return nodes.some(function (node) { return node.matches(selector); });
        },
        addClass: function (name) {
            nodes.forEach(function (node) {
                if (node.classes.indexOf(name) === -1) node.className = node.classes.concat([name]).join(' ');
            });
            return $nodes;
        },
        removeClass: function (name) {
            nodes.forEach(function (node) {
                node.className = node.classes.filter(function (existing) { return existing !== name; }).join(' ');
            });
            return $nodes;
        },
        attr: function (name, value) {
            nodes.forEach(function (node) { node.setAttribute(name, value); });
            return $nodes;
        },
        removeAttr: function (name) {
            nodes.forEach(function (node) { node.removeAttribute(name); });
            return $nodes;
        }
    });
    return $nodes;
}

function load_follow_along() {
    const context = {
        NEWSBLUR: {},
        $: fake_jquery,
        window: {},
        document: {
            createElement: function (tag) { return new FakeElement(tag); }
        }
    };
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/vendor/underscore-1.4.3.js'), 'utf8'), context);
    vm.runInContext(fs.readFileSync(path.join(repo_root, 'media/js/newsblur/common/listen_follow_along.js'), 'utf8'), context);
    return context.NEWSBLUR.ListenFollowAlong;
}

function make_view(story_el) {
    return {
        _listen_map: null,
        $: function (selector) {
            const matches = story_el.matches(selector) ? [story_el] : [];
            return fake_jquery(matches.concat(story_el.querySelectorAll(selector)));
        }
    };
}

// listen_follow_along.test.js: Array.from copies out of the vm realm, so deepEqual compares values
// and not the two realms' Array prototypes.
function block_keys(blocks) {
    return Array.from(blocks, function (block) { return block.key; });
}

test('collect_blocks reads the paragraphs around an embed inside an article wrapper', function () {
    const follow_along = load_follow_along();
    // listen_follow_along.test.js: apps/listen/text.py extract_paragraphs reads this as
    // ["First", "Second"].
    const first = h('p', {}, 'First');
    const iframe = h('iframe', { src: 'https://www.youtube.com/embed/x' });
    const second = h('p', {}, 'Second');
    const wrapper = h('div', {}, first, iframe, second);
    const content = h('div', { class: 'NB-feed-story-content' }, wrapper);

    const blocks = follow_along.collect_blocks(content);

    assert.deepEqual(block_keys(blocks), ['first', 'second']);
    assert.equal(blocks[0].el, first);
    assert.equal(blocks[1].el, second);
    // listen_follow_along.test.js: Moving an iframe reloads it, so it must stay where it was.
    assert.deepEqual(wrapper.childNodes, [first, iframe, second]);
});

test('collect_blocks reads a paragraph that holds an inline embed without moving it', function () {
    const follow_along = load_follow_along();
    // listen_follow_along.test.js: apps/listen/text.py reads this as ["Watch the launch right here."].
    const iframe = h('iframe', { src: 'https://www.youtube.com/embed/x' });
    const paragraph = h('p', {}, 'Watch the launch ', iframe, ' right here.');
    const content = h('div', { class: 'NB-feed-story-content' }, paragraph);

    const blocks = follow_along.collect_blocks(content);

    assert.deepEqual(block_keys(blocks), ['watch the launch right here.']);
    assert.equal(blocks[0].el, paragraph);
    assert.equal(iframe.parentNode, paragraph);
    assert.equal(paragraph.childNodes[1], iframe);
});

test('collect_blocks never moves an inline element holding an embed into a text run', function () {
    const follow_along = load_follow_along();
    // listen_follow_along.test.js: apps/listen/text.py reads this as ["Intro text", "Para"].
    const iframe = h('iframe', { src: 'https://www.youtube.com/embed/x' });
    const embed_span = h('span', {}, iframe);
    const paragraph = h('p', {}, 'Para');
    const content = h('div', { class: 'NB-feed-story-content' }, 'Intro text ', embed_span, paragraph);

    const blocks = follow_along.collect_blocks(content);

    assert.deepEqual(block_keys(blocks), ['intro text', 'para']);
    assert.equal(embed_span.parentNode, content);
    assert.equal(iframe.parentNode, embed_span);
    assert.equal(blocks[0].el.className, 'NB-listen-run');
    assert.ok(blocks[0].el.childNodes.indexOf(embed_span) === -1);
});

test('paragraph_map highlights every server paragraph of a wrapper with a video and a figure', function () {
    const follow_along = load_follow_along();
    const opening = h('p', {}, 'Opening paragraph of the article.');
    const closing = h('p', {}, 'Closing paragraph.');
    const video = h('video', { src: 'a.mp4' });
    const story_el = h('div', { class: 'NB-feed-story' },
        h('div', { class: 'NB-feed-story-title' }, 'A title'),
        h('div', { class: 'NB-feed-story-content' },
            h('div', { class: 'entry' },
                h('div', { class: 'video' }, video),
                opening,
                h('figure', {}, h('img', { src: 'a.jpg' }), h('figcaption', {}, 'Cap')),
                closing)));
    // listen_follow_along.test.js: The paragraphs apps/listen/text.py build_paragraphs returns
    // for this story.
    follow_along.manifest = {
        manifest_id: 'manifest-1',
        paragraphs: [
            { index: 0, kind: 'title', text: 'A title' },
            { index: 1, kind: 'text', text: 'Opening paragraph of the article.' },
            { index: 2, kind: 'text', text: 'Closing paragraph.' }
        ]
    };

    const map = follow_along.paragraph_map(make_view(story_el));

    assert.equal(map[1], opening);
    assert.equal(map[2], closing);
    assert.equal(opening.getAttribute('data-listen-paragraph'), '1');
    assert.equal(closing.getAttribute('data-listen-paragraph'), '2');
    assert.equal(video.parentNode.className, 'video');
});
