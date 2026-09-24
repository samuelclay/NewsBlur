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
    const reveals = [];
    const NEWSBLUR = { Globals: { user_id: 1 }, reader: { active_feed: 'trending:discovery' },
        reveal_discovery_stories(first_new_story) { reveals.push(first_new_story); } };
    const context = vm.createContext({
        NEWSBLUR, _: underscore, Backbone: { Router: { extend: methods => methods } }
    });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/common/assetmodel.js'), 'utf8'), context);
    const model = Object.create(NEWSBLUR.AssetModel);
    const requests = [], loaded = [];
    model.stories = { length: 12 };
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
    assert.deepEqual(reveals, [0, 12], 'a later page reveals only the stories it appended');
    load(3, false);
    assert.equal(requests[2].data.discovery_cursor, 18);
    assert.equal(loaded.length, 2);
    load(1, true);
    assert.equal(requests[3].data.discovery_cursor, 0);
    assert.equal(requests[3].data.discovery_snapshot, null);
});

test('weekly preview ends pagination, reveals every opening, and ignores a superseded opening', () => {
    const reveals = [];
    const events = [], requests = [], loaded = [];
    const NEWSBLUR = { Globals: { user_id: 1 }, reader: { active_feed: 'trending:discovery' },
        reveal_discovery_stories(first_new_story) { reveals.push(first_new_story); } };
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
    assert.deepEqual(reveals, [0]);
    load(); requests[2]({ ...response, discovery_preview: { limited: true, generated: false } });
    assert.deepEqual(reveals, [0, 0]);
});

test('each Discovery page continues the cascade on the beat after the page before it', () => {
    let clock = 1000;
    const stories = [];
    const NEWSBLUR = { Views: {}, assets: { stories: { models: stories } } };
    const context = vm.createContext({ NEWSBLUR, _: underscore, Date: { now: () => clock },
        Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    const view = () => {
        const $el = { classes: [], css(name, value) { this.delay = parseInt(value, 10); return this; },
            addClass(name) { this.classes.push(name); return this; }, on() { return this; } };
        return { $el };
    };
    const add_page = count => {
        const first_new_story = stories.length;
        for (let i = 0; i < count; i++) stories.push({ story_title_view: view(), story_view: view() });
        NEWSBLUR.reveal_discovery_stories(first_new_story);
        return stories.slice(first_new_story).map(story => story.story_title_view.$el.delay);
    };

    const first_page = add_page(12);
    assert.deepEqual(first_page, [0, 70, 140, 210, 280, 350, 420, 490, 560, 630, 700, 770],
        'every story in a page gets its own beat instead of the tail arriving as a block');
    assert.equal(stories[3].story_view.$el.delay, 210, 'split view detail stays in step with its title');
    assert.ok(stories.every(story => story.story_title_view.$el.classes.includes('NB-discovery-reveal')));

    // Page one's last story starts at 1000 + 770, so page two's first story takes the next beat at 1840.
    clock = 1500;
    const second_page = add_page(12);
    assert.equal(second_page[0], 340, 'page two picks up one beat after page one without a pause');
    assert.equal(second_page[11], 340 + 770);

    // Page two's last story starts at 1500 + 340 + 770; page three takes the beat after it.
    clock = 2000;
    assert.equal(add_page(12)[0], 1500 + 340 + 770 + 70 - 2000);

    clock = 60000;
    assert.equal(add_page(12)[0], 0, 'a page after the queue drains starts immediately');

    clock = 60100;
    stories.length = 0;
    assert.equal(add_page(12)[0], 0, 'a fresh opening never waits on the previous stream');
});

test('changing reader layout preserves the weekly preview boundary in both story views', () => {
    const main_stories = { no_more_stories: true };
    const NEWSBLUR = { Views: {}, reader: { active_feed: 'trending:discovery' },
        assets: { discovery_cursor: null, discovery_preview: { limited: true }, stories: main_stories } };
    const context = vm.createContext({ NEWSBLUR, _: underscore, Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    for (const [file, name] of [['story_titles_view.js', 'StoryTitlesView'], ['story_list_view.js', 'StoryListView']]) {
        vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/', file), 'utf8'), context);
        const view = Object.create(NEWSBLUR.Views[name]);
        Object.assign(view, { stories: [], collection: main_stories, $el: { empty() {} }, clear_explainer() {} });
        view.clear();
        assert.equal(view.collection.no_more_stories, true, name + ' dropped the preview end marker');
        view.collection = { no_more_stories: true };
        view.clear();
        assert.equal(view.collection.no_more_stories, false, name + ' exhausted an independent related-story collection');
        assert.equal(NEWSBLUR.discovery_preview_active(view.collection), false);
    }
});

test('organizer and feed chooser rebuilds leave the main sidebar summary and its listener alone', () => {
    let created = 0, removed = 0, replaced = 0;
    const NEWSBLUR = { Globals: { is_authenticated: true }, Views: {
        RecommendationFeedbackSummary: function () { created++; this.remove = () => { removed++; }; }
    } };
    const continue_feed_render = new Error('Continue ordinary feed rendering');
    NEWSBLUR.assets = {};
    Object.defineProperty(NEWSBLUR.assets, 'folders', { get() { throw continue_feed_render; } });
    const rebuild = view => assert.throws(() => view.make_feeds(), error => error === continue_feed_render);
    const context = vm.createContext({ NEWSBLUR, _: underscore,
        $: () => ({ empty() { replaced++; return this; }, append() {} }),
        Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/feed_list_view.js'), 'utf8'), context);
    for (const options of [{feed_chooser:true}, {organizer:true}, {feed_chooser:true,organizer:true}]) {
        const dialog = Object.assign(Object.create(NEWSBLUR.Views.FeedList), {options});
        for (let i=0; i<3; i++) rebuild(dialog);
    }
    assert.equal(created, 0);
    assert.equal(replaced, 0);
    const main = Object.assign(Object.create(NEWSBLUR.Views.FeedList), { options: {} });
    rebuild(main); rebuild(main);
    assert.equal(created, 2);
    assert.equal(removed, 1);
});
