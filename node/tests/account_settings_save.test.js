const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function account_fixture() {
    const requests = [];
    let callback;
    const element = {};
    for (const method of ['text', 'attr', 'addClass']) element[method] = () => element;
    element.val = value => value === undefined ? '25' : element;
    const context = {
        NEWSBLUR: {
            Modal: function () {}, log() {},
            Globals: { can_use_ai_classifiers: true },
            Preferences: { send_emails: true, notify_before_renewal: false, invoice_text: 'Old' },
        },
        _: { extend: Object.assign, bind: (fn, self) => fn.bind(self) },
        $: () => element,
        gettext: text => text,
    };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/reader/reader_account.js'), 'utf8'), context);
    const account = Object.create(context.NEWSBLUR.ReaderAccount.prototype);
    account.serialize_preferences = () => ({ send_emails: false, notify_before_renewal: true, invoice_text: 'New' });
    account.model = {
        preference() { requests.push('preference'); },
        save_usage_billing_limit() { requests.push('usage'); },
        save_account_settings(form, done) { requests.push('account'); callback = done; },
    };
    account.close = () => {};
    account.disable_save = () => {};
    account.switch_tab = () => {};
    return { account, requests, preferences: context.NEWSBLUR.Preferences, respond: data => callback(data) };
}

test('account preferences save in one request before usage billing can write the profile', () => {
    const fixture = account_fixture();
    fixture.account.save_account_settings();
    assert.deepEqual(fixture.requests, ['account']);
    assert.equal(fixture.preferences.invoice_text, 'Old');
    assert.equal(fixture.preferences.send_emails, true);
    fixture.respond({ code: 1, payload: { username: 'owner', email: 'owner@example.com', invoice_text: 'New', send_emails: false, notify_before_renewal: true } });
    assert.deepEqual(fixture.requests, ['account', 'usage']);
    assert.equal(fixture.preferences.invoice_text, 'New');
    assert.equal(fixture.preferences.send_emails, false);
    assert.equal(fixture.preferences.notify_before_renewal, true);
});

test('rejected account settings leave cached preferences and usage billing unchanged', () => {
    const fixture = account_fixture();
    fixture.account.save_account_settings();
    fixture.respond({ code: -4, message: 'Invalid invoice text' });
    assert.deepEqual(fixture.requests, ['account']);
    assert.equal(fixture.preferences.invoice_text, 'Old');
    assert.equal(fixture.preferences.send_emails, true);
    assert.equal(fixture.preferences.notify_before_renewal, false);
});
