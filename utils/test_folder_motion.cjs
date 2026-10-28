// test_folder_motion.cjs exercises actual folder navigation after motion setup.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('clicking a folder title opens its story river', () => {
    let definition;
    let opened;
    const title = {};
    const folder = {};
    const model = {};
    const $el = {};
    const context = {
        NEWSBLUR: { Views: {}, reader: { open_river_stories: (...args) => { opened = args; } } },
        Backbone: { View: { extend: value => { definition = value; return value; } } },
        $: value => value === title ? { 0: title, closest: () => [folder] } : { length: 0 }
    };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/views/folder_view.js', 'utf8'), context);
    definition.open.call({ options: {}, el: folder, $el, model, $: () => [title] }, {
        currentTarget: title, which: 1, preventDefault() {}, stopPropagation() {}
    });
    assert.deepEqual(opened, [$el, model]);
});

test('toggling a folder finishes previous child motion before choosing its new transition', () => {
    let definition;
    const calls = [];
    const folder = {};
    const children = {
        stop(clear_queue, finish) { calls.push(['stop', clear_queue, finish]); return this; },
        animate() { calls.push(['collapse']); return this; }
    };
    const context = {
        NEWSBLUR: { Views: {}, log() {}, motion: { duration: value => value } },
        Backbone: { View: { extend: value => { definition = value; return value; } } },
        $: () => ({ closest: () => [folder] })
    };
    vm.runInNewContext(fs.readFileSync('media/js/newsblur/views/folder_view.js', 'utf8'), context);
    definition.collapse_folder.call({
        options: { feed_chooser: true }, el: folder, collection: {},
        $el: { children: () => children, addClass() {} }
    }, { preventDefault() {}, stopPropagation() {} }, { force_collapse: true });
    assert.deepEqual(calls, [['stop', true, true], ['collapse']]);
});
