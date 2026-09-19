const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const underscore = require('../../media/js/vendor/underscore-1.4.3.js');

test('dashboard folder choices do not offer the standalone Discovery stream', () => {
    const options = [];
    const NEWSBLUR = { assets: { get_folders: () => ({ each() {} }) } };
    const context = vm.createContext({
        NEWSBLUR, _: underscore,
        $: { make: (tag, attrs) => ({
            append: option => options.push(option), attr() {}, attrs
        }) }
    });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/reader/reader_utils.js'), 'utf8'), context);
    NEWSBLUR.utils.make_folders(null, null, null, true);
    const values = options.map(option => option.attrs.value);
    assert.ok(values.includes('trending:good_reads'));
    assert.ok(!values.includes('trending:discovery'));
});

test('Discovery continues with the returned cursor and resets it on refresh', () => {
    const NEWSBLUR = { Globals: { user_id: 1 }, reader: { active_feed: 'trending:discovery' } };
    const context = vm.createContext({
        NEWSBLUR, _: underscore, Backbone: { Router: { extend: methods => methods } }
    });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/common/assetmodel.js'), 'utf8'), context);
    const model = Object.create(NEWSBLUR.AssetModel);
    const requests = [], loaded = [];
    model.view_setting = () => 'unread';
    model.make_request = (url, data, callback) => requests.push({ url, data, callback });
    model.load_feed_precallback = data => loaded.push(data);
    const load = (page, first) => model.fetch_trending_stories('trending:discovery', page,
        { trending_type: 'discovery' }, null, null, first);
    load(1, true);
    requests[0].callback({ discovery_snapshot: 'snapshot', discovery_next_cursor: 5, feeds: [] });
    load(2, false);
    assert.equal(requests[1].data.discovery_snapshot, 'snapshot');
    assert.equal(requests[1].data.discovery_cursor, 5);
    requests[1].callback({ discovery_snapshot: 'snapshot', discovery_next_cursor: 18, feeds: [] });
    load(3, false);
    assert.equal(requests[2].data.discovery_cursor, 18);
    assert.equal(loaded.length, 2);
    load(1, true);
    assert.equal(requests[3].data.discovery_cursor, 0);
    assert.equal(requests[3].data.discovery_snapshot, null);
});
