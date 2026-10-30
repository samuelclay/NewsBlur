const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo_root = path.resolve(__dirname, '..', '..');

// story_score_ai_priority.test.js: loads media/js/newsblur/reader/reader_utils.js into a
// sandbox so NEWSBLUR.utils.compute_story_score runs exactly as it does in the browser.
function load_reader_utils() {
    const context = {
        NEWSBLUR: {},
        gettext: function (text) { return text; },
        document: { documentElement: { lang: 'en' } },
    };
    vm.createContext(context);
    ['media/js/vendor/underscore-1.4.3.js', 'media/js/newsblur/reader/reader_utils.js'].forEach(function (relative_path) {
        vm.runInContext(fs.readFileSync(path.join(repo_root, relative_path), 'utf8'), context);
    });
    return context.NEWSBLUR.utils;
}

function story_with(intelligence) {
    const scores = Object.assign({ feed: 0, author: 0, tags: 0, title: 0 }, intelligence);
    return { get: function (key) { return key === 'intelligence' ? scores : undefined; } };
}

const utils = load_reader_utils();

test('an AI focus match outranks a disliked author', function () {
    assert.equal(utils.compute_story_score(story_with({ feed: 1, author: -1, prompt: 1 })), 1);
});

test('a super disliked author outranks an AI focus match', function () {
    assert.equal(utils.compute_story_score(story_with({ feed: 1, author: -2, prompt: 1 })), -2);
});

test('a super dislike stays -2 alongside an AI hidden match', function () {
    assert.equal(utils.compute_story_score(story_with({ author: -2, prompt: -1 })), -2);
});

test('an AI hidden match outranks a liked title', function () {
    assert.equal(utils.compute_story_score(story_with({ title: 1, prompt: -1 })), -1);
});
