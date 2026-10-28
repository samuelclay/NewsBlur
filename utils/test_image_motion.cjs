// test_image_motion.cjs checks modal keyboard isolation and native dialog dismissal.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness() {
    class Element {
        constructor(tag) { this.tag = tag; this.nodeName = tag.toUpperCase(); this.listeners = {}; this.children = []; this.isConnected = true; }
        appendChild(child) { child.parentNode = this; this.children.push(child); }
        addEventListener(type, callback, capture = false) { (this.listeners[type] ||= []).push({ callback, capture }); }
        removeEventListener(type, callback, capture = false) {
            this.listeners[type] = (this.listeners[type] || []).filter(entry => entry.callback !== callback || entry.capture !== capture);
        }
        setAttribute() {}
        showModal() { this.open = true; }
        close() { this.open = false; }
        remove() { this.isConnected = false; }
        focus() { document.activeElement = this; }
        getBoundingClientRect() { return { left: 0, top: 0, bottom: 100, width: 100, height: 100 }; }
    }
    function dispatch(target, type, properties = {}) {
        const event = {
            target, type, defaultPrevented: false, propagationStopped: false, ...properties,
            preventDefault() { this.defaultPrevented = true; },
            stopPropagation() { this.propagationStopped = true; },
            stopImmediatePropagation() { this.propagationStopped = true; this.immediateStopped = true; }
        };
        const path = [];
        for (let node = target; node; node = node.parentNode) path.push(node);
        function deliver(node, capture) {
            for (const listener of [...(node.listeners[type] || [])]) {
                if (listener.capture === capture) listener.callback.call(node, event);
                if (event.immediateStopped) break;
            }
        }
        for (const node of [...path].reverse()) {
            deliver(node, true);
            if (event.propagationStopped) return event;
        }
        for (const node of path) {
            deliver(node, false);
            if (event.propagationStopped || !properties.bubbles) return event;
        }
        return event;
    }
    const document = new Element('document');
    document.body = new Element('body');
    document.appendChild(document.body);
    document.createElement = tag => new Element(tag);
    const prior_focus = new Element('article');
    document.activeElement = prior_focus;
    let open_image;
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/common/image_motion.js', 'utf8'), {
        document,
        window: { HTMLDialogElement: Element, matchMedia: () => ({ matches: true }) },
        innerHeight: 800,
        gettext: text => text,
        $: target => target === document ? { on: (_, selector, handler) => { open_image = handler; } } : { closest: () => ({ length: 0 }) },
        NEWSBLUR: { motion: { enter() {} } }
    });
    const source = new Element('img');
    source.naturalWidth = 100;
    source.src = '/test-image.png';
    open_image.call(source, {});
    const dialog = document.body.children[0];
    const close = dialog.children[1];
    const jQuery = {
        event: { special: {} },
        each: (items, callback) => items.forEach(item => callback.call(item))
    };
    const newsblur = {};
    vm.runInNewContext(fs.readFileSync('media/js/vendor/jquery.hotkeys.js', 'utf8'), { NEWSBLUR: newsblur, jQuery });
    document.addEventListener('keydown', event => newsblur.hotkeys.down(event));
    document.addEventListener('keyup', event => newsblur.hotkeys.up(event));
    function bind_key(key, handler, type = 'keydown') {
        const registration = { data: key, handler };
        jQuery.event.special[type].add(registration);
        document.addEventListener(type, registration.handler);
    }
    return { document, dialog, close, prior_focus, dispatch, bind_key, hotkeys: newsblur.hotkeys,
        bind_escape: handler => bind_key('esc', handler) };
}

test('character shortcuts stay inside the dialog while modifier tracking remains current', () => {
    const h = harness();
    let reader_actions = 0;
    h.bind_key('a', event => { event.preventDefault(); reader_actions++; }, 'keypress');
    const key = h.dispatch(h.close, 'keypress', { key: 'a', keyCode: 97, which: 97, bubbles: true });
    assert.equal(reader_actions, 0, 'Reader article actions must not run behind the modal');
    assert.equal(key.defaultPrevented, false);
    h.dispatch(h.close, 'keydown', { key: 'Shift', keyCode: 16, which: 16, bubbles: true });
    assert.equal(h.hotkeys.shift, true);
    h.dispatch(h.close, 'keyup', { key: 'Shift', keyCode: 16, which: 16, bubbles: true });
    assert.equal(h.hotkeys.shift, false, 'Releasing a modifier inside the dialog must clear its tracked state');
});

for (const [key, code, shortcut] of [['Enter', 13, 'return'], [' ', 32, 'space']]) {
    test(`${shortcut} keeps native close-button activation without triggering reader shortcuts`, () => {
        const h = harness();
        let reader_actions = 0;
        h.bind_key(shortcut, event => { event.preventDefault(); reader_actions++; });
        const event = h.dispatch(h.close, 'keydown', { key, keyCode: code, which: code, bubbles: true });
        assert.equal(reader_actions, 0, 'The real hotkey wrapper must not dispatch outside the modal');
        assert.equal(event.defaultPrevented, false, 'Native button activation must remain available');
        // test_image_motion.cjs models the browser activation only when keydown permits its default action.
        if (!event.defaultPrevented) h.close.onclick();
        assert.equal(h.dialog.isConnected, false);
        assert.equal(h.document.activeElement, h.prior_focus);
    });
}

test('Tab stays native and does not escape to reader shortcuts', () => {
    const h = harness();
    let reader_actions = 0;
    h.bind_key('tab', event => { event.preventDefault(); reader_actions++; });
    const event = h.dispatch(h.close, 'keydown', { key: 'Tab', keyCode: 9, which: 9, bubbles: true });
    assert.equal(reader_actions, 0);
    assert.equal(event.defaultPrevented, false);
    assert.equal(h.dialog.open, true);
});

for (const target of ['document', 'body']) {
    test(`Escape closes the modal after native focus leaves its button for ${target}`, () => {
        const h = harness();
        let dashboard_navigations = 0;
        h.bind_escape(event => { event.preventDefault(); dashboard_navigations++; });
        const focused = target === 'document' ? h.document : h.document.body;
        focused.focus();
        h.dispatch(focused, 'keydown', { key: 'Escape', keyCode: 27, which: 27, bubbles: true });
        assert.equal(dashboard_navigations, 0);
        assert.equal(h.dialog.open, false);
        h.dispatch(h.document.body, 'keydown', { key: 'Escape', keyCode: 27, which: 27, bubbles: true });
        assert.equal(dashboard_navigations, 1, 'Closing the image must restore reader keyboard shortcuts');
    });
}

test('reader shortcuts stay blocked after native focus leaves the dialog', () => {
    const h = harness();
    let reader_actions = 0;
    h.bind_key('return space', event => { event.preventDefault(); reader_actions++; });
    h.bind_key('a', event => { event.preventDefault(); reader_actions++; }, 'keypress');
    h.document.body.focus();
    h.dispatch(h.document.body, 'keydown', { key: 'Enter', keyCode: 13, which: 13, bubbles: true });
    h.dispatch(h.document.body, 'keydown', { key: ' ', keyCode: 32, which: 32, bubbles: true });
    h.dispatch(h.document.body, 'keypress', { key: 'a', keyCode: 97, which: 97, bubbles: true });
    assert.equal(reader_actions, 0);
});

test('Escape dismisses the image without invoking the reader dashboard shortcut', () => {
    const h = harness();
    let dashboard_navigations = 0;
    h.bind_escape(event => {
        // reader.js handles Escape through jquery.hotkeys.js at document level.
        event.preventDefault();
        dashboard_navigations++;
    });
    const key = h.dispatch(h.close, 'keydown', { key: 'Escape', keyCode: 27, which: 27, bubbles: true });
    assert.equal(dashboard_navigations, 0, 'The modal must keep Escape away from reader.js');
    assert.equal(key.defaultPrevented, true, 'The modal owns dismissal for every supported Escape event');
    assert.equal(h.dialog.isConnected, false);
    assert.equal(h.document.activeElement, h.prior_focus);
});

test('Escape events recognized by jquery.hotkeys stay inside the image dialog even without event.key', () => {
    const h = harness();
    let dashboard_navigations = 0;
    h.bind_escape(event => { event.preventDefault(); dashboard_navigations++; });
    const key = h.dispatch(h.close, 'keydown', { keyCode: 27, which: 27, bubbles: true });
    assert.equal(dashboard_navigations, 0);
    assert.equal(key.defaultPrevented, true);
    assert.equal(h.dialog.isConnected, false, 'Key-code-only Escape must also run the dismiss flow');
    assert.equal(h.document.activeElement, h.prior_focus);
});

test('native dialog cancel and the close button remain accessible without keyboard events', () => {
    const native = harness();
    const cancel = native.dispatch(native.dialog, 'cancel');
    assert.equal(cancel.defaultPrevented, true, 'The existing dismiss flow owns the close animation');
    assert.equal(native.dialog.open, false);
    assert.equal(native.document.activeElement, native.prior_focus);

    const button = harness();
    button.close.onclick();
    assert.equal(button.dialog.isConnected, false);
    assert.equal(button.document.activeElement, button.prior_focus);
});
