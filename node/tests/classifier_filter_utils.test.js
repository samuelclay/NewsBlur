const test = require('node:test');
const assert = require('node:assert/strict');

const classifier_filter_utils = require('../../media/js/newsblur/common/classifier_filter_utils.js');

test('reload options preserve the active classifier filter', function () {
    const classifier_filter = {
        type: 'author',
        value: 'John Voorhees',
        scope: 'feed'
    };

    assert.deepEqual(
        classifier_filter_utils.preserve_active_filter({ order: 'newest' }, classifier_filter),
        {
            order: 'newest',
            classifier_filter: classifier_filter
        }
    );
});

test('reload options do not add an inactive classifier filter', function () {
    assert.deepEqual(
        classifier_filter_utils.preserve_active_filter({ order: 'newest' }, null),
        { order: 'newest' }
    );
});

test('reload options respect an explicitly supplied classifier filter', function () {
    const supplied_filter = { type: 'tag', value: 'comics', scope: 'feed' };

    assert.deepEqual(
        classifier_filter_utils.preserve_active_filter(
            { classifier_filter: supplied_filter },
            { type: 'author', value: 'John Voorhees', scope: 'feed' }
        ),
        { classifier_filter: supplied_filter }
    );
});

test('result summaries distinguish loading, exact, partial, and empty results', function () {
    assert.equal(
        classifier_filter_utils.format_result_summary(null, false, 'MacStories'),
        'Finding matching stories in MacStories…'
    );
    assert.equal(
        classifier_filter_utils.format_result_summary(0, false, 'MacStories'),
        'Finding matching stories in MacStories…'
    );
    assert.equal(
        classifier_filter_utils.format_result_summary(0, true, 'MacStories'),
        'No matching stories in MacStories'
    );
    assert.equal(
        classifier_filter_utils.format_result_summary(1, true, 'MacStories'),
        '1 matching story in MacStories'
    );
    assert.equal(
        classifier_filter_utils.format_result_summary(12, true, 'MacStories'),
        '12 matching stories in MacStories'
    );
    assert.equal(
        classifier_filter_utils.format_result_summary(120, false, 'All sites'),
        '120 matching stories loaded from All sites'
    );
});

test('story-list highlighting only targets visible matching fields', function () {
    assert.equal(classifier_filter_utils.story_title_highlight_selector('title'), '.NB-storytitles-title');
    assert.equal(classifier_filter_utils.story_title_highlight_selector('author'), '.NB-storytitles-author');
    assert.equal(
        classifier_filter_utils.story_title_highlight_selector('text'),
        '.NB-storytitles-content-preview'
    );
    assert.equal(classifier_filter_utils.story_title_highlight_selector('tag'), null);
    assert.equal(classifier_filter_utils.story_title_highlight_selector('url'), null);
});
