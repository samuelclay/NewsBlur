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
            delay: fn => fn(), isEqual: (a, b) => JSON.stringify(a) === JSON.stringify(b),
        },
    };
    for (const file of ['common/folder_picker_utils.js', 'common/assetmodel.js', 'models/folders.js', 'reader/reader.js']) {
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
    app.reader.folder_picker = { multiple: false, selected: [], original: [], moving_folder_path: ['Work', 'Queue', 'Saved'] };
    app.assets.get_folders = () => [
        { title: 'News', children: [{ title: 'Done' }] },
        { title: 'Work', children: [{ title: 'Done' }] },
    ];
    app.reader.folder_picker_tree = tree => tree;
    app.reader.render_folder_picker = () => {};
    const destinations = app.reader.folder_picker_rows().filter(row => row.title === 'Done');
    assert.equal(destinations.length, 2);
    assert.notEqual(destinations[0].value, destinations[1].value);
    app.reader.choose_folder_picker_folder(destinations[1].value);
    app.reader.hide_confirm_move_menu_item = () => reader_ui.push('closed picker');
    app.reader.hide_manage_menu = () => reader_ui.push('closed menu');

    app.reader.manage_menu_move_folder('Saved', {});
    assert.equal(app.reader.flags.reloading_feeds, true);
    assert.deepEqual(reader_ui, []);
    assert.deepEqual(JSON.parse(request.params.in_folder_path), ['Work', 'Queue']);
    assert.deepEqual(JSON.parse(request.params.to_folder_path), ['Work', 'Done']);
    request.failure({ code: -1, message: 'The destination changed.' });
    assert.deepEqual(messages, ['The destination changed.']);
    assert.deepEqual(reader_ui, []);
    assert.equal(app.reader.flags.reloading_feeds, false);

    const rejected_request = request;
    app.reader.manage_menu_move_folder('Saved', {});
    assert.notEqual(request, rejected_request);
    const warning = 'Folder moved, but some training rules may still use its old location.';
    request.success({ code: 1, folders: [{ Work: [{ Done: [{ Saved: [7] }] }] }], message: warning });
    assert.deepEqual(messages, ['The destination changed.', warning]);
    assert.deepEqual(reader_ui, ['reset', 'closed picker', 'closed menu']);
    assert.equal(app.reader.flags.reloading_feeds, false);
});
