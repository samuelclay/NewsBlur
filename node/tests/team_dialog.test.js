const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// team_dialog.test.js: the server's dates are UTC with no zone, so the tests run away from UTC to tell a date read
// as UTC from one read as local time.
process.env.TZ = 'America/Los_Angeles';

const read = file => fs.readFileSync(path.join(__dirname, '../..', file), 'utf8');
const plain = value => JSON.parse(JSON.stringify(value));

// team_dialog.test.js: reader_team.js's rules (NEWSBLUR.ReaderTeam) on the underscore the reader ships, with
// gettext's English.
function team_rules() {
    const context = {
        NEWSBLUR: { Modal: function () {}, SettingsDialog: {} },
        gettext: text => text,
        ngettext: (singular, plural, count) => (count == 1 ? singular : plural),
        interpolate: (format, values) => format.replace(/%\((\w+)\)s/g, (match, name) => String(values[name])),
    };
    vm.runInNewContext(read('media/js/vendor/underscore-1.4.3.js'), context);
    vm.runInNewContext(read('media/js/newsblur/reader/reader_team.js'), context);
    return { rules: context.NEWSBLUR.ReaderTeam, interpolate: context.interpolate };
}

const team_sources = () => fs.readdirSync(path.join(__dirname, '../../apps/team'))
    .filter(file => file.endsWith('.py') && file != 'tests.py')
    .map(file => read('apps/team/' + file))
    .join('\n');

test('each seat shows only the controls the server lets the viewer use on it', () => {
    const { rules } = team_rules();
    const owner = { user_id: 1, role: 'owner' };
    const manager = { user_id: 2, role: 'manager' };
    const other_manager = { user_id: 3, role: 'manager' };
    const member = { user_id: 4, role: 'member' };
    const none = { change_role: false, remove: false, leave: false };
    const controls = (viewer_role, viewer_id, seat) => plain(rules.seat_controls(viewer_role, viewer_id, seat));

    // apps/team/models.py TeamMember.can_remove and apps/team/views.py change_role.
    assert.deepEqual(controls('owner', 1, owner), none);
    assert.deepEqual(controls('owner', 1, manager), { change_role: true, remove: true, leave: false });
    assert.deepEqual(controls('owner', 1, member), { change_role: true, remove: true, leave: false });
    assert.deepEqual(controls('manager', 2, member), { change_role: false, remove: true, leave: false });
    assert.deepEqual(controls('manager', 2, other_manager), none);
    assert.deepEqual(controls('manager', 2, owner), none);
    assert.deepEqual(controls('manager', 2, manager), { change_role: false, remove: false, leave: true });
    assert.deepEqual(controls('member', 4, manager), none);
    assert.deepEqual(controls('member', 4, member), { change_role: false, remove: false, leave: true });
});

test('only owners and managers invite and read the activity log, and only the owner renames, hands over and invites managers', () => {
    const { rules } = team_rules();
    const sections = (role, status) => plain(rules.team_sections({ role: role, status: status || 'active' }));

    assert.deepEqual(sections('owner'), {
        rename: true, invite: true, invite_managers: true, hand_over: true, leave: false, activity: true, more_seats: true,
    });
    assert.deepEqual(sections('manager'), {
        rename: false, invite: true, invite_managers: false, hand_over: false, leave: true, activity: true, more_seats: true,
    });
    assert.deepEqual(sections('member'), {
        rename: false, invite: false, invite_managers: false, hand_over: false, leave: true, activity: false, more_seats: false,
    });
    // An inactive team takes no invites (apps/team/models.py Team.invite_by_email).
    assert.equal(sections('owner', 'inactive').invite, false);
});

test('every action the server logs reads as its own sentence with every name filled in', () => {
    const { rules, interpolate } = team_rules();
    const sources = team_sources();
    const actions = new Set(
        [...sources.matchAll(/(?:TeamActivity\.log|_end_transfer)\((?:[^()"]|\([^()]*\))*?"(\w+)"/g)].map(match => match[1]));
    assert.ok(actions.size >= 20, 'found only ' + [...actions].join(', '));

    const details = {
        name: 'Desk', old_name: 'Newsroom', email: 'casey@example.com', role: 'manager', user_id: 5, username: 'casey',
        plan: 'team_enterprise', old_plan: 'team', seat_limit: 25, old_seat_limit: 10, seats: 25, via: 'email', replaced: true,
    };
    const fallback = rules.activity_message({ action: 'not_an_action', actor: 'maya', details: {} }).message;
    for (const action of actions) {
        const sentence = rules.activity_message({ action: action, actor: 'maya', details: details }, []);
        assert.notEqual(sentence.message, fallback, action + ' has no sentence of its own');
        assert.doesNotMatch(interpolate(sentence.message, sentence.values), /undefined|%\(/, action);
    }
});

test('an action the dialog has no sentence for, or by an account since deleted, still reads sensibly', () => {
    const { rules, interpolate } = team_rules();
    const text = entry => {
        const sentence = rules.activity_message(entry, []);
        return interpolate(sentence.message, sentence.values);
    };

    assert.equal(text({ action: 'team_archived', actor: 'maya', details: {} }), 'maya changed the team');
    assert.equal(text({ action: 'team_archived', actor: null, details: {} }), 'The team was changed');
    assert.equal(text({ action: 'member_left', actor: null, details: {} }), 'Someone left the team');
});

test('a change staff made is said to be NewsBlur staff\'s, not the staff member\'s', () => {
    const { rules, interpolate } = team_rules();
    const text = (action, details) => {
        const sentence = rules.activity_message({ action: action, actor: 'samuel', details: details }, []);
        return interpolate(sentence.message, sentence.values);
    };

    assert.equal(text('seat_limit_changed', { seat_limit: 25, old_seat_limit: 10 }), 'The seat limit was raised to 25 by NewsBlur staff');
    assert.equal(text('seat_limit_changed', { seat_limit: 12, old_seat_limit: 25 }), 'The seat limit was lowered to 12 by NewsBlur staff');
    for (const action of ['plan_changed', 'comp_started', 'comp_ended']) {
        assert.doesNotMatch(text(action, { plan: 'team' }), /samuel/, action);
    }
});

test('a teammate the log names only by id is found among the members, or left out of the sentence', () => {
    const { rules, interpolate } = team_rules();
    const text = (members) => {
        // apps/team/models.py Team._end_transfer logs who was asked by id alone.
        const sentence = rules.activity_message({ action: 'transfer_cancelled', actor: 'maya', details: { user_id: 3 } }, members);
        return interpolate(sentence.message, sentence.values);
    };

    assert.equal(text([{ user_id: 3, username: 'devon' }]), 'maya cancelled the request for devon to take over the team');
    assert.equal(text([]), 'maya cancelled the request to take over the team');
});

test('the Billing tab offers a change of plan only where the web can make it', () => {
    const { rules } = team_rules();
    const owner_team = (billing, status) => ({
        role: 'owner', status: status || 'active', plan: 'team',
        members: [{ user_id: 1, username: 'maya', role: 'owner' }],
        billing: Object.assign({ comped: false, paid_through: '2026-12-27 10:00:00', pending_plan: null, monthly_price: 79 }, billing),
    });
    const state = team => plain(rules.billing_state(team));

    assert.deepEqual(state(owner_team({ provider: 'stripe' })).actions, ['change_plan', 'manage_stripe']);
    assert.deepEqual(state(owner_team({ provider: 'paypal' })).actions, ['change_plan', 'manage_paypal']);
    // A store's subscription is changed in that store; the web would refuse it (apps/team/stripe_billing.py).
    for (const provider of ['app_store', 'play']) {
        const store = state(owner_team({ provider: provider }));
        assert.deepEqual([store.store, store.actions], [true, []], provider);
    }
    const comped = state(owner_team({ provider: 'comp', comped: true, paid_through: null }));
    assert.deepEqual([comped.provider, comped.actions, comped.paid_through], ['comp', [], null]);
    // A team whose plan ended can be bought again on the web, whoever billed it before.
    const ended = state(owner_team({ provider: 'app_store' }, 'inactive'));
    assert.deepEqual([ended.ended, ended.actions], [true, ['renew']]);
    // A switch down to a plan of the owner's own ends the team; one between team plans doesn't.
    assert.equal(state(owner_team({ provider: 'stripe', pending_plan: 'pro' })).pending.ends_team, true);
    assert.equal(state(owner_team({ provider: 'stripe', pending_plan: 'team' })).pending.ends_team, false);
});

test('a teammate\'s Billing tab names the owner and the plan, with nothing to change', () => {
    const { rules } = team_rules();
    const teammate = plain(rules.billing_state({
        role: 'manager', status: 'active', plan: 'team_enterprise',
        members: [{ user_id: 2, username: 'devon', role: 'manager' }, { user_id: 1, username: 'maya', role: 'owner' }],
    }));

    assert.deepEqual([teammate.kind, teammate.owner, teammate.plan, teammate.actions], ['teammate', 'maya', 'team_enterprise', []]);
});

test('every reason the server turns a team purchase away with has a message', () => {
    const { rules } = team_rules();
    const source = read('apps/team/stripe_billing.py');
    const body = source.slice(source.indexOf('def team_purchase_refusal'), source.indexOf('\ndef ', source.indexOf('def team_purchase_refusal') + 1));
    const reasons = [...body.matchAll(/return "(\w+)"/g)].map(match => match[1]);
    assert.ok(reasons.length >= 3, 'found only ' + reasons.join(', '));

    for (const reason of reasons) {
        assert.ok(rules.purchase_refusal_message(reason), reason);
    }
    assert.equal(rules.purchase_refusal_message('not_a_reason'), null);
});

test('a server date is read as UTC', () => {
    const { rules } = team_rules();

    assert.equal(rules.parse_date('2026-12-11 21:25:54.590000').toISOString(), '2026-12-11T21:25:54.590Z');
    assert.equal(rules.parse_date('2026-12-11 21:25:54').toISOString(), '2026-12-11T21:25:54.000Z');
    assert.equal(rules.parse_date(null), null);
});
