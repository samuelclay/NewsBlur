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

test('the same phrase in two folders is two classifiers, not one pending edit', function () {
    const tech_news = { feed_id: 0, type: 'tag', value: 'news', scope: 'folder', folder_name: 'Tech' };
    const sports_news = { feed_id: 0, type: 'tag', value: 'news', scope: 'folder', folder_name: 'Sports' };
    const global_news = { feed_id: 0, type: 'tag', value: 'news', scope: 'global', folder_name: '' };

    assert.notEqual(classifier_add_utils.classifier_key(tech_news), classifier_add_utils.classifier_key(sports_news));
    assert.notEqual(classifier_add_utils.classifier_key(tech_news), classifier_add_utils.classifier_key(global_news));
    assert.equal(
        classifier_add_utils.classifier_key(tech_news),
        classifier_add_utils.classifier_key(Object.assign({}, tech_news))
    );
});

test('classifier keys read DOM attribute strings and model values the same way', function () {
    const from_model = { feed_id: 42, type: 'author', value: 'Jane Doe', scope: 'feed', folder_name: '' };
    const from_dom = { feed_id: '42', type: 'author', value: 'Jane Doe', scope: undefined, folder_name: undefined };

    assert.equal(classifier_add_utils.classifier_key(from_model), classifier_add_utils.classifier_key(from_dom));
});

test('a regex classifier and a plain one with the same text are separate classifiers', function () {
    const plain = { feed_id: 0, type: 'title', value: 'apple', scope: 'global', folder_name: '', is_regex: false };
    const regex = Object.assign({}, plain, { is_regex: true });
    const plain_from_dom = Object.assign({}, plain, { is_regex: 'false' });
    const regex_from_dom = Object.assign({}, plain, { is_regex: 'true' });

    assert.notEqual(classifier_add_utils.classifier_key(plain), classifier_add_utils.classifier_key(regex));
    assert.equal(classifier_add_utils.classifier_key(plain), classifier_add_utils.classifier_key(plain_from_dom));
    assert.equal(classifier_add_utils.classifier_key(regex), classifier_add_utils.classifier_key(regex_from_dom));
});

test('classifier keys cannot be confused by separators inside folder names or values', function () {
    const a = { feed_id: 0, type: 'title', value: 'b:c', scope: 'folder', folder_name: 'a' };
    const b = { feed_id: 0, type: 'title', value: 'c', scope: 'folder', folder_name: 'a:b' };

    assert.notEqual(classifier_add_utils.classifier_key(a), classifier_add_utils.classifier_key(b));
});

test('saved opinion names keep the regex suffix so a regex edit updates the regex classifier', function () {
    assert.equal(classifier_add_utils.opinion_name('title', 1, -1, true), 'like_title_regex');
    assert.equal(classifier_add_utils.opinion_name('title', -1, 1, false), 'dislike_title');
    assert.equal(classifier_add_utils.opinion_name('author', -2, 1, true), 'super_dislike_author_regex');
    assert.equal(classifier_add_utils.opinion_name('url', 0, 1, true), 'remove_like_url_regex');
    assert.equal(classifier_add_utils.opinion_name('text', 0, -1, false), 'remove_dislike_text');
});

test('opinion names ignore a regex flag on types without regex classifiers', function () {
    assert.equal(classifier_add_utils.opinion_name('tag', 1, 0, true), 'like_tag');
    assert.equal(classifier_add_utils.opinion_name('feed', -1, 0, true), 'dislike_feed');
});

function _extend(base, overrides) {
    return Object.assign({}, base, overrides);
}
