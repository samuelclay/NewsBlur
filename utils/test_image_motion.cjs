// test_image_motion.cjs checks modal keyboard isolation and native dialog dismissal.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness() {
    class Element {
        constructor(tag) { this.tag = tag; this.nodeName = tag.toUpperCase(); this.listeners = {}; this.children = []; this.isConnected = true; }
        appendChild(child) { child.parentNode = this; this.children.push(child); }
        addEventListener(type, callback) { (this.listeners[type] ||= []).push(callback); }
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
            stopPropagation() { this.propagationStopped = true; }
        };
        for (let node = target; node; node = node.parentNode) {
            for (const listener of node.listeners[type] || []) listener.call(node, event);
            if (event.propagationStopped || !properties.bubbles) break;
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
    vm.runInNewContext(fs.readFileSync('media/js/vendor/jquery.hotkeys.js', 'utf8'), { NEWSBLUR: {}, jQuery });
    function bind_escape(handler) {
        const registration = { data: 'esc', handler };
        jQuery.event.special.keydown.add(registration);
        document.addEventListener('keydown', registration.handler);
    }
    return { document, dialog, close, prior_focus, dispatch, bind_escape };
}

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
