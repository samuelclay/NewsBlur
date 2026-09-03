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
    assert.match(
        make_classifier,
        /NEWSBLUR\.reader\.open_classifier_filter\([\s\S]*classifier_type,[\s\S]*classifier_value/
    );
});

test('dashboard trainer matching view falls back to the trainer feed', function () {
    const trainer_js = repo_file('media/js/newsblur/reader/reader_classifier.js');
    const reader_js = repo_file('media/js/newsblur/reader/reader.js');
    const function_start = trainer_js.indexOf('make_classifier: function');
    const function_end = trainer_js.indexOf('\n    select_scope:', function_start);
    const make_classifier = trainer_js.slice(function_start, function_end);

    assert.match(make_classifier, /filter_feed_id\s*=\s*this\.feed_id/);
    assert.match(make_classifier, /filter_options\.feed_id\s*=\s*filter_feed_id/);
    assert.match(reader_js, /window\.location\.pathname\s*===\s*'\/'/);
    assert.match(reader_js, /this\.open_feed\(opts\.feed_id,[\s\S]*classifier_filter/);
});

test('manage trainer does not offer literal matching view for regex classifiers', function () {
    const js = repo_file('media/js/newsblur/reader/reader_classifier.js');
    const function_start = js.indexOf('make_manage_classifier_item: function');
    const function_end = js.indexOf('\n    change_manage_classifier:', function_start);
    const make_manage_classifier_item = js.slice(function_start, function_end);

    assert.notEqual(function_start, -1);
    assert.notEqual(function_end, -1);
    assert.match(
        make_manage_classifier_item,
        /has_filter_view\s*=\s*!is_regex\s*&&[\s\S]*FILTER_TYPES/
    );
});

test('story classifier pills embed browse buttons for matching-story views', function () {
    const js = repo_file('media/js/newsblur/views/story_detail_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /classifier_filter_button_html\("author",\s*story\.story_authors\(\)\)/);
    assert.match(js, /classifier_filter_button_html\("tag",\s*tag\)/);
    assert.match(js, /classifier_filter_button_html\("url",\s*story\.get\("story_permalink"\)\)/);
    assert.match(js, /title="View matching stories"/);
    assert.match(js, /aria-label="View matching stories"/);
    assert.match(js, /data-classifier-type=/);
    assert.match(js, /data-classifier-value=/);
    assert.match(js, /M224,104v96a16,16,0,0,1-16,16H48/);
    assert.doesNotMatch(js, /M237\.22,151\.9l0-\.1/);
    assert.match(js, /\.NB-score-icon, \.NB-score-icon-double, \.NB-pill-view-classifier/);
    assert.doesNotMatch(js, /(?:mouseenter|mousemove) \.NB-feed-story-(?:tag|author|url)/);
    assert.doesNotMatch(js, /show_pill_filter_menu:/);
    assert.doesNotMatch(js, /this\.attach_classifier_filter_tooltips\(\);/);
    assert.doesNotMatch(js, /attach_classifier_filter_tooltips:\s*function/);
    assert.match(js, /"mousemove \.NB-pill-view-classifier":\s*"show_classifier_filter_tooltip"/);
    assert.match(js, /"mouseleave \.NB-pill-view-classifier":\s*"hide_classifier_filter_tooltip"/);
    assert.match(js, /show_classifier_filter_tooltip:\s*function[\s\S]*?tippy\(e\.currentTarget/);
    assert.match(js, /trigger:\s*'manual'/);

    const author_start = js.indexOf('<span class="NB-feed-story-author');
    const author_button = js.indexOf('classifier_filter_button_html("author"', author_start);
    const author_end = js.indexOf('</span>', author_start);
    assert.ok(author_button > author_start && author_button < author_end);

    const tag_start = js.indexOf('<div class="NB-feed-story-tag ');
    const tag_button = js.indexOf('classifier_filter_button_html("tag"', tag_start);
    const tag_end = js.indexOf('</div>', tag_start);
    assert.ok(tag_button > tag_start && tag_button < tag_end);

    const button_rule = css_rule(css, '.NB-pill-view-classifier');
    assert.match(button_rule, /width:\s*18px;/);
    assert.match(button_rule, /height:\s*18px;/);
    assert.match(button_rule, /background:\s*transparent;/);

    const button_hover_rule = css_rule(css, '.NB-pill-view-classifier:hover,\n.NB-pill-view-classifier:focus-visible');
    assert.match(button_hover_rule, /background:\s*rgba\(0, 0, 0, \.12\);/);
    assert.match(button_hover_rule, /opacity:\s*1;/);
});

test('filter banner labels each segment and keeps the clear action icon-only', function () {
    const js = repo_file('media/js/newsblur/views/classifier_filter_banner_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /className:\s*'NB-classifier-filter-banner-heading'/);
    assert.doesNotMatch(js, /format_result_summary/);
    assert.doesNotMatch(js, /NB-classifier-filter-banner-subtext/);
    assert.doesNotMatch(css, /\.NB-classifier-filter-banner-subtext/);
    assert.match(js, /'aria-label':\s*'Clear classifier filter'/);
    assert.match(js, /feed:\s*'Site'/);
    assert.match(js, /folder:\s*'Folder'/);
    assert.match(js, /global:\s*'All'/);
    assert.match(js, /short_label:\s*'Like'/);
    assert.match(js, /short_label:\s*'Dislike'/);
    assert.match(js, /short_label:\s*'Hide'/);
    assert.match(js, /NB-classifier-filter-super-dislike-icon/);
    assert.doesNotMatch(js, /M3 3l18 18/);
    assert.match(js, /className:\s*'NB-classifier-filter-button-label'/);
    assert.doesNotMatch(js, /NB-classifier-filter-banner-clear-label/);
    assert.match(css, /\.NB-classifier-filter-button-label\s*\{/);

    const clear_rule = css_rule(css, '.NB-classifier-filter-banner-clear');
    assert.match(clear_rule, /width:\s*32px;/);
    assert.match(clear_rule, /min-height:\s*32px;/);
    assert.match(clear_rule, /padding:\s*0;/);
});

test('filter banner reuses trainer thumb icons and sentiment colors', function () {
    const js = repo_file('media/js/newsblur/views/classifier_filter_banner_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /NB-classifier-filter-training-icon NB-training-icon-like/);
    assert.match(js, /NB-classifier-filter-training-icon NB-training-icon-dislike/);
    assert.doesNotMatch(js, /var thumb_down_svg/);
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-icon.NB-training-icon-like'),
        /thumbs-up\.svg/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-icon.NB-training-icon-dislike'),
        /thumbs-down\.svg/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-training-like.NB-active'),
        /color:\s*#34912E;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-training-dislike.NB-active'),
        /color:\s*#A90103;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-training-super_dislike.NB-active'),
        /color:\s*#6B0001;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-training-like .NB-classifier-filter-training-icon'),
        /color:\s*#34912E;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-training-dislike .NB-classifier-filter-training-icon'),
        /color:\s*#A90103;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-training-super_dislike .NB-classifier-filter-training-icon'),
        /color:\s*#6B0001;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-active'),
        /box-shadow:\s*inset 0 -2px 0 currentColor;/
    );
    assert.match(
        css_rule(css, '.NB-classifier-filter-training-button.NB-active .NB-classifier-filter-button-label'),
        /color:\s*#252329;/
    );
    assert.match(
        css,
        /\.NB-dark \.NB-classifier-filter-training-button\.NB-training-like\.NB-active\s*\{[^}]*color:\s*#34912E;/s
    );
    assert.match(
        css,
        /\.NB-dark \.NB-classifier-filter-training-button\.NB-training-dislike\.NB-active\s*\{[^}]*color:\s*#A90103;/s
    );
    assert.match(
        css,
        /\.NB-dark \.NB-classifier-filter-training-button\.NB-training-super_dislike\.NB-active\s*\{[^}]*color:\s*#6B0001;/s
    );
    assert.match(
        css_rule(css, '.NB-dark .NB-classifier-filter-training-button.NB-active .NB-classifier-filter-button-label'),
        /color:\s*#F4F1F5;/
    );
});

test('filter banner renders notification channels inline with Premium Archive gating', function () {
    const js = repo_file('media/js/newsblur/views/classifier_filter_banner_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /this\._make_notification_controls\(/);
    assert.doesNotMatch(js, /_make_notification_bell:\s*function/);
    assert.doesNotMatch(js, /_show_notification_popover:\s*function/);
    assert.match(js, /"click \.NB-classifier-filter-notification-button":\s*"toggle_notification"/);
    assert.match(js, /className:\s*'NB-classifier-filter-tool-label'\s*},\s*'Notify on'/);
    assert.match(js, /short_label:\s*'Email'/);
    assert.match(js, /short_label:\s*'Web'/);
    assert.match(js, /short_label:\s*'iOS'/);
    assert.match(js, /short_label:\s*'Android'/);
    assert.match(js, /NEWSBLUR\.Globals\.is_archive/);
    assert.match(js, /Upgrade to Premium Archive/);
    assert.match(js, /highlight_feature:\s*'notifications'/);
    assert.match(js, /className:\s*'NB-classifier-filter-notification-content'/);

    const tools_rule = css_rule(css, '.NB-classifier-filter-banner-tools');
    const label_rule = css_rule(css, '.NB-classifier-filter-tool-label');
    assert.match(tools_rule, /flex-direction:\s*column;/);
    assert.match(label_rule, /flex:\s*0 0 64px;/);
    assert.match(css, /\.NB-classifier-filter-notification-button\s*\{/);
    assert.match(css, /\.NB-classifier-filter-notification-upgrade\s*\{/);
    assert.match(
        css_rule(css, '.NB-classifier-filter-notification-content'),
        /flex-wrap:\s*wrap;/
    );
});

test('filter banner separates the temporary view filter from account actions', function () {
    const js = repo_file('media/js/newsblur/views/classifier_filter_banner_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /className:\s*'NB-classifier-filter-view-section'/);
    assert.match(js, /Filter stories/);
    assert.doesNotMatch(js, /Filter this view/);
    assert.doesNotMatch(js, /Apply to/);
    assert.match(js, /className:\s*'NB-classifier-filter-account-section'/);
    assert.doesNotMatch(js, /Save to account/);
    assert.match(js, /className:\s*'NB-classifier-filter-account-controls'/);
    assert.match(
        css,
        /\.NB-classifier-filter-account-section\s*\{[^}]*border-radius:\s*7px;[^}]*background:\s*rgba\(/s
    );
    assert.doesNotMatch(css, /\.NB-classifier-filter-account-controls::before\s*\{/);
    assert.doesNotMatch(css, /\.NB-classifier-filter-account-controls \.NB-classifier-filter-tool-group::before\s*\{/);
});

test('filter banner segmented controls use the house style and retain active underlines', function () {
    const css = repo_file('media/css/reader/reader.css');
    const segmented_rule = css_rule(css, '.NB-classifier-filter-segmented');

    assert.match(segmented_rule, /padding:\s*1px;/);
    assert.match(segmented_rule, /border:\s*0;/);
    assert.match(segmented_rule, /background:\s*transparent;/);
    assert.match(
        css,
        /\.NB-classifier-filter-segmented:hover\s*\{[^}]*background(?:-color)?:\s*#E5E6E2;/s
    );
    assert.match(
        css,
        /\.NB-classifier-filter-scope-button,[\s\S]*?\.NB-classifier-filter-notification-button\s*\{[^}]*margin:\s*0 2px 0 0;[^}]*border-radius:\s*3px;/s
    );
    assert.match(
        css,
        /\.NB-classifier-filter-scope-button\.NB-active,[\s\S]*?\.NB-classifier-filter-notification-button\.NB-active\s*\{[^}]*background:\s*#D5D6D2;[^}]*box-shadow:\s*inset 0 -2px 0 var\(--classifier-accent\);/s
    );
    assert.match(
        css,
        /\.NB-dark \.NB-classifier-filter-segmented:hover\s*\{[^}]*background(?:-color)?:\s*#494D54;/s
    );
});

test('filter banner has deliberate layouts down to the story pane minimum width', function () {
    const js = repo_file('media/js/newsblur/views/classifier_filter_banner_view.js');
    const css = repo_file('media/css/reader/reader.css');
    const tools_rule = css_rule(css, '.NB-classifier-filter-banner-tools');

    assert.match(js, /className:\s*'NB-classifier-filter-narrow-hint'/);
    assert.match(js, /Widen pane/);
    assert.match(js, /NB-classifier-filter-narrow-hint-compact/);
    assert.match(tools_rule, /opacity:\s*1;/);
    assert.doesNotMatch(tools_rule, /transition:\s*opacity/);
    assert.match(css, /@container\s*\(max-width:\s*430px\)/);
    assert.match(css, /@container\s*\(max-width:\s*340px\)/);
    assert.match(css, /@container\s*\(max-width:\s*300px\)/);
    assert.match(css, /@container\s*\(max-width:\s*240px\)/);
    assert.match(css, /@container\s*\(max-width:\s*200px\)/);
    assert.match(css, /@container\s*\(max-width:\s*120px\)/);
});

test('matching-story mode displays its temporary all-stories read filter', function () {
    const story_titles_header = repo_file('media/js/newsblur/views/story_titles_header_view.js');
    const feed_title = repo_file('media/js/newsblur/views/feed_title_view.js');
    const feed_options = repo_file('media/js/newsblur/views/feed_options_popover.js');

    assert.match(story_titles_header, /read_filter_for_matching_view/);
    assert.match(feed_title, /read_filter_for_matching_view/);
    assert.match(feed_options, /read_filter_for_matching_view/);
});

test('notification controls compact before they can cross the account surface', function () {
    const css = repo_file('media/css/reader/reader.css');
    const compact_start = css.indexOf('@container (max-width: 380px)');
    const compact_end = css.indexOf('\n@container', compact_start + 1);

    assert.notEqual(compact_start, -1);
    assert.notEqual(compact_end, -1);
    const compact_css = css.slice(compact_start, compact_end);
    assert.match(compact_css, /\.NB-classifier-filter-banner-icon\s*\{[^}]*display:\s*none;/s);
    assert.match(compact_css, /\.NB-classifier-filter-notification-button/);
    assert.match(compact_css, /padding-right:\s*6px;/);
    assert.match(compact_css, /padding-left:\s*6px;/);
});

test('filtered story titles apply a dedicated match highlight', function () {
    const js = repo_file('media/js/newsblur/views/story_title_view.js');
    const css = repo_file('media/css/reader/reader.css');

    assert.match(js, /apply_classifier_filter_highlight/);
    assert.match(js, /story_title_highlight_selector/);
    assert.match(js, /NB-classifier-filter-highlight/);
    assert.match(css, /\.NB-classifier-filter-highlight\s*\{/);
});
