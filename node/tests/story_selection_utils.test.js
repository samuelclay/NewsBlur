const test = require('node:test');
const assert = require('node:assert/strict');

const story_selection_utils = require('../../media/js/newsblur/common/story_selection_utils.js');

function make_story(attrs) {
    return {
        get: function (key) {
            return attrs[key];
        }
    };
}

test('find_story_by_hash_or_title prefers exact story hash matches', function () {
    const stories = [
        make_story({ story_hash: '1:hash-a', story_title: 'First story' }),
        make_story({ story_hash: '1:hash-b', story_title: 'Second story' })
    ];

    const story = story_selection_utils.find_story_by_hash_or_title(stories, {
        story_id: '1:hash-b',
        story_title: 'First story',
        allow_title_fallback: true
    });

    assert.equal(story.get('story_hash'), '1:hash-b');
});

test('find_story_by_hash_or_title falls back to normalized title matches', function () {
    const stories = [
        make_story({ story_hash: '1:hash-a', story_title: 'Not the right story' }),
        make_story({ story_hash: '1:hash-b', story_title: 'Clustered & Hidden Story' })
    ];

    const story = story_selection_utils.find_story_by_hash_or_title(stories, {
        story_id: '1:missing-hash',
        story_title: '  clustered &amp; hidden   story ',
        allow_title_fallback: true
    });

    assert.equal(story.get('story_hash'), '1:hash-b');
});

test('find_story_by_hash_or_title does not title-match before fallback is enabled', function () {
    const stories = [
        make_story({ story_hash: '1:hash-b', story_title: 'Clustered & Hidden Story' })
    ];

    const story = story_selection_utils.find_story_by_hash_or_title(stories, {
        story_id: '1:missing-hash',
        story_title: 'Clustered & Hidden Story',
        allow_title_fallback: false
    });

    assert.equal(story, null);
});

test('unread_view_name_for_story_score maps hidden stories to the correct threshold', function () {
    assert.equal(story_selection_utils.unread_view_name_for_story_score(2), 'positive');
    assert.equal(story_selection_utils.unread_view_name_for_story_score(0), 'neutral');
    assert.equal(story_selection_utils.unread_view_name_for_story_score(-1), 'negative');
});
