const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// preferences_save.test.js: the Preferences dialog (reader_preferences.js) with its form and its
// requests replaced, so a test decides what the form holds and when each save comes back.
function preferences_fixture(saved_form) {
    const requests = [];
    const statuses = [];
    let reloads = 0;
    const noop = () => {};
    const element = {};
    for (const method of ['text', 'addClass', 'toggleClass']) element[method] = () => element;
    const context = {
        NEWSBLUR: {
            Modal: function () {},
            Globals: { is_premium: true, is_archive: true },
            Preferences: {},
            reader: {
                switch_feed_view_unread_view: noop, apply_story_styling: noop, apply_tipsy_titles: noop,
                adjust_for_narrow_window: noop, add_body_classes: noop, check_and_load_ssl: noop,
                force_feeds_refresh: noop, clear_realtime_new_stories: noop,
            },
            app: {
                story_list: { show_stories_preference_in_feed_view: noop },
                sidebar_header: { count: noop },
                feed_list: { make_feeds: noop, make_social_feeds: noop, toggle_filter_feeds: noop },
            },
            utils: { hide_tip: noop },
        },
        _: {
            extend: Object.assign, bind: (fn, self) => fn.bind(self),
            each: (object, fn) => Object.keys(object).forEach(key => fn(object[key], key)),
            isEqual: (a, b) => a === b, isEmpty: object => Object.keys(object).length === 0,
            isNumber: value => typeof value === 'number',
            any: (list, fn) => list.some(fn),
        },
        $: Object.assign(() => element, { extend: Object.assign }),
        gettext: text => text,
        window: { location: { reload() { reloads += 1; } } },
        clearTimeout: noop,
        setTimeout: noop,
    };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/reader/reader_preferences.js'), 'utf8'), context);
    const dialog = Object.create(context.NEWSBLUR.ReaderPreferences.prototype);
    const form = Object.assign({}, saved_form);
    dialog.serialize_preferences = () => Object.assign({}, form);
    dialog.original_preferences = Object.assign({}, saved_form);
    dialog.set_status = status => statuses.push(status);
    dialog.model = {
        save_preferences(changed, done) { requests.push({ changed: Object.assign({}, changed), done }); },
    };
    return {
        dialog, form, requests, statuses,
        sent: () => requests.map(request => request.changed),
        reloads: () => reloads,
        respond: (index, data) => requests[index].done(data),
    };
}

test('a save that fails is not called saved, and goes out again with the next change', () => {
    const fixture = preferences_fixture({ show_content_preview: true, feed_order: 'ALPHABETICAL' });

    fixture.form.show_content_preview = false;
    fixture.dialog.save_preferences();
    // What common/assetmodel.js make_request hands back after a 500, a timeout or a dropped connection.
    fixture.respond(0, { message: 'Sorry, there was an unhandled error.', status_code: 500 });
    assert.equal(fixture.statuses.at(-1), 'error');

    fixture.form.feed_order = 'MOSTUSED';
    fixture.dialog.save_preferences();
    assert.deepEqual(fixture.sent()[1], { show_content_preview: false, feed_order: 'MOSTUSED' });
});

test('a change put back while its save is still out is saved once that save returns', () => {
    const fixture = preferences_fixture({ show_content_preview: true });

    fixture.form.show_content_preview = false;
    fixture.dialog.save_preferences();
    fixture.form.show_content_preview = true;
    fixture.dialog.save_preferences();
    fixture.respond(0, { code: 1 });

    // The server holds false from the first request, so true has to follow it.
    assert.deepEqual(fixture.sent(), [{ show_content_preview: false }, { show_content_preview: true }]);
    assert.notEqual(fixture.statuses.at(-1), 'saved');
    fixture.respond(1, { code: 1 });
    assert.equal(fixture.statuses.at(-1), 'saved');
});

test('closing the dialog reads the form while it is still on the page, even with a save out', () => {
    const fixture = preferences_fixture({ show_content_preview: true });

    fixture.form.show_content_preview = false;
    fixture.dialog.save_preferences();
    fixture.form.show_content_preview = true;
    fixture.dialog.save_timer = 1;
    fixture.dialog.handle_modal_closed();
    // The dialog is gone by the time the first save returns, and reading its fields then would
    // send whatever an empty page serializes to.
    fixture.dialog.serialize_preferences = () => ({ show_content_preview: 'read after close' });
    fixture.respond(0, { code: 1 });

    assert.deepEqual(fixture.sent(), [{ show_content_preview: false }, { show_content_preview: true }]);
});

test('a new language reloads the page only after a change made meanwhile is saved', () => {
    const fixture = preferences_fixture({ language: 'en', feed_order: 'ALPHABETICAL' });

    fixture.form.language = 'fr';
    fixture.dialog.save_preferences();
    fixture.form.feed_order = 'MOSTUSED';
    fixture.dialog.save_preferences();
    fixture.respond(0, { code: 1 });

    assert.equal(fixture.reloads(), 0);
    assert.deepEqual(fixture.sent()[1], { feed_order: 'MOSTUSED' });
    fixture.respond(1, { code: 1 });
    assert.equal(fixture.reloads(), 1);
});

test('a new language does not reload the page over a change that failed to save', () => {
    const fixture = preferences_fixture({ language: 'en', feed_order: 'ALPHABETICAL' });

    fixture.form.language = 'fr';
    fixture.dialog.save_preferences();
    fixture.form.feed_order = 'MOSTUSED';
    fixture.dialog.save_preferences();
    fixture.respond(0, { code: 1 });
    fixture.respond(1, { message: 'Sorry, there was an unhandled error.', status_code: 500 });

    // Reloading here would drop the feed order and hide that it was never saved.
    assert.equal(fixture.reloads(), 0);
    assert.equal(fixture.statuses.at(-1), 'error');
    fixture.dialog.save_preferences();
    fixture.respond(2, { code: 1 });
    assert.deepEqual(fixture.sent()[2], { feed_order: 'MOSTUSED' });
    assert.equal(fixture.reloads(), 1);
});
