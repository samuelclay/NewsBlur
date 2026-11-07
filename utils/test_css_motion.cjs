// test_css_motion.cjs validates easing functions in the actual reader and page stylesheets.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

test('button color and shadow transitions retain complete CSS easing functions', () => {
    const files = ['media/css/reader/reader.css', 'media/css/reader/modals.css',
        'media/css/reader/growth_prompts.css', 'media/css/pages/welcome.css',
        'media/css/pages/static_pages.css', 'media/css/pages/faq_modal.css'];
    for (const file of files) {
        const css = fs.readFileSync(file, 'utf8');
        for (const match of css.matchAll(/\btransition(?:-timing-function)?:\s*([^;]+);/g)) {
            const location = `${file}:${css.slice(0, match.index).split('\n').length}`;
            let depth = 0;
            for (const character of match[1]) {
                if (character === '(') depth++;
                if (character === ')') depth--;
                assert.ok(depth >= 0, `${location}: unmatched closing parenthesis invalidates ${match[0]}`);
            }
            assert.equal(depth, 0, `${location}: incomplete easing function invalidates ${match[0]}`);
        }
    }
});
