// test_modal_motion.cjs guards the styled dialog during its dismissal animation.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('dialog dismissal preserves its live styling until the exit finishes', () => {
    let callbacks, finish, closed = 0, disconnected = 0;
    function element() {
        return { 0: { style: {} }, removed: false,
            hide() { return this; }, empty() { return this; },
            remove() { this.removed = true; return this; },
            fadeOut(_, done) { done?.(); return this; }
        };
    }
    const holder = element(), $ = () => holder;
    $.modal = { close() { closed++; } };
    const NEWSBLUR = { motion: {
        depart() {}, duration: value => value,
        exit(_, complete) { finish = complete; }
    } };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/common/modal.js', 'utf8'), { NEWSBLUR, $ });
    const modal = Object.create(NEWSBLUR.Modal.prototype);
    Object.assign(modal, { options: {}, flags: {}, $modal: { modal(value) { callbacks = value; } },
        section_motion_owner: { motion_observer: { disconnect() { disconnected++; } } } });
    modal.open_modal();
    const dialog = { data: element(), container: element(), overlay: element() };
    callbacks.onClose(dialog);
    assert.equal(disconnected, 1, 'Closing stops pending section entrances before the exit');
    assert.equal(dialog.container.removed, false);
    assert.equal(dialog.data.removed, false);
    assert.equal(closed, 0);
    finish();
    assert.equal(dialog.container.removed, true);
    assert.equal(dialog.data.removed, true);
    assert.equal(closed, 1);
});

test('dialog sections are prepared before the parent entrance makes them transparent', () => {
    let callbacks;
    const order = [];
    function element() {
        return { 0: { style: {} }, addClass() { return this; }, show() { return this; },
            fadeIn(_, done) { done(); } };
    }
    const NEWSBLUR = { motion: { duration: value => value, enter(element) {
        element.style.opacity = '0';
        order.push('parent');
    } } };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/common/modal.js', 'utf8'), {
        NEWSBLUR, $: {}, setTimeout() {}
    });
    const modal = Object.create(NEWSBLUR.Modal.prototype);
    const dialog = { data: element(), container: element(), overlay: element() };
    Object.assign(modal, { options: {}, flags: {}, $modal: { modal(value) { callbacks = value; } },
        resize() {}, animate_sections() {
            assert.notEqual(dialog.container[0].style.opacity, '0');
            assert.equal(this.section_motion_root, dialog.container[0]);
            order.push('sections');
        }
    });
    modal.open_modal();
    callbacks.onOpen(dialog);
    assert.deepEqual(order, ['sections', 'parent']);
});
