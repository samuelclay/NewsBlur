// test_ios_reader_motion.cjs runs the article's real motion code without a native bridge.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function article(reduced = false, observe = false) {
    const animations = [];
    const nodes = [];
    const root = {
        querySelectorAll(selector) {
            return nodes.filter(node => selector.split(',').some(s => s.trim() === node.selector));
        }
    };
    function add(selector) {
        const node = { selector, parentElement: root, id: '', className: selector.startsWith('.') ? selector.slice(1) : '', innerHTML: '',
            getAttribute() { return null; },
            animate(frames, options) { animations.push({ node: this, frames, options }); },
            getBoundingClientRect() { return { top: 10, bottom: 40 }; },
            getClientRects() { return [{}]; }
        };
        nodes.push(node);
        return node;
    }
    const source = fs.readFileSync('clients/ios/static/storyDetailView.js', 'utf8');
    const preference = { matches: reduced };
    let observer;
    const context = { document: root, window: { matchMedia: () => preference, innerHeight: 800 },
        WeakSet, Array, Math };
    if (observe) {
        context.window.IntersectionObserver = true;
        context.IntersectionObserver = class {
            constructor(callback) { this.callback = callback; this.targets = new Set(); observer = this; }
            observe(node) { this.targets.add(node); }
            unobserve(node) { this.targets.delete(node); }
        };
    }
    vm.runInNewContext(source.slice(source.indexOf('// storyDetailView.js starts motion'),
        source.indexOf('// storyDetailView.js adds feedback')), context);
    function replace(old, values = {}) {
        const node = { ...old, ...values, isConnected: true };
        old.isConnected = false;
        nodes.splice(nodes.indexOf(old), 1, node);
        return node;
    }
    return { add, replace, animations, context, preference, get observer() { return observer; } };
}

test('native article cascades each action, social section, comment and cluster independently', () => {
    const h = article();
    const actions = Array.from({ length: 5 }, () => h.add('.NB-share-button'));
    const sections = ['.NB-story-shares', '.NB-story-comment', '.NB-story-cluster-detail-header',
        '.NB-story-cluster-detail-item'].map(h.add);
    h.context.newsblurAnimateStoryEntrance();
    for (const node of [...actions, ...sections]) {
        assert.ok(h.animations.some(animation => animation.node === node), node.selector);
    }
    const actionAnimations = h.animations.filter(animation => actions.includes(animation.node));
    for (let index = 1; index < actionAnimations.length; index++) {
        assert.ok(actionAnimations[index].options.delay > actionAnimations[index - 1].options.delay);
    }
    const count = h.animations.length;
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, count, 'unchanged article must not replay');
    const comment = h.add('.NB-story-comment');
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, count + 1);
    assert.equal(h.animations.at(-1).node, comment);
});

test('native article Reduce Motion renders all sections without animation', () => {
    const h = article(true);
    h.add('.NB-share-button');
    h.add('.NB-story-comment');
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, 0);
});

test('hidden actions wait for visibility and comment replies do not double animate', () => {
    const h = article();
    const hidden = h.add('.NB-share-button');
    hidden.getClientRects = () => [];
    const comment = h.add('.NB-story-comment');
    const reply = h.add('.NB-story-comment-reply');
    reply.parentElement = comment;
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 0, 'refresh before native paint must not consume the entrance');
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, 1);
    assert.equal(h.animations[0].node, comment);
    hidden.getClientRects = () => [{}];
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 2);
    assert.equal(h.animations.at(-1).node, hidden);
});

test('offscreen sections wait for appearance, enter top to bottom, and respect a later Reduce Motion change', () => {
    const h = article(false, true);
    const lower = h.add('.NB-story-cluster-detail-item');
    const upper = h.add('.NB-story-cluster-detail-item');
    lower.getBoundingClientRect = () => ({ top: 950, bottom: 990, left: 0 });
    upper.getBoundingClientRect = () => ({ top: 900, bottom: 940, left: 0 });
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, 0);
    const entry = node => ({ target: node, isIntersecting: true, boundingClientRect: node.getBoundingClientRect() });
    h.observer.callback([entry(lower), entry(upper)]);
    assert.equal(h.animations[0].node, upper);
    assert.ok(h.animations[1].options.delay > h.animations[0].options.delay);
    assert.equal(h.observer.targets.size, 0);
    const comment = h.add('.NB-story-comment');
    comment.getBoundingClientRect = lower.getBoundingClientRect;
    h.context.newsblurRefreshStoryMotion();
    h.preference.matches = true;
    h.observer.callback([entry(comment)]);
    assert.equal(h.animations.length, 2);
});

test('rebuilding identical side options does not replay and saving animates only Save', () => {
    const h = article();
    const actions = ['train', 'share-share', 'save', 'ask-ai', 'listen'].map(name => {
        const node = h.add('.NB-share-button');
        node.className += ' NB-' + name + '-button';
        node.innerHTML = name;
        return node;
    });
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, 5);
    const replacements = actions.map(node => h.replace(node));
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 5, 'font/classifier refresh must preserve unchanged controls');
    const saved = replacements.map(node => h.replace(node, node === replacements[2] ? {
        className: node.className + ' NB-button-active', innerHTML: 'Saved'
    } : {}));
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 6, 'only changed Save should animate');
    assert.equal(h.animations.at(-1).node, saved[2]);
    assert.equal(h.animations.at(-1).frames[0].opacity, 0.6, 'changed controls get a gentle update, not another full entrance');
});

test('rebuilding comments preserves unchanged identities when another comment is inserted or liked', () => {
    const h = article();
    const first = h.add('.NB-story-comment');
    first.id = 'NB-user-comment-1'; first.innerHTML = 'first comment';
    const second = h.add('.NB-story-comment');
    second.id = 'NB-user-comment-2'; second.innerHTML = 'second comment';
    h.context.newsblurAnimateStoryEntrance();
    assert.equal(h.animations.length, 2);
    h.replace(first);
    const liked = h.replace(second, { innerHTML: 'second comment, liked' });
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 3);
    assert.equal(h.animations.at(-1).node, liked);
    const third = h.add('.NB-story-comment');
    third.id = 'NB-user-comment-3'; third.innerHTML = 'new comment';
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 4);
    assert.equal(h.animations.at(-1).node, third);
});

test('an offscreen replacement keeps its first entrance on the new node', () => {
    const h = article(false, true);
    const comment = h.add('.NB-story-comment');
    comment.id = 'NB-user-comment-1'; comment.innerHTML = 'comment';
    comment.getBoundingClientRect = () => ({ top: 900, bottom: 950, left: 0 });
    h.context.newsblurAnimateStoryEntrance();
    const replacement = h.replace(comment);
    h.context.newsblurRefreshStoryMotion();
    assert.equal(h.animations.length, 0);
    assert.equal(h.observer.targets.has(comment), false);
    assert.equal(h.observer.targets.has(replacement), true);
    h.observer.callback([comment, replacement].map(node => ({ target: node, isIntersecting: true,
        boundingClientRect: node.getBoundingClientRect() })));
    assert.equal(h.animations.length, 1);
    assert.equal(h.animations[0].node, replacement);
    assert.equal(h.animations[0].frames[0].opacity, 0);
});
