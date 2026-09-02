const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function repo_file(relative_path) {
    return fs.readFileSync(path.join(__dirname, '..', '..', relative_path), 'utf8');
}

function css_rule(css, selector) {
    const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = css.match(new RegExp(escaped + '\\s*\\{([^}]*)\\}', 'm'));
    assert.ok(match, 'Missing CSS rule for ' + selector);
    return match[1];
}

test('trainer matching-stories control is an accessible sibling of the classifier pill', function () {
    const css = repo_file('media/css/reader/reader.css');
    const js = repo_file('media/js/newsblur/reader/reader_classifier.js');
    const item_rule = css_rule(css, '.NB-manage-classifier-item');
    const button_rule = css_rule(
        css,
        '.NB-manage-classifier-item .NB-classifier-filter-view-btn'
    );

    assert.match(js, /\$filter_view_button\s*=\s*has_filter_view\s*&&\s*\$\.make\('button'/);
    assert.match(js, /'aria-label':\s*'View matching stories'/);
    assert.match(js, /\$filter_view_button\s*\n?\s*\]\);/);
    assert.match(item_rule, /display:\s*inline-flex;/);
    assert.match(button_rule, /position:\s*static;/);
    assert.match(button_rule, /margin-left:\s*2px;/);
});

test('story trainer classifier rows include the matching-stories button', function () {
    const js = repo_file('media/js/newsblur/reader/reader_classifier.js');
    const function_start = js.indexOf('make_classifier: function');
    const function_end = js.indexOf('\n    select_scope:', function_start);
    const make_classifier = js.slice(function_start, function_end);

    assert.notEqual(function_start, -1);
    assert.notEqual(function_end, -1);
    assert.match(make_classifier, /\$filter_view_button\s*=\s*has_filter_view/);
    assert.match(make_classifier, /'aria-label':\s*'View matching stories'/);
    assert.match(make_classifier, /\$filter_view_button[\s\S]*classifier_count/);
    assert.match(make_classifier, /NEWSBLUR\.reader\.open_classifier_filter\(classifier_type, classifier_value/);
});
