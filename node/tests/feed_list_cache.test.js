const test = require('node:test');
const assert = require('node:assert/strict');

const cache = require('../../media/js/newsblur/common/feed_list_cache.js');

function response(overrides) {
    return Object.assign({
        user_id: 7,
        folders: [1, { Tech: [2, 3] }],
        feeds: [
            { id: 1, feed_title: 'One', active: true, ps: 0, nt: 4, ng: 0, updated: '1 minute ago' },
            { id: 2, feed_title: 'Two', active: true, ps: 1, nt: 0, ng: 2, updated: '2 hours ago' },
            { id: 3, feed_title: 'Three', active: false, ps: 0, nt: 0, ng: 0 }
        ],
        social_feeds: [{ id: 'social:9', feed_title: 'Friend', username: 'friend', ps: 0, nt: 1, ng: 0 }],
        starred_counts: [{ tag: 'later', count: 2 }],
        share_ext_token: 'secret',
        social_services: { twitter: { twitter_uid: '1' } },
        user_profile: { secret_token: 'secret' },
        playback_state: { position: 12 }
    }, overrides);
}

test('the stored feed list leaves out secrets, the account and Listen state', function () {
    const stored = cache.storable(response());
    ['share_ext_token', 'social_services', 'user_profile', 'playback_state'].forEach(function (key) {
        assert.equal(key in stored, false, key);
    });
    assert.equal(stored.feeds.length, 3);
    assert.deepEqual(stored.folders, [1, { Tech: [2, 3] }]);
});

test('lists that differ only in counts, timestamps or saved tags draw the same', function () {
    const fresher = response({
        feeds: response().feeds.map(function (feed) {
            return Object.assign({}, feed, { nt: feed.nt + 5, updated: 'just now' });
        }).reverse(),
        starred_counts: [{ tag: 'later', count: 9 }]
    });
    assert.equal(cache.structure_signature(fresher), cache.structure_signature(response()));
});

test('a renamed feed, a new folder or a feed in exception redraws the list', function () {
    const base = cache.structure_signature(response());
    const renamed = response({
        feeds: response().feeds.map(function (feed) {
            return feed.id === 2 ? Object.assign({}, feed, { feed_title: 'Two, renamed' }) : feed;
        })
    });
    const refoldered = response({ folders: [1, { Tech: [2] }, { News: [3] }] });
    const broken = response({
        feeds: response().feeds.map(function (feed) {
            return feed.id === 1 ? Object.assign({}, feed, { has_exception: true, exception_type: 'feed' }) : feed;
        })
    });
    [renamed, refoldered, broken].forEach(function (data) {
        assert.notEqual(cache.structure_signature(data), base);
    });
});

test('merging the server list keeps the counts on screen', function () {
    const merged = cache.without_counts(response().feeds);
    merged.forEach(function (feed) {
        assert.equal('ps' in feed || 'nt' in feed || 'ng' in feed, false);
    });
    assert.equal(merged[1].feed_title, 'Two');
});

test('the counts on screen are written back into the stored list', function () {
    const patched = cache.with_counts(response(), { 2: { ps: 0, nt: 7, ng: 1 }, 'social:9': { ps: 0, nt: 0, ng: 0 } });
    assert.deepEqual([patched.feeds[1].ps, patched.feeds[1].nt, patched.feeds[1].ng], [0, 7, 1]);
    assert.equal(patched.feeds[0].nt, 4);
    assert.equal(patched.social_feeds[0].nt, 0);
    assert.equal(response().feeds[1].nt, 0, 'the original response is untouched');
});

test('each user has a key of their own', function () {
    assert.notEqual(cache.cache_key(7), cache.cache_key(8));
    assert.equal(cache.cache_key(7).indexOf(cache.KEY_PREFIX), 0);
});
