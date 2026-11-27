const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

test('a typed j belongs to the URL field, while reader navigation still works outside it', () => {
    const jQuery = {
        event: { special: {} },
        each(values, callback) { values.forEach(value => callback.call(value)); },
    };
    vm.runInNewContext(
        fs.readFileSync(path.join(__dirname, '../../media/js/vendor/jquery.hotkeys.js'), 'utf8'),
        { jQuery, NEWSBLUR: {} }
    );

    const shortcut = { data: 'j', handler() { return 'handled'; } };
    jQuery.event.special.keydown.add(shortcut);
    const reader = { nodeName: 'BODY' };
    const urlField = { nodeName: 'INPUT', type: 'url' };
    const keydown = target => ({ type: 'keydown', which: 74, target });

    assert.equal(shortcut.handler.call(reader, keydown(urlField)), undefined);
    assert.equal(shortcut.handler.call(reader, keydown(reader)), 'handled');
    assert.equal(shortcut.handler.call(urlField, keydown(urlField)), 'handled');
});
