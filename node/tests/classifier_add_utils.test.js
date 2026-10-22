const test = require('node:test');
const assert = require('node:assert/strict');

const classifier_add_utils = require('../../media/js/newsblur/common/classifier_add_utils.js');

const archive_tiers = { is_premium: true, is_archive: true, is_pro: false };
const premium_tiers = { is_premium: true, is_archive: false, is_pro: false };
const free_tiers = { is_premium: false, is_archive: false, is_pro: false };
const pro_tiers = { is_premium: true, is_archive: true, is_pro: true };

test('a typed global title like saves with no feed behind it', function () {
    const data = classifier_add_utils.build_save_data({
        type: 'title',
        value: '  Apple Vision  ',
        scope_value: 'global',
        sentiment: 'like',
        is_regex: false
    });

    assert.deepEqual(data, {
        feed_id: 0,
        scope: 'global',
        folder_name: '',
        like_title: 'Apple Vision'
    });
});

test('a typed folder dislike keeps the full folder path the backend flattens to', function () {
    const data = classifier_add_utils.build_save_data({
        type: 'tag',
        value: 'sponsored',
        scope_value: 'folder:Tech - Apple',
        sentiment: 'dislike',
        is_regex: false
    });

    assert.deepEqual(data, {
        feed_id: 0,
        scope: 'folder',
        folder_name: 'Tech - Apple',
        dislike_tag: 'sponsored'
    });
});

test('a typed site classifier posts that site and the feed scope', function () {
    const data = classifier_add_utils.build_save_data({
        type: 'author',
        value: 'Jane Doe',
        scope_value: 'feed:42',
        sentiment: 'like',
        is_regex: false
    });

    assert.deepEqual(data, {
        feed_id: 42,
        scope: 'feed',
        folder_name: '',
        like_author: 'Jane Doe'
    });
});

test('regex only changes the opinion key for types that support regex', function () {
    const regex_title = classifier_add_utils.build_save_data({
        type: 'title', value: 'iphone \\d+', scope_value: 'global', sentiment: 'dislike', is_regex: true
    });
    const regex_tag = classifier_add_utils.build_save_data({
        type: 'tag', value: 'news', scope_value: 'global', sentiment: 'like', is_regex: true
    });

    assert.equal(regex_title.dislike_title_regex, 'iphone \\d+');
    assert.equal(regex_title.dislike_title, undefined);
    assert.equal(regex_tag.like_tag, 'news');
    assert.equal(regex_tag.like_tag_regex, undefined);
});

test('folder paths join nested folder titles the way flatten_folders does', function () {
    assert.equal(classifier_add_utils.folder_path('', 'Tech'), 'Tech');
    assert.equal(classifier_add_utils.folder_path('Tech', 'Apple'), 'Tech - Apple');
    assert.equal(classifier_add_utils.folder_path('Tech - Apple', 'Rumors'), 'Tech - Apple - Rumors');
});

test('global and folder scopes need Premium Archive', function () {
    const entry = { type: 'title', value: 'x', scope_value: 'global', is_regex: false };

    assert.equal(classifier_add_utils.required_tier(entry, archive_tiers), null);
    assert.deepEqual(classifier_add_utils.required_tier(entry, premium_tiers), { tier: 'archive', reason: 'scope' });
    assert.deepEqual(
        classifier_add_utils.required_tier(_extend(entry, { scope_value: 'folder:Tech' }), premium_tiers),
        { tier: 'archive', reason: 'scope' }
    );
    assert.equal(
        classifier_add_utils.required_tier(_extend(entry, { scope_value: 'feed:42' }), free_tiers),
        null
    );
});

test('text needs Archive, URL needs Premium, and regex needs Pro', function () {
    const site = { value: 'x', scope_value: 'feed:42', is_regex: false };

    assert.deepEqual(
        classifier_add_utils.required_tier(_extend(site, { type: 'text' }), premium_tiers),
        { tier: 'archive', reason: 'text' }
    );
    assert.deepEqual(
        classifier_add_utils.required_tier(_extend(site, { type: 'url' }), free_tiers),
        { tier: 'premium', reason: 'url' }
    );
    assert.equal(classifier_add_utils.required_tier(_extend(site, { type: 'url' }), premium_tiers), null);
    assert.deepEqual(
        classifier_add_utils.required_tier(_extend(site, { type: 'title', is_regex: true }), archive_tiers),
        { tier: 'pro', reason: 'regex' }
    );
    assert.equal(
        classifier_add_utils.required_tier(_extend(site, { type: 'title', is_regex: true }), pro_tiers),
        null
    );
    assert.equal(
        classifier_add_utils.required_tier(_extend(site, { type: 'tag', is_regex: true }), archive_tiers),
        null
    );
});

function _extend(base, overrides) {
    return Object.assign({}, base, overrides);
}
