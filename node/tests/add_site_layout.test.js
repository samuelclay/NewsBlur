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

test('add site tab pane owns tab scrolling', function () {
    const css = repo_file('media/css/reader/reader.css');
    const tab_pane_rule = css_rule(css, '.NB-add-site-tab-pane');
    const tab_results_rule = css_rule(css, '.NB-add-site-tab-results');
    const webfeed_rule = css_rule(css, '.NB-add-site-webfeed-content');

    assert.match(tab_pane_rule, /overflow-y:\s*auto;/);
    assert.match(tab_pane_rule, /overflow-x:\s*hidden;/);
    assert.match(tab_pane_rule, /padding:\s*20px 16px 48px 0;/);
    assert.match(tab_results_rule, /overflow:\s*visible;/);
    assert.doesNotMatch(tab_results_rule, /overflow-y:\s*auto;/);
    assert.match(webfeed_rule, /overflow:\s*visible;/);
});

test('add site infinite scroll binds to active tab pane', function () {
    const js = repo_file('media/js/newsblur/views/add_site_view.js');

    assert.match(js, /get_active_tab_scrollable:\s*function \(\) \{\s*return this\.\$\('\.NB-add-site-tab-pane\.NB-active'\);/);
    assert.match(js, /bind_scroll_handler:\s*function \(\) \{[\s\S]*var \$scrollable = this\.get_active_tab_scrollable\(\);/);
    assert.match(js, /this\.\$\('\.NB-add-site-tab-pane'\)\.off\('scroll\.infinite'\);/);
    assert.doesNotMatch(js, /this\.\$\('\.NB-add-site-tab-results'\)[\s\S]{0,120}\.on\('scroll\.infinite'/);
});
