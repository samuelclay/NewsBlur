const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const underscore = require('../../media/js/vendor/underscore-1.4.3.js');

function asset_setup() {
    const requests = [], events = [], story = {};
    const NEWSBLUR = { Globals: { user_id: 1, is_authenticated: true } };
    const context = vm.createContext({ NEWSBLUR, _: underscore,
        $: { cookie: () => 'csrf-token' }, Backbone: { Router: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/common/assetmodel.js'), 'utf8'), context);
    const model = Object.create(NEWSBLUR.AssetModel);
    model.make_request = (url, data, callback, error, options) => requests.push({ url, data, callback, error, options });
    model.stories = { get_by_story_hash: hash => hash === '1:abcdef' ? { set: attrs => Object.assign(story, attrs) } : null };
    model.trigger = name => events.push(name);
    return { NEWSBLUR, model, requests, story, events };
}

test('history edits synchronize loaded articles and notify the header after a successful save', () => {
    const { model, requests, story, events } = asset_setup();
    let saved = false;
    model.save_recommendation_feedback('1:abcdef', -1, () => { saved = true; }, () => assert.fail('save failed'));
    assert.equal(requests[0].data.csrfmiddlewaretoken, 'csrf-token');
    assert.equal(requests[0].options.retry, false);
    requests[0].callback({ code: 1, value: -1 });
    assert.equal(saved, true);
    assert.equal(story.recommendation_feedback, -1);
    assert.deepEqual(events, ['recommendation:updated']);
});

test('account changes discard late history and save results before touching another account', () => {
    const { NEWSBLUR, model, requests, story, events } = asset_setup();
    const unexpected = () => assert.fail('late callback crossed accounts');
    model.save_recommendation_feedback('1:abcdef', 1, unexpected, unexpected);
    model.load_recommendation_feedback({ summary: 1 }, unexpected, unexpected);
    NEWSBLUR.Globals.user_id = 2;
    requests[0].callback({ value: 1 }); requests[0].error();
    requests[1].callback({ summary: {} }); requests[1].error();
    assert.deepEqual(story, {});
    assert.deepEqual(events, []);
});

function history_setup() {
    const requests = [], writes = [];
    const chain = new Proxy({}, { get: (target, method) => (...args) => {
        writes.push([method, ...args]);
        return chain;
    } });
    const NEWSBLUR = { Views: {}, assets: { load_recommendation_feedback: (params, callback, error) => requests.push({ params, callback, error }) } };
    const $ = () => chain;
    $.modal = { resize() {} };
    const context = vm.createContext({ NEWSBLUR, _: underscore, $, Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    NEWSBLUR.recommendation_feedback_chart = () => 'chart';
    const view = Object.create(NEWSBLUR.Views.RecommendationFeedbackHistory);
    Object.assign(view, { choice: 1, request_number: 0, active: true, $: () => chain });
    return { view, requests, writes };
}

test('switching More to Less ignores the old list response and its error', () => {
    const { view, requests, writes } = history_setup();
    view.load(false);
    view.choice = -1; view.load(false);
    writes.length = 0;
    requests[0].callback({}); requests[0].error();
    assert.equal(writes.length, 0);
    assert.equal(view.loading, true);
    requests[1].callback({ next_cursor: 'next', stories: [], feeds: {},
        summary: { more: 2, less: 3, days: Array(30).fill({ date: '2026-09-19' }) } });
    assert.equal(view.loading, false);
    assert.equal(view.next_cursor, 'next');
    assert.ok(writes.some(write => write[0] === 'text' && write[1] === 3));
});

test('closing history ignores pending results, and an expired pagination cursor retries from the beginning', () => {
    const { view, requests, writes } = history_setup();
    view.next_cursor = 'expired'; view.load(true);
    requests[0].error();
    assert.equal(view.retry_append, false);
    view.retry();
    assert.equal(requests[1].params.cursor, '');
    view.active = false;
    writes.length = 0;
    requests[1].callback({}); requests[1].error();
    assert.equal(writes.length, 0);
});
