const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..', '..');

function repo_file(relative_path) {
    return fs.readFileSync(path.join(root, relative_path), 'utf8');
}

function css_rule(css, selector) {
    const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = css.match(new RegExp(escaped + '\\s*\\{([^}]*)\\}'));
    assert.ok(match, `Missing CSS rule for ${selector}`);
    return match[1];
}

test('extra-narrow list stories reflow metadata instead of squeezing columns', function () {
    const css = repo_file('media/css/reader/reader.css');
    const prefix = '#story_titles.NB-layout-list.NB-extra-narrow-content ';

    assert.match(
        css_rule(css, prefix + '.NB-story-title-list.NB-story-title'),
        /padding:\s*0 10px 0 40px;/
    );
    assert.match(
        css_rule(css, prefix + '.NB-story-title-list.NB-story-title.NB-has-image'),
        /padding-right:\s*10px;/
    );
    assert.match(
        css_rule(css, prefix + '.NB-story-title-list .NB-story-feed'),
        /position:\s*static;[\s\S]*display:\s*flex;[\s\S]*width:\s*auto;/
    );
    assert.match(
        css_rule(css, prefix + '.NB-story-title-list .NB-storytitles-title'),
        /display:\s*block;/
    );
    assert.match(
        css_rule(css, prefix + '.NB-story-title-list .NB-storytitles-story-image-container'),
        /display:\s*none;/
    );
    assert.match(
        css_rule(css, prefix + '.NB-story-title-list .story_date'),
        /position:\s*static;[\s\S]*width:\s*auto;/
    );
});
