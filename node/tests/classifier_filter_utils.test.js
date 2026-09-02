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
