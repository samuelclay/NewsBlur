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

test('interest requests include CSRF and ignore responses after switching accounts', () => {
    const { NEWSBLUR, model, requests, events } = asset_setup();
    model.discovery_taste_request('edit_taste', { revision: 3 }, () => assert.fail('Cross-account response'));
    assert.equal(requests[0].data.csrfmiddlewaretoken, 'csrf-token');
    assert.equal(requests[0].options.request_type, 'POST');
    NEWSBLUR.Globals.user_id = 2;
    requests[0].callback({ profile: { revision: 4 } });
    requests[0].error({ message: 'Another account’s error' });
    assert.equal(model.discovery_taste, undefined);
    assert.deepEqual(events, []);
});

test('an older profile response cannot overwrite a saved interest', () => {
    const { model, requests } = asset_setup();
    model.discovery_taste_request('taste_profile', {});
    model.discovery_taste = { revision: 5, rules: ['manual edit'] };
    requests[0].callback({ profile: { revision: 4, rules: [] } });
    assert.deepEqual(model.discovery_taste.rules, ['manual edit']);
});

test('background inference is deduplicated and only runs for changed, sufficient ratings', () => {
    const { model, requests } = asset_setup();
    model.ensure_discovery_taste('8:9');
    model.ensure_discovery_taste('8:9');
    assert.equal(requests.length, 1);
    requests[0].callback({ profile: { revision: 0, stale: true, can_learn: true } });
    assert.equal(requests[1].url, '/recommendations/learn_taste');
    requests[1].callback({ profile: { revision: 1, stale: false } });
    model.ensure_discovery_taste('8:9');
    assert.equal(requests.length, 2);
    model.ensure_discovery_taste('9:9');
    requests[2].callback({ profile: { revision: 1, stale: false, can_learn: true } });
    assert.equal(requests.length, 3);
    assert.equal(model.discovery_taste_pending, false);
});

test('background learning keeps dirty forms intact until the reader cancels', () => {
    const NEWSBLUR = { Views: {} };
    const context = vm.createContext({ NEWSBLUR, _: underscore, Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    const view = Object.create(NEWSBLUR.Views.DiscoveryTaste);
    let rendered = 0;
    Object.assign(view, { active: true, dirty: true, profile: { revision: 1 }, status() {}, render() { rendered++; } });
    view.receive({ revision: 2 });
    assert.equal(rendered, 0);
    assert.equal(view.profile.revision, 1);
    view.cancel_edit();
    assert.equal(view.profile.revision, 2);
    assert.equal(rendered, 1);
});

test('saving a preserved draft uses the newer revision after background learning', () => {
    const NEWSBLUR = { Views: {} };
    const values = { label: 'My edited label', criterion: 'My edited criterion', kind: 'angle', direction: '-1', strength: '2' };
    const row = { attr: name => name === 'data-interest-id' ? 'ai' : null,
        find: selector => ({ val: () => values[selector.match(/name="(\w+)"/)[1]] }) };
    const $ = () => ({ closest: () => row, blur() {} });
    const context = vm.createContext({ NEWSBLUR, _: underscore, $, Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    const view = Object.create(NEWSBLUR.Views.DiscoveryTaste);
    let sent;
    Object.assign(view, { active: true, dirty: true, profile: { revision: 1, rules: [{ id: 'ai' }] },
        status() {}, request: (action, params) => { sent = params; } });
    view.receive({ revision: 2, rules: [{ id: 'ai', label: 'Generated label' }] });
    view.save({ currentTarget: {} });
    assert.equal(sent.revision, 2);
    assert.equal(sent.label, 'My edited label');
    assert.equal(sent.action, 'save');
    view.receive({ revision: 3, rules: [] });
    view.save({ currentTarget: {} });
    assert.equal(sent.action, 'add');
    assert.equal(sent.revision, 3);
});

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

test('dialog letters never reach reader keypress shortcuts, while native activation and Escape/Tab remain intact', () => {
    const { view } = history_setup();
    assert.equal(view.events.keypress, 'stop_event');
    const event = { key: 'v', which: 118, stopPropagation() { this.stopped = true; },
        preventDefault() { throw Error('Native button activation should remain available'); } };
    view[view.events.keypress](event);
    assert.equal(event.stopped, true);
    for (const key of ['Escape', 'Tab']) {
        view.stop_event({ key, stopPropagation() { assert.fail('Modal keyboard handling was swallowed'); } });
    }
});

test('equal More and Less activity is visible on opposite sides; an empty summary is a constellation', () => {
    const NEWSBLUR = { Views: {} };
    const document = { createElementNS(namespace, tag) {
        return { tag, attributes: {}, children: [], setAttribute(key, value) { this.attributes[key] = value; },
            appendChild(child) { this.children.push(child); } };
    } };
    const context = vm.createContext({ NEWSBLUR, document, _: underscore, Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    const empty = NEWSBLUR.recommendation_feedback_chart([], 72, 24, true);
    assert.equal(empty.attributes.class, 'NB-feedback-constellation');
    assert.equal(empty.children.filter(shape => shape.tag === 'circle').length, 5);
    const graph = NEWSBLUR.recommendation_feedback_chart([{ more: 0, less: 0 }, { more: 2, less: 2 }], 72, 24, false);
    const line = choice => graph.children.find(shape => shape.attributes.class === 'NB-feedback-chart-' + choice);
    const y = choice => Number(line(choice).attributes.points.split(' ').at(-1).split(',')[1]);
    assert.ok(y('more') < 12);
    assert.ok(y('less') > 12);
    assert.equal(12 - y('more'), y('less') - 12);
});

test('Discovery summary badges use standard unread styling with hidden before focus', () => {
    const NEWSBLUR = { Views: {} };
    const $ = html => ({ html, text(value) { this.value = value; return this; } });
    const context = vm.createContext({ NEWSBLUR, _: underscore, $, Backbone: { View: { extend: methods => methods } } });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/recommendation_feedback_view.js'), 'utf8'), context);
    NEWSBLUR.recommendation_feedback_chart = () => 'chart';
    const children = [];
    const element = { empty() { children.length = 0; return this; }, append(child) { children.push(child); return this; }, attr() {} };
    NEWSBLUR.Views.RecommendationFeedbackSummary.render_summary.call({ $el: element }, { more: 43, less: 2, days: [] });
    const badges = children.filter(child => child.html);
    assert.equal(badges.length, 2);
    for (const badge of badges) {
        const classes = badge.html.match(/class="([^"]+)"/)[1].split(/\s+/);
        assert.ok(classes.includes('unread_count'), 'Discovery must inherit the standard unread badge CSS');
    }
    assert.match(badges[0].html, /unread_count_negative/);
    assert.equal(badges[0].value, 2);
    assert.match(badges[1].html, /unread_count_positive/);
    assert.equal(badges[1].value, 43);
    NEWSBLUR.Views.RecommendationFeedbackSummary.render_summary.call({ $el: element }, { more: 0, less: 0, days: [] });
    assert.deepEqual(children, ['chart']);
});
