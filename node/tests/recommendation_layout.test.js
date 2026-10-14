const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

test('Discovery feedback preserves the normal stacked story header', () => {
    const css = fs.readFileSync(path.join(__dirname, '../../media/css/controls/recommendation_feedback.css'), 'utf8');
    // recommendation_layout.test.js: A wrapping flex header puts the 700px title beside its metadata on wide screens.
    assert.doesNotMatch(css, /\.NB-feed-story-header-info:has\([^)]*\)\s*\{[^}]*display:\s*(?:inline-)?(?:flex|grid)\s*;/);
    assert.doesNotMatch(css, /\.NB-feed-story-header-info:has\([^)]*\)[^{]*\.NB-feed-story-date-line\s*\{[^}]*flex\s*:/);
});
