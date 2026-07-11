const test = require('node:test');
const assert = require('node:assert/strict');

const title_classifier_utils = require('../../media/js/newsblur/common/title_classifier_utils.js');

test('word-leading classifiers do not match inside words', function () {
    const story_title = 'Por dentro do comitê sigiloso da Fifa que suspendeu o cartão vermelho dos EUA';

    assert.equal(title_classifier_utils.find_match_position(story_title, 'USP'), -1);
});

test('word-leading classifiers continue searching for a later valid occurrence', function () {
    assert.equal(title_classifier_utils.find_match_position('suspendeu USP', 'USP'), 10);
});

test('title classifier stems can continue through the end of a word', function () {
    assert.equal(title_classifier_utils.find_match_position('Foi assassinada ontem', 'assassinad'), 4);
});

test('punctuation-leading classifiers retain substring matching', function () {
    assert.equal(title_classifier_utils.find_match_position('Learn.NET today', '.NET'), 5);
});

test('word-leading classifiers match at the title start and after hyphens', function () {
    assert.equal(title_classifier_utils.find_match_position('USP opens a new office', 'USP'), 0);
    assert.equal(title_classifier_utils.find_match_position('anti-USP campaign', 'USP'), 5);
});

test('accented and decomposed characters prevent an inside-word match', function () {
    assert.equal(title_classifier_utils.find_match_position('préUSP', 'USP'), -1);
    assert.equal(title_classifier_utils.find_match_position('pre\u0301USP', 'USP'), -1);
});

test('title classifier matching is case-insensitive', function () {
    assert.equal(title_classifier_utils.find_match_position('A uSp update', 'UsP'), 2);
});

test('empty title classifier input does not match', function () {
    assert.equal(title_classifier_utils.find_match_position('', 'USP'), -1);
    assert.equal(title_classifier_utils.find_match_position('USP update', ''), -1);
    assert.equal(title_classifier_utils.find_match_position(null, 'USP'), -1);
    assert.equal(title_classifier_utils.find_match_position('USP update'), -1);
});
