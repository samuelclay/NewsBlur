const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const underscore = require('../../media/js/vendor/underscore-1.4.3.js');

function setup(value = 0) {
    const calls = [];
    const attrs = { story_hash: '1:abcdef', recommendation_feedback: value, read_status: 0 };
    const NEWSBLUR = {
        Views: {}, Globals: { is_authenticated: true, user_id: 1 },
        reader: { flags: { trending_view: true, trending_type: 'discovery' } },
        assets: { save_recommendation_feedback: (...args) => calls.push(args) }
    };
    const context = vm.createContext({
        NEWSBLUR, _: underscore, Backbone: { View: { extend: methods => methods } },
        $: target => ({ attr: name => target[name], closest: () => ({ length: target.feedback ? 1 : 0 }) })
    });
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/views/story_detail_view.js'), 'utf8'), context);
    const view = Object.create(NEWSBLUR.Views.StoryDetailView);
    view.options = {};
    view.model = {
        get: key => attrs[key],
        set: (key, value) => typeof key === 'object' ? Object.assign(attrs, key) : (attrs[key] = value),
        mark_read: () => { throw Error('Feedback marked the story read'); }
    };
    return { view, calls, attrs, NEWSBLUR };
}
function event(value) {
    return { currentTarget: { 'data-value': value }, target: { feedback: true },
        preventDefault() { this.prevented = true; },
        stopImmediatePropagation() { this.stopped = true; },
        stopPropagation() { this.stopped = true; }
    };
}
function finish(call) { call[2]({ code: 1, value: call[1] }); }

test('feedback saves without changing read state, then Undo clears it', () => {
    const { view, calls, attrs } = setup();
    const click = event(1);
    view.save_recommendation_feedback(click);
    assert.equal(click.prevented, true);
    assert.equal(click.stopped, true);
    assert.equal(attrs.recommendation_feedback, 0);
    assert.equal(attrs.recommendation_feedback_state.saving, true);
    finish(calls[0]);
    assert.equal(attrs.recommendation_feedback, 1);
    assert.equal(attrs.read_status, 0);
    view.undo_recommendation_feedback(event());
    assert.equal(calls[1][1], 0);
    finish(calls[1]);
    assert.equal(attrs.recommendation_feedback, 0);
    assert.equal(attrs.recommendation_feedback_state.can_undo, false);
});

test('switching a persisted preference and Undo restores the previous vote', () => {
    const { view, calls, attrs } = setup(1);
    view.save_recommendation_feedback(event(-1)); finish(calls[0]);
    assert.equal(attrs.recommendation_feedback, -1);
    view.undo_recommendation_feedback(event()); finish(calls[1]);
    assert.equal(attrs.recommendation_feedback, 1);
});

test('clicking the selected vote clears it', () => {
    const { view, calls, attrs } = setup(-1);
    view.save_recommendation_feedback(event(-1)); finish(calls[0]);
    assert.equal(attrs.recommendation_feedback, 0);
});

test('duplicate clicks while saving issue only one request', () => {
    const { view, calls } = setup();
    view.save_recommendation_feedback(event(1));
    view.save_recommendation_feedback(event(-1));
    assert.equal(calls.length, 1);
});

test('failed saves preserve selection and Retry resubmits the requested vote', () => {
    const { view, calls, attrs } = setup(1);
    view.save_recommendation_feedback(event(-1)); calls[0][3]();
    assert.equal(attrs.recommendation_feedback, 1);
    assert.equal(attrs.recommendation_feedback_state.error, true);
    view.retry_recommendation_feedback(event()); finish(calls[1]);
    assert.equal(attrs.recommendation_feedback, -1);
});

test('a failed Undo can be retried without losing the old preference', () => {
    const { view, calls, attrs } = setup(1);
    view.save_recommendation_feedback(event(-1)); finish(calls[0]);
    view.undo_recommendation_feedback(event()); calls[1][3]();
    assert.equal(attrs.recommendation_feedback, -1);
    view.retry_recommendation_feedback(event()); finish(calls[2]);
    assert.equal(attrs.recommendation_feedback, 1);
    assert.equal(attrs.recommendation_feedback_state.can_undo, false);
});

test('account switches ignore late save callbacks', () => {
    const { view, calls, attrs, NEWSBLUR } = setup();
    view.save_recommendation_feedback(event(1));
    NEWSBLUR.Globals.user_id = 2; finish(calls[0]);
    assert.equal(attrs.recommendation_feedback, 0);
});

test('controls only operate in authenticated Discovery article views', () => {
    const { view, calls, NEWSBLUR } = setup();
    assert.equal(view.show_recommendation_feedback(), true);
    NEWSBLUR.reader.flags.trending_type = 'good_reads';
    view.save_recommendation_feedback(event(1));
    assert.equal(calls.length, 0);
    NEWSBLUR.reader.flags.trending_type = 'discovery';
    view.options.feed_floater = true;
    assert.equal(view.show_recommendation_feedback(), false);
    view.options.feed_floater = false; NEWSBLUR.Globals.is_authenticated = false;
    assert.equal(view.show_recommendation_feedback(), false);
});

test('keyboard and pointer events cannot bubble into reader shortcuts or mark-read', () => {
    const { view } = setup();
    const key = event();
    view.stop_recommendation_feedback_event(key);
    assert.equal(key.stopped, true);
    assert.equal(key.prevented, undefined);
    view.mark_read(key);
});
