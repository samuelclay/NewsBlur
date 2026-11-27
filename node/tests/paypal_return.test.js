const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// paypal_return.test.js: the page Stripe Checkout and a plan switch return to, which waits for the purchase.
function return_page(search) {
    const requests = [];
    let start;
    let every_two_seconds;
    const element = { length: 0, ready() {}, progressbar() {} };
    const context = {
        NEWSBLUR: {},
        document: {},
        window: { location: { pathname: '/profile/stripe_return', search: search, href: '' } },
        _: {
            delay: fn => { start = fn; },
            bind: (fn, self) => fn.bind(self),
            string: { include: (text, part) => text.includes(part) },
        },
        jQuery: Object.assign(() => element, { ajax: options => requests.push(options) }),
        setInterval: fn => { every_two_seconds = fn; },
    };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../media/js/newsblur/payments/paypal_return.js'), 'utf8'), context);
    new context.NEWSBLUR.PaypalReturn();
    start();
    return {
        requests,
        location: context.window.location,
        // paypal_return.test.js: the answer to the latest request, then the next poll.
        answer(data) {
            requests[requests.length - 1].success(data);
            every_two_seconds();
        },
    };
}

test('a team purchase waits for the team, then opens the team dialog, and never asks for Premium', () => {
    const page = return_page('?plan=team_enterprise');
    page.answer({ code: 1, team: null });
    assert.equal(page.location.href, '');
    page.answer({ code: 1, team: { role: 'owner' } });
    assert.equal(page.location.href, '/?next=team');
    assert.ok(page.requests.every(request => request.url == '/team/'));
});

test('a team that never shows up still ends on the team dialog, not on Premium', () => {
    const page = return_page('?plan=team');
    for (let tries = 0; tries < 31; tries++) page.answer({ code: 1, team: null });
    assert.equal(page.location.href, '/?next=team');
    assert.ok(page.requests.every(request => request.url == '/team/'));
});

test('any other purchase still waits for Premium', () => {
    const page = return_page('');
    assert.equal(page.requests[0].url, '/profile/is_premium');
});
