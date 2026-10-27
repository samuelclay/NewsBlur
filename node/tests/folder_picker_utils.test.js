const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const folder_picker_utils = require('../../media/js/newsblur/common/folder_picker_utils.js');

function repo_file(relative_path) {
    return fs.readFileSync(path.join(__dirname, '..', '..', relative_path), 'utf8');
}

const tree = [
    { title: 'Audio', children: [] },
    { title: 'Newsletters', children: [] },
    {
        title: 'Reality', children: [
            { title: 'Africa', children: [] },
            { title: 'Asia', children: [{ title: 'Japan', children: [] }] }
        ]
    }
];

function values(rows) {
    return rows.map(function (row) {
        return row.value;
    });
}

test('build_rows flattens the folder tree under Top Level with depths', function () {
    const rows = folder_picker_utils.build_rows(tree, { selected: ['Newsletters'] });

    assert.deepEqual(values(rows), ['', 'Audio', 'Newsletters', 'Reality', 'Africa', 'Asia', 'Japan']);
    assert.deepEqual(rows.map(function (row) { return row.depth; }), [0, 1, 1, 1, 2, 2, 3]);
    assert.deepEqual(rows.find(function (row) { return row.value === 'Japan'; }).ancestors, ['Reality', 'Asia']);
    assert.equal(rows.find(function (row) { return row.value === 'Newsletters'; }).selected, true);
    assert.equal(rows.find(function (row) { return row.value === 'Audio'; }).selected, false);
});

test('build_rows marks a folder and its subfolders as disabled targets', function () {
    const rows = folder_picker_utils.build_rows(tree, {
        selected: [''],
        disabled: folder_picker_utils.disabled_folder_targets('Reality', ['Africa', 'Asia', 'Japan'])
    });

    const disabled = rows.filter(function (row) { return row.disabled; });
    assert.deepEqual(values(disabled), ['Reality', 'Africa', 'Asia', 'Japan']);
});

test('choosing a folder by name moves the feed instead of adding a folder', function () {
    assert.deepEqual(folder_picker_utils.choose_folder(['Newsletters'], 'Audio'), ['Audio']);
    assert.deepEqual(folder_picker_utils.choose_folder(['Newsletters', 'Audio'], 'Audio'), ['Audio']);
});

test('toggling the check circle adds and removes extra folders', function () {
    assert.deepEqual(folder_picker_utils.toggle_folder(['Newsletters'], 'Audio'), ['Newsletters', 'Audio']);
    assert.deepEqual(folder_picker_utils.toggle_folder(['Newsletters', 'Audio'], 'Newsletters'), ['Audio']);
    assert.deepEqual(folder_picker_utils.toggle_folder(['Audio'], ''), ['Audio', '']);
});

test('save_state names the single destination folder for a move', function () {
    assert.deepEqual(folder_picker_utils.save_state(['Newsletters'], ['Newsletters']), { action: 'unchanged', count: 1 });
    assert.deepEqual(folder_picker_utils.save_state(['Audio', 'Books'], ['Books', 'Audio']), { action: 'unchanged', count: 2 });
    assert.deepEqual(folder_picker_utils.save_state([], ['Newsletters']), { action: 'empty', count: 0 });
    assert.deepEqual(folder_picker_utils.save_state(['Audio'], ['Newsletters']), { action: 'move', count: 1, folder: 'Audio' });
    assert.deepEqual(folder_picker_utils.save_state([''], ['Newsletters']), { action: 'move', count: 1, folder: '' });
    assert.deepEqual(folder_picker_utils.save_state(['Audio', 'Newsletters'], ['Newsletters']), { action: 'save', count: 2 });
});

test('filter_rows keeps matches and the folders that contain them', function () {
    const rows = folder_picker_utils.build_rows(tree, { selected: [] });
    const filtered = folder_picker_utils.filter_rows(rows, '  JAP ');

    assert.deepEqual(values(filtered), ['Reality', 'Asia', 'Japan']);
    assert.deepEqual(filtered.filter(function (row) { return row.matches; }).map(function (row) { return row.value; }), ['Japan']);
    assert.deepEqual(values(folder_picker_utils.filter_rows(rows, '')), values(rows));
    assert.deepEqual(folder_picker_utils.filter_rows(rows, 'nothing like this'), []);
});

test('first_match skips context rows and disabled folders', function () {
    const rows = folder_picker_utils.build_rows(tree, { selected: [], disabled: ['Africa'] });

    assert.equal(folder_picker_utils.first_match(folder_picker_utils.filter_rows(rows, 'a')), 'Audio');
    assert.equal(folder_picker_utils.first_match(folder_picker_utils.filter_rows(rows, 'africa')), null);
    assert.equal(folder_picker_utils.first_match(folder_picker_utils.filter_rows(rows, 'japan')), 'Japan');
});

test('next_highlight walks enabled rows and stops at the ends', function () {
    const rows = folder_picker_utils.build_rows(tree, { selected: [], disabled: ['Reality'] });

    assert.equal(folder_picker_utils.next_highlight(rows, null, 1), '');
    assert.equal(folder_picker_utils.next_highlight(rows, 'Newsletters', 1), 'Africa');
    assert.equal(folder_picker_utils.next_highlight(rows, 'Africa', -1), 'Newsletters');
    assert.equal(folder_picker_utils.next_highlight(rows, 'Japan', 1), 'Japan');
    assert.equal(folder_picker_utils.next_highlight(rows, '', -1), '');
});

test('list_height shows every folder when the window has room', function () {
    assert.equal(folder_picker_utils.list_height({ content_height: 720, available_height: 1400, min_height: 120 }), 720);
    assert.equal(folder_picker_utils.list_height({ content_height: 720, available_height: 400, min_height: 120 }), 400);
    assert.equal(folder_picker_utils.list_height({ content_height: 720, available_height: 40, min_height: 120 }), 120);
    assert.equal(folder_picker_utils.list_height({ content_height: 60, available_height: 40, min_height: 120 }), 60);
});

test('menu_top keeps a growing menu on screen and anchored to its arrow', function () {
    // Opens downward: keep the top unless the bottom would leave the window.
    assert.equal(folder_picker_utils.menu_top({ top: 100, height: 300, grow: 200, window_height: 900, margin: 12, inverse: false }), 100);
    assert.equal(folder_picker_utils.menu_top({ top: 500, height: 300, grow: 200, window_height: 900, margin: 12, inverse: false }), 388);
    // Opens upward: keep the bottom edge on the item and grow toward the top.
    assert.equal(folder_picker_utils.menu_top({ top: 500, height: 300, grow: 200, window_height: 900, margin: 12, inverse: true }), 300);
    assert.equal(folder_picker_utils.menu_top({ top: 100, height: 300, grow: 200, window_height: 900, margin: 12, inverse: true }), 12);
});

test('change folders picker shows custom folder icons and a sized list', function () {
    const js = repo_file('media/js/newsblur/reader/reader.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /\$\.favicon_el\('river:' \+ row\.value\)/);
    assert.match(js, /utils\.list_height\(\{/);
    assert.doesNotMatch(css, /\.NB-change-folders \{\s*width: 100%;\s*height: 84px;/);
});
