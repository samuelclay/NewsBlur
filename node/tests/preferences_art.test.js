const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const read = file => fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/reader', file), 'utf8');

test('every option card in Preferences has a drawing', () => {
    const context = {
        NEWSBLUR: {},
        _: {
            each: (list, fn) => list.forEach(fn), map: (list, fn) => list.map(fn),
            range: count => Array.from({ length: count }, (unused, i) => i),
            contains: (list, value) => list.includes(value), extend: Object.assign,
        },
    };
    vm.runInNewContext(read('reader_preferences_art.js'), context);
    const art = context.NEWSBLUR.PreferencesArt;
    // preferences_art.test.js: reader_preferences.js names a card's drawing as art: '...' or
    // make_art('...'). A name with no drawing behind it would leave that card blank.
    const names = [...read('reader_preferences.js').matchAll(/(?:art: |make_art\()'([\w-]+)'/g)].map(match => match[1]);

    assert.ok(names.length > 60, 'found only ' + names.length + ' cards');
    assert.deepEqual(names.filter(name => !art.has(name)), []);
    names.forEach(name => assert.match(art.draw(name), /^<svg[^>]*>.*<\/svg>$/s, name));
});
