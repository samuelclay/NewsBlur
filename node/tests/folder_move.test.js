const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

test('a rejected folder move reports the reason, keeps the picker open and permits retry', () => {
    const messages = [];
    const reader_ui = [];
    let request;
    const backbone = { extend: methods => methods };
    const context = {
        Backbone: { Router: backbone, Model: backbone, Collection: backbone },
        NEWSBLUR: { Models: {}, Collections: {} },
        window: { addEventListener() {}, alert: text => messages.push(text) },
        gettext: text => text,
        jQuery: {},
        _: {
            bind: (fn, obj) => fn.bind(obj), compact: a => a.filter(Boolean),
            contains: (a, v) => a.includes(v), isUndefined: v => v === undefined,
            delay: fn => fn(),
        },
    };
    for (const file of ['common/assetmodel.js', 'models/folders.js', 'reader/reader.js']) {
        vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur', file), 'utf8'), context);
    }
    const app = context.NEWSBLUR;
    const model = Object.create(app.Models.FeedOrFolder);
    model.collection = { options: { title: 'Queue' }, parent_folder_names: () => ['Queue', 'Work'] };
    model.get = () => 'Saved';
    app.assets = Object.create(app.AssetModel);
    app.assets.folders = { get_view: () => ({ model }), reset: () => reader_ui.push('reset') };
    app.assets.make_request = (url, params, success, failure) => { request = { params, success, failure }; };
    app.reader = Object.create(app.Reader);
    app.reader.$s = { $feed_list: { css() { return this; }, animate() {} } };
    app.reader.flags = { showing_confirm_input_on_manage_menu: true };
    app.reader.folder_picker = { selected: ['Archive'], original: ['Queue'], disabled: [] };
    app.reader.hide_confirm_move_menu_item = () => reader_ui.push('closed picker');
    app.reader.hide_manage_menu = () => reader_ui.push('closed menu');

    app.reader.manage_menu_move_folder('Saved', {});
    assert.equal(app.reader.flags.reloading_feeds, true);
    assert.deepEqual(reader_ui, []);
    assert.deepEqual(JSON.parse(request.params.in_folder_path), ['Work', 'Queue']);
    request.failure({ code: -1, message: 'The destination changed.' });
    assert.deepEqual(messages, ['The destination changed.']);
    assert.deepEqual(reader_ui, []);
    assert.equal(app.reader.flags.reloading_feeds, false);

    const rejected_request = request;
    app.reader.manage_menu_move_folder('Saved', {});
    assert.notEqual(request, rejected_request);
    request.success({ code: 1, folders: [{ Archive: [{ Saved: [7] }] }] });
    assert.deepEqual(reader_ui, ['reset', 'closed picker', 'closed menu']);
    assert.equal(app.reader.flags.reloading_feeds, false);
});
