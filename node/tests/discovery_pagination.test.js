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
    const NEWSBLUR = { Globals: { user_id: 1 }, reader: { active_feed: 'trending:discovery' },
        reveal_discovery_stories() {} };
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

test('weekly preview ends pagination, reveals new picks once, and ignores a superseded opening', () => {
    let reveals = 0;
    const events = [], requests = [], loaded = [];
    const NEWSBLUR = { Globals: { user_id: 1 }, reader: { active_feed: 'trending:discovery' },
        reveal_discovery_stories() { reveals++; } };
    const context = vm.createContext({ NEWSBLUR, _: underscore, Backbone: { Router: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/common/assetmodel.js'), 'utf8'), context);
    const model = Object.create(NEWSBLUR.AssetModel);
    model.stories = { trigger: event => events.push(event) };
    model.view_setting = () => 'all';
    model.make_request = (url, data, callback) => requests.push(callback);
    model.load_feed_precallback = data => loaded.push(data);
    const load = () => model.fetch_trending_stories('trending:discovery', 1, { trending_type: 'discovery' }, null, null, true);
    const response = { discovery_preview: { limited: true, generated: true }, discovery_next_cursor: null, feeds: [] };
    load(); load();
    requests[0](response);
    assert.equal(loaded.length, 0);
    requests[1](response);
    assert.equal(model.stories.no_more_stories, true);
    assert.deepEqual(events, ['no_more_stories']);
    assert.equal(reveals, 1);
    load(); requests[2]({ ...response, discovery_preview: { limited: true, generated: false } });
    assert.equal(reveals, 1);
    load(); requests[3](response);
    assert.equal(reveals, 2);
});

test('changing reader layout preserves the weekly preview boundary in both story views', () => {
    const NEWSBLUR = { Views: {}, assets: { discovery_cursor: null }, discovery_preview_active: () => true };
    const context = vm.createContext({ NEWSBLUR, _: underscore, Backbone: { View: { extend: methods => methods } } });
    for (const [file, name] of [['story_titles_view.js', 'StoryTitlesView'], ['story_list_view.js', 'StoryListView']]) {
        vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/', file), 'utf8'), context);
        const view = Object.create(NEWSBLUR.Views[name]);
        Object.assign(view, { stories: [], collection: { no_more_stories: true }, $el: { empty() {} }, clear_explainer() {} });
        view.clear();
        assert.equal(view.collection.no_more_stories, true, name + ' dropped the preview end marker');
        NEWSBLUR.discovery_preview_active = () => false;
        view.clear();
        assert.equal(view.collection.no_more_stories, false);
        NEWSBLUR.discovery_preview_active = () => true;
    }
});
