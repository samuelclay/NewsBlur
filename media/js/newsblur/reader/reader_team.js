// reader_team.js: the team dialog. A team is up to 10 NewsBlur accounts on one bill (apps/team). The dialog is
// made of the same pieces as Preferences (common/settings_dialog.js): tabs, titled groups of rows, option cards
// with drawings and the pill that says a change was saved. Each control sends its own change to the team
// endpoints (apps/team/views.py), which answer with the team as it is now, and the dialog redraws from that.
// What a role may not do, the server refuses, so the dialog shows each role only the controls it can use.

NEWSBLUR.ReaderTeam = function (options) {
    var defaults = {
        width: Math.min(960, $(window).width() - 48)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.team = null;
    this.loaded = false;
    this.active_tab = this.options.tab || 'members';
    this.busy = {};
    this.errors = {};
    this.drafts = {};
    this.pending_roles = {};
    this.confirming = null;
    this.invite_role = 'member';
    this.contact = { open: false, sent: null };
    this.activity = { entries: [], page: 0, has_more: false, loading: false, error: null, stale: true };
    this.notice = this.options.team_purchase && NEWSBLUR.ReaderTeam.purchase_refusal_message(this.options.team_purchase);
    this.runner();
};

NEWSBLUR.ReaderTeam.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderTeam.prototype.constructor = NEWSBLUR.ReaderTeam;

// ==========
// = Rules  =
// ==========

// reader_team.js: what the dialog decides from the team the server sent, kept apart from the drawing so
// node/tests/team_dialog.test.js can check it.
_.extend(NEWSBLUR.ReaderTeam, {

    // reader_team.js: the server's dates are UTC with no zone, "2026-12-11 21:25:54.590000"
    // (utils/json_functions.py). Safari can't read that form and Chrome would read it as local time.
    parse_date: function (value) {
        if (!value) return null;
        var match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?/);
        if (!match) return new Date(value);
        var milliseconds = match[7] ? parseInt((match[7] + '00').slice(0, 3), 10) : 0;
        return new Date(Date.UTC(parseInt(match[1], 10), parseInt(match[2], 10) - 1, parseInt(match[3], 10),
            parseInt(match[4], 10), parseInt(match[5], 10), parseInt(match[6], 10), milliseconds));
    },

    plan_name: function (plan) {
        var names = {
            premium: gettext('Premium'),
            archive: gettext('Premium Archive'),
            archive_extra: gettext('Premium Archive Extra'),
            pro: gettext('Premium Pro'),
            team: gettext('Premium Team'),
            team_enterprise: gettext('Premium Team Enterprise')
        };
        return names[plan] || plan;
    },

    owner_of: function (team) {
        return _.find(team.members, function (member) { return member.role == 'owner'; });
    },

    // reader_team.js: what the viewer can do to one seat, the way the server allows it (apps/team/models.py
    // TeamMember.can_remove, apps/team/views.py change_role): the owner sets managers and members and removes
    // either, a manager removes members, nobody removes the owner or themselves, and everyone but the owner
    // can leave.
    seat_controls: function (viewer_role, viewer_id, member) {
        var is_self = member.user_id == viewer_id;
        var removable = !is_self && member.role != 'owner' &&
            (viewer_role == 'owner' || (viewer_role == 'manager' && member.role == 'member'));
        return {
            change_role: viewer_role == 'owner' && member.role != 'owner',
            remove: removable,
            leave: is_self && member.role != 'owner'
        };
    },

    // reader_team.js: which parts of the dialog the viewer gets. Managers invite and read the activity log
    // (apps/team/views.py invite, activity), only the owner invites managers, renames the team and hands it
    // over, and an inactive team takes no invites (Team.invite_by_email).
    team_sections: function (team) {
        var is_owner = team.role == 'owner';
        var is_manager = is_owner || team.role == 'manager';
        return {
            rename: is_owner,
            invite: is_manager && team.status == 'active',
            invite_managers: is_owner,
            hand_over: is_owner,
            leave: !is_owner,
            activity: is_manager,
            more_seats: is_manager
        };
    },

    // reader_team.js: one entry of the activity log as a sentence (apps/team, TeamActivity.log). Returns the
    // translated message and the values for its placeholders, which reader_team.js sets in bold. Changes staff
    // make are said to be NewsBlur staff's, whoever on staff made them.
    activity_message: function (entry, members) {
        var details = entry.details || {};
        var actor = entry.actor || gettext('Someone');
        var named = function (user_id, username) {
            if (username) return username;
            var member = _.find(members || [], function (member) { return member.user_id == user_id; });
            return member && member.username;
        };
        var plan = NEWSBLUR.ReaderTeam.plan_name(details.plan);
        var message;
        var values = { actor: actor };

        switch (entry.action) {
            case 'team_created':
                message = gettext('%(actor)s started the team as %(name)s, on %(plan)s');
                values = { actor: actor, name: details.name, plan: plan };
                break;
            case 'team_renamed':
                message = gettext('%(actor)s renamed the team from %(old_name)s to %(name)s');
                values = { actor: actor, old_name: details.old_name, name: details.name };
                break;
            case 'invite_sent':
                message = details.role == 'manager' ?
                    gettext('%(actor)s invited %(email)s as a manager') :
                    gettext('%(actor)s invited %(email)s as a member');
                values = { actor: actor, email: details.email };
                break;
            case 'invite_revoked':
                message = gettext('%(actor)s cancelled the invite to %(email)s');
                values = { actor: actor, email: details.email };
                break;
            case 'join_link_created':
                message = details.replaced ?
                    gettext('%(actor)s made a new join link and turned off the old one') :
                    gettext('%(actor)s made a join link');
                break;
            case 'join_link_revoked':
                message = gettext('%(actor)s turned off the join link');
                break;
            case 'member_joined':
                if (details.via == 'link') {
                    message = gettext('%(actor)s joined with the join link');
                } else if (details.role == 'manager') {
                    message = gettext('%(actor)s joined from an email invite, as a manager');
                } else {
                    message = gettext('%(actor)s joined from an email invite');
                }
                break;
            case 'member_left':
                message = gettext('%(actor)s left the team');
                break;
            case 'member_removed':
                message = gettext('%(actor)s removed %(username)s');
                values = { actor: actor, username: named(details.user_id, details.username) || gettext('a teammate') };
                break;
            case 'role_changed':
                message = details.role == 'manager' ?
                    gettext('%(actor)s made %(username)s a manager') :
                    gettext('%(actor)s made %(username)s a member');
                values = { actor: actor, username: named(details.user_id, details.username) || gettext('a teammate') };
                break;
            case 'transfer_requested':
                message = gettext('%(actor)s asked %(username)s to take over the team');
                values = { actor: actor, username: named(details.user_id, details.username) || gettext('a teammate') };
                break;
            case 'transfer_cancelled':
                var asked = named(details.user_id, details.username);
                message = asked ?
                    gettext('%(actor)s cancelled the request for %(username)s to take over the team') :
                    gettext('%(actor)s cancelled the request to take over the team');
                if (asked) values = { actor: actor, username: asked };
                break;
            case 'transfer_declined':
                message = gettext('%(actor)s declined to take over the team');
                break;
            case 'transfer_expired':
                var waited_for = named(details.user_id, details.username);
                message = waited_for ?
                    gettext('The request for %(username)s to take over the team ran out') :
                    gettext('The request to take over the team ran out');
                values = waited_for ? { username: waited_for } : {};
                break;
            case 'ownership_transferred':
                message = gettext('%(actor)s handed the team over to %(username)s');
                values = { actor: actor, username: named(details.user_id, details.username) || gettext('a teammate') };
                break;
            case 'seat_limit_changed':
                message = details.seat_limit < details.old_seat_limit ?
                    gettext('The seat limit was lowered to %(seat_limit)s by NewsBlur staff') :
                    gettext('The seat limit was raised to %(seat_limit)s by NewsBlur staff');
                values = { seat_limit: details.seat_limit };
                break;
            case 'plan_changed':
                message = gettext('The team was moved to %(plan)s by NewsBlur staff');
                values = { plan: plan };
                break;
            case 'comp_started':
                message = gettext('NewsBlur staff made the team\'s %(plan)s plan free');
                values = { plan: plan };
                break;
            case 'comp_ended':
                message = gettext('NewsBlur staff ended the team\'s free plan');
                values = {};
                break;
            case 'team_deactivated':
                message = gettext('The team\'s plan ended, and everyone went back to their own plan');
                values = {};
                break;
            case 'team_activated':
                message = gettext('The team\'s plan started again');
                values = {};
                break;
            case 'more_seats_requested':
                message = ngettext('%(actor)s asked NewsBlur for a team of %(count)s seat',
                    '%(actor)s asked NewsBlur for a team of %(count)s seats', details.seats);
                values = { actor: actor, count: details.seats };
                break;
            default:
                message = entry.actor ? gettext('%(actor)s changed the team') : gettext('The team was changed');
                values = entry.actor ? { actor: actor } : {};
        }
        return { message: message, values: values };
    },

    // reader_team.js: what the Billing tab shows. The owner sees who bills the team and can change the plan
    // where the web sells it. A store's plan is changed in that store, a comp has nothing to pay, and a team
    // whose plan ended can be bought again on the web whoever billed it before (apps/team/stripe_billing.py
    // team_purchase_refusal). Everyone else sees who owns the team and its plan.
    billing_state: function (team) {
        var owner = NEWSBLUR.ReaderTeam.owner_of(team);
        var state = {
            plan: team.plan,
            ended: team.status != 'active',
            owner: owner && owner.username,
            actions: []
        };
        var billing = team.billing;
        if (team.role != 'owner' || !billing) {
            state.kind = 'teammate';
            return state;
        }
        state.kind = 'owner';
        state.provider = billing.comped ? 'comp' : billing.provider;
        state.store = _.contains(['app_store', 'play'], state.provider);
        state.paid_through = billing.comped ? null : NEWSBLUR.ReaderTeam.parse_date(billing.paid_through);
        state.monthly_price = billing.monthly_price;
        if (billing.pending_plan && !state.ended) {
            state.pending = {
                plan: billing.pending_plan,
                ends_team: !_.contains(['team', 'team_enterprise'], billing.pending_plan)
            };
        }
        if (state.ended) {
            state.actions = ['renew'];
        } else if (state.provider == 'stripe') {
            state.actions = ['change_plan', 'manage_stripe'];
        } else if (state.provider == 'paypal') {
            state.actions = ['change_plan', 'manage_paypal'];
        } else if (!state.store && state.provider != 'comp') {
            state.actions = ['change_plan'];
        }
        return state;
    },

    // reader_team.js: why the server sent someone back from buying a team plan (apps/profile/views.py
    // _team_purchase_refused, apps/team/stripe_billing.py team_purchase_refusal), or null for a reason it
    // doesn't give.
    purchase_refusal_message: function (reason) {
        var messages = {
            on_team: gettext('You can only be on one team at a time, so leave your current team before you start one.'),
            team_billed_elsewhere: gettext('Your team is already paid for another way, so change its plan where you pay for it.'),
            team_comped: gettext('This team\'s plan is free, so accept the request to take it over instead of buying it.')
        };
        return messages[reason] || null;
    }

});

// ==========
// = Dialog =
// ==========

_.extend(NEWSBLUR.ReaderTeam.prototype, NEWSBLUR.SettingsDialog, {

    runner: function () {
        this.options.onOpen = _.bind(function () {
            this.resize_modal();
            this.focus_name_prompt();
        }, this);
        this.make_modal();
        this.bind_events();
        this.open_modal();
        this.load_team();
    },

    // reader_team.js: every tab the dialog can show, in order. A tab with roles shows to those roles only.
    tabs: function () {
        return [
            { name: 'members', title: gettext('Members'), make: this.make_members_tab },
            { name: 'activity', title: gettext('Activity'), make: this.make_activity_tab, roles: ['owner', 'manager'] },
            { name: 'billing', title: gettext('Billing'), make: this.make_billing_tab }
        ];
    },

    visible_tabs: function () {
        var role = this.team.role;
        return _.filter(this.tabs(), function (tab) {
            return !tab.roles || _.contains(tab.roles, role);
        });
    },

    make_modal: function () {
        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal-team NB-modal' }, [
            this.make_tabs([], null),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                gettext('Team')
            ]),
            $.make('div', { className: 'NB-team-body' }, [
                $.make('div', { className: 'NB-tab NB-active NB-team-loading' }, [
                    $.make('div', { className: 'NB-modal-loading NB-active' })
                ])
            ])
        ]);
    },

    load_team: function () {
        this.load_error = null;
        this.model.fetch_team(_.bind(function (data) {
            this.loaded = true;
            this.team = data.team;
            this.render();
            this.animate_sections($('.NB-tab.NB-active', this.$modal));
            this.focus_name_prompt();
        }, this), _.bind(function (data) {
            this.load_error = this.failure_message(data);
            this.render();
        }, this));
    },

    // reader_team.js: the name prompt takes the cursor once both the team and the open dialog are there,
    // whichever comes last.
    focus_name_prompt: function () {
        var $input = $('.NB-team-name-prompt input', this.$modal);
        if ($input.length && $input.is(':visible') && !this.prompt_focused) {
            this.prompt_focused = true;
            $input.focus().select();
        }
    },

    // ===========
    // = Drawing =
    // ===========

    // reader_team.js: the whole dialog is drawn again from this.team and the dialog's own state after every
    // change, keeping the open tab, where it was scrolled to and anything typed and not yet sent.
    render: function () {
        if (this.closed) return;
        this.rendering = true;
        // reader_team.js: what a tooltip (reader_utils.js show_tip) points at may not survive the redraw.
        NEWSBLUR.utils.hide_tip();
        var $body = $('.NB-team-body', this.$modal);
        var $old_tab = $('.NB-tab.NB-active', $body);
        var scroll_top = $old_tab.scrollTop();
        var tab_height = $old_tab.length && !$old_tab.hasClass('NB-team-loading') ? $old_tab[0].style.height : '';
        this.capture_drafts();

        var $strip = $('.NB-modal-tabs', this.$modal);
        $strip.children('.NB-modal-tab').remove();
        var $tabs;
        if (!this.loaded) {
            $tabs = [this.make_tab('error', this.make_load_error(), true)];
            this.$modal.addClass('NB-team-single');
        } else if (!this.team) {
            $tabs = [this.make_tab('none', this.make_none_tab(), true)];
            this.$modal.addClass('NB-team-single');
        } else {
            this.$modal.removeClass('NB-team-single');
            var tabs = this.visible_tabs();
            var active_tab = this.active_tab;
            if (!_.find(tabs, function (tab) { return tab.name == active_tab; })) this.active_tab = tabs[0].name;
            _.each(tabs, function (tab) {
                $strip.append($.make('div', {
                    className: 'NB-modal-tab NB-modal-tab-' + tab.name + (tab.name == this.active_tab ? ' NB-active' : ''),
                    role: 'tab',
                    tabindex: '0',
                    'data-tab': tab.name
                }, tab.title));
            }, this);
            $tabs = _.map(tabs, function (tab) {
                return this.make_tab(tab.name, tab.make.call(this), tab.name == this.active_tab);
            }, this);
        }
        $body.empty().append($tabs);

        var $new_tab = $('.NB-tab.NB-active', $body);
        if (tab_height) $('.NB-tab', $body).css('height', tab_height);
        $new_tab.scrollTop(scroll_top);
        this.restore_drafts();
        this.rendering = false;
        this.resize();
    },

    capture_drafts: function () {
        $('[data-draft]', this.$modal).each(_.bind(function (i, field) {
            this.drafts[$(field).attr('data-draft')] = $(field).val();
        }, this));
    },

    restore_drafts: function () {
        $('[data-draft]', this.$modal).each(_.bind(function (i, field) {
            var name = $(field).attr('data-draft');
            if (_.has(this.drafts, name) && this.drafts[name] !== null) $(field).val(this.drafts[name]);
        }, this));
    },

    make_load_error: function () {
        if (!this.load_error) return [];
        return [
            this.make_notice('error', [
                $.make('div', { className: 'NB-team-notice-text' }).text(this.load_error),
                $.make('div', { className: 'NB-team-notice-buttons' }, [
                    this.make_button('NB-team-retry', gettext('Try again'))
                ])
            ])
        ];
    },

    // reader_team.js: a callout above the groups, for what the reader has to know before anything else.
    make_notice: function (kind, children) {
        return $.make('div', { className: 'NB-team-notice NB-team-notice-' + kind, role: kind == 'error' ? 'alert' : 'status' }, children);
    },

    make_button: function (class_name, label, options) {
        options = options || {};
        return $.make('button', {
            type: 'button',
            className: 'NB-modal-submit-button NB-modal-submit-' + (options.color || 'grey') + ' ' + class_name,
            disabled: !!options.disabled
        }, label);
    },

    make_link_button: function (class_name, label, tip) {
        var attrs = { type: 'button', className: 'NB-team-link-button ' + class_name };
        if (tip) attrs['data-tip'] = tip;
        return $.make('button', attrs, label);
    },

    make_error: function (key) {
        if (!this.errors[key]) return null;
        return $.make('div', { className: 'NB-preference-error NB-team-error', role: 'alert' }).text(this.errors[key]);
    },

    // reader_team.js: a name, address or team name someone typed goes in as text, never as markup, and finds its
    // own direction in a page of the other direction.
    make_text: function (class_name, text) {
        return $.make('span', { className: class_name, dir: 'auto' }).text(text);
    },

    make_value: function (value, detail) {
        return $.make('div', { className: 'NB-team-value' }, _.compact([
            $.make('div', { className: 'NB-team-value-main' }, value),
            detail && $.make('div', { className: 'NB-team-value-detail' }, detail)
        ]));
    },

    // reader_team.js: a translated sentence with names in it, the names in bold and kept as text.
    make_sentence: function (message, values, bold) {
        var nodes = {};
        _.each(values, function (value, key) {
            nodes[key] = _.contains(bold || [], key) ? $.make('b', { dir: 'auto' }).text(String(value))[0] : String(value);
        });
        return NEWSBLUR.utils.interpolate_nodes(message, nodes);
    },

    format_day: function (date) {
        if (!date) return '';
        var language = document.documentElement.lang || 'en';
        return date.toLocaleDateString(language + '-u-nu-latn', { month: 'long', day: 'numeric', year: 'numeric' });
    },

    format_moment: function (date) {
        if (!date) return '';
        var language = document.documentElement.lang || 'en';
        var options = { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' };
        if (date.getFullYear() != new Date().getFullYear()) options.year = 'numeric';
        return date.toLocaleString(language + '-u-nu-latn', options);
    },

    format_price: function (price) {
        return interpolate(gettext('$%(price)s a month'), { price: price }, true);
    },

    make_avatar: function (member) {
        var initial = (member.username || '?').charAt(0).toUpperCase();
        var hue = _.reduce((member.username || '').split(''), function (sum, letter) {
            return (sum * 31 + letter.charCodeAt(0)) % 360;
        }, 0);
        var $initial = $.make('div', { className: 'NB-team-avatar NB-team-avatar-initial', style: '--nb-avatar-hue: ' + hue, 'aria-hidden': 'true' }).text(initial);
        if (!member.photo_url) return $initial;
        // reader_team.js: a photo that fails to load gives way to the initial.
        return $.make('img', { className: 'NB-team-avatar', src: member.photo_url, alt: '' }).on('error', function () {
            $(this).replaceWith($initial);
        });
    },

    // ================
    // = Members tab  =
    // ================

    make_members_tab: function () {
        var team = this.team;
        var sections = NEWSBLUR.ReaderTeam.team_sections(team);
        return [
            this.make_purchase_notice(),
            this.make_ended_notice(),
            this.make_transfer_request(),
            sections.rename && team.name_needs_confirming && this.make_name_prompt(),
            this.make_team_group(sections),
            this.make_teammates_group(),
            sections.invite && this.make_invite_group(),
            sections.hand_over && this.make_hand_over_group(),
            sections.leave && this.make_leave_group()
        ];
    },

    make_purchase_notice: function () {
        if (!this.notice) return null;
        return this.make_notice('warning', [$.make('div', { className: 'NB-team-notice-text' }).text(this.notice)]);
    },

    make_ended_notice: function () {
        var team = this.team;
        if (team.status == 'active') return null;
        var state = NEWSBLUR.ReaderTeam.billing_state(team);
        var text;
        if (state.kind == 'owner') {
            text = state.paid_through ?
                interpolate(gettext('The team\'s plan ended on %(date)s, so everyone on it is back on their own plan. Paying for it again brings the team straight back.'), { date: this.format_day(state.paid_through) }, true) :
                gettext('The team\'s plan has ended, so everyone on it is back on their own plan. Paying for it again brings the team straight back.');
        } else {
            text = interpolate(gettext('The team\'s plan has ended, so everyone on it is back on their own plan. When %(owner)s pays for it again, the team comes straight back.'), { owner: state.owner }, true);
        }
        return this.make_notice('warning', _.compact([
            $.make('div', { className: 'NB-team-notice-text' }).text(text),
            state.kind == 'owner' && $.make('div', { className: 'NB-team-notice-buttons' }, [
                this.make_button('NB-team-open-upgrade', gettext('Renew the plan'), { color: 'green' })
            ])
        ]));
    },

    // reader_team.js: the teammate the owner asked to take the team over sees the request first, with what
    // taking it over costs (Team.transfer_canonical).
    make_transfer_request: function () {
        var transfer = this.team.transfer;
        if (!transfer || !transfer.is_pending_owner) return null;
        var owner = NEWSBLUR.ReaderTeam.owner_of(this.team);
        var owner_name = owner ? owner.username : gettext('The owner');
        var values = {
            owner: owner_name,
            team: this.team.name,
            plan: NEWSBLUR.ReaderTeam.plan_name(transfer.plan),
            price: transfer.monthly_price,
            date: this.format_day(NEWSBLUR.ReaderTeam.parse_date(transfer.expire_date))
        };
        var comped = !transfer.monthly_price;
        var text = comped ?
            gettext('NewsBlur comps this team\'s %(plan)s plan, so there is nothing to pay, and %(owner)s stays on as a manager. This request runs out on %(date)s.') :
            gettext('From then on you pay for the team\'s plan, %(plan)s at $%(price)s a month, and %(owner)s stays on as a manager. This request runs out on %(date)s.');
        return this.make_notice('accent NB-team-transfer-request', _.compact([
            $.make('div', { className: 'NB-team-notice-title' }, this.make_sentence(
                gettext('%(owner)s asked you to take over %(team)s'), values, ['owner', 'team'])),
            $.make('div', { className: 'NB-team-notice-text' }, this.make_sentence(text, values, ['owner'])),
            $.make('div', { className: 'NB-team-notice-buttons' }, [
                this.make_button('NB-team-transfer-accept', comped ? gettext('Accept') : gettext('Accept and pay'), {
                    color: 'green', disabled: this.busy.transfer
                }),
                this.make_button('NB-team-transfer-decline', gettext('Decline'), { disabled: this.busy.transfer })
            ]),
            this.make_error('transfer')
        ]));
    },

    make_name_input: function (class_name) {
        return $.make('input', {
            type: 'text',
            className: 'NB-team-input NB-team-name-input ' + (class_name || ''),
            maxlength: 100,
            dir: 'auto',
            'data-draft': 'team_name',
            'aria-label': gettext('Team name'),
            value: this.team.name
        });
    },

    // reader_team.js: a team bought from a store or the web starts with its owner's name on it
    // (apps/team/billing.py), and the first thing its owner is asked is the name they want.
    make_name_prompt: function () {
        return $.make('div', { className: 'NB-preference-group NB-team-name-prompt' }, [
            $.make('div', { className: 'NB-preference-group-title' }, gettext('Name your team')),
            $.make('div', { className: 'NB-preference-group-rows' }, [
                this.make_row('NB-team-name', gettext('Team name'),
                    gettext('Your team is named after you until you pick a name. Teammates and everyone you invite see it.'), [
                        $.make('div', { className: 'NB-team-inline' }, [
                            this.make_name_input(),
                            this.make_button('NB-team-save-name', this.busy.name ? gettext('Saving...') : gettext('Save name'), {
                                color: 'green', disabled: this.busy.name
                            })
                        ]),
                        this.make_error('name')
                    ])
            ])
        ]);
    },

    make_team_group: function (sections) {
        var team = this.team;
        var open_seats = Math.max(0, team.seat_limit - team.seats_used);
        var rows = [];

        if (!(sections.rename && team.name_needs_confirming)) {
            rows.push(this.make_row('NB-team-name', gettext('Name'), sections.rename ? gettext('Press Enter to save') : null, sections.rename ? [
                this.make_name_input(),
                this.make_error('name')
            ] : this.make_value(this.make_text('NB-team-name-text', team.name))));
        }
        rows.push(this.make_row('NB-team-seats', gettext('Seats'),
            open_seats ? interpolate(ngettext('%(count)s seat is open', '%(count)s seats are open', open_seats), { count: open_seats }, true) :
                gettext('Every seat is taken'), [
                $.make('div', { className: 'NB-team-seats-count' },
                    interpolate(ngettext('%(used)s of %(count)s seat used', '%(used)s of %(count)s seats used', team.seat_limit), {
                        used: team.seats_used, count: team.seat_limit
                    }, true)),
                this.make_seats_meter(team.seats_used, team.seat_limit)
            ]));
        if (sections.more_seats) rows.push(this.make_more_seats_row());
        return this.make_group(gettext('Team'), rows);
    },

    make_seats_meter: function (used, limit) {
        if (limit > 20) {
            return $.make('div', { className: 'NB-team-seats-bar', 'aria-hidden': 'true' }, [
                $.make('div', { className: 'NB-team-seats-bar-fill', style: 'width: ' + Math.min(100, Math.round(used / limit * 100)) + '%' })
            ]);
        }
        return $.make('div', { className: 'NB-team-seats-meter', 'aria-hidden': 'true' }, _.map(_.range(limit), function (i) {
            return $.make('span', { className: 'NB-team-seat' + (i < used ? ' NB-taken' : '') });
        }));
    },

    // reader_team.js: "More than 10 teammates? Get in touch" is a short form that emails staff
    // (apps/team/views.py contact).
    make_more_seats_row: function () {
        var bigger = this.team && this.team.seat_limit > 10;
        var title = bigger ? gettext('Need more seats?') : gettext('More than 10 teammates?');
        var hint = gettext('Say how many seats you need and you\'ll get a reply by email.');
        var controls;
        if (this.contact.sent) {
            controls = $.make('div', { className: 'NB-team-text NB-team-sent' }).text(this.contact.sent);
        } else if (!this.contact.open) {
            controls = this.make_button('NB-team-contact-open', gettext('Get in touch'));
        } else {
            controls = $.make('div', { className: 'NB-team-form' }, _.compact([
                $.make('label', { className: 'NB-team-field' }, [
                    $.make('span', { className: 'NB-team-field-label' }, gettext('Team name')),
                    $.make('input', { type: 'text', className: 'NB-team-input', name: 'team_name', maxlength: 100, dir: 'auto', 'data-draft': 'contact_name', value: this.team ? this.team.name : '' })
                ]),
                $.make('label', { className: 'NB-team-field NB-team-field-short' }, [
                    $.make('span', { className: 'NB-team-field-label' }, gettext('Seats wanted')),
                    $.make('input', { type: 'number', className: 'NB-team-input', name: 'seats', min: 11, step: 1, 'data-draft': 'contact_seats' })
                ]),
                $.make('label', { className: 'NB-team-field' }, [
                    $.make('span', { className: 'NB-team-field-label' }, gettext('Note, if you like')),
                    $.make('textarea', { className: 'NB-team-input', name: 'note', rows: 3, maxlength: 2000, dir: 'auto', 'data-draft': 'contact_note' })
                ]),
                $.make('div', { className: 'NB-team-buttons' }, [
                    this.make_button('NB-team-contact-send', this.busy.contact ? gettext('Sending...') : gettext('Send'), { color: 'green', disabled: this.busy.contact }),
                    this.make_button('NB-team-contact-cancel', gettext('Cancel'))
                ]),
                this.make_error('contact')
            ]));
        }
        return this.make_row('NB-team-more-seats', title, hint, controls);
    },

    make_teammates_group: function () {
        return this.make_group(gettext('Teammates'), _.map(this.team.members, this.make_member_row, this));
    },

    make_member_row: function (member) {
        var team = this.team;
        var controls = NEWSBLUR.ReaderTeam.seat_controls(team.role, NEWSBLUR.Globals.user_id, member);
        var role_names = { owner: gettext('Owner'), manager: gettext('Manager'), member: gettext('Member') };
        var hint = interpolate(gettext('Joined %(date)s'), {
            date: this.format_day(NEWSBLUR.ReaderTeam.parse_date(member.joined_date))
        }, true);
        var is_self = member.user_id == NEWSBLUR.Globals.user_id;
        var confirm_key = 'remove:' + member.user_id;

        var options;
        if (this.confirming == confirm_key) {
            options = this.make_confirm(
                this.make_sentence(gettext('Remove %(username)s from the team? Their account goes back to its own plan right away.'), { username: member.username }, ['username']),
                'NB-team-remove-confirm', gettext('Remove'), confirm_key, { 'data-user-id': member.user_id });
        } else {
            options = $.make('div', { className: 'NB-team-member-controls' }, _.compact([
                controls.change_role ? this.make_role_cards(member) :
                    $.make('div', { className: 'NB-team-role-text NB-team-role-' + member.role }, role_names[member.role]),
                controls.remove && this.make_button('NB-team-remove', gettext('Remove'), { disabled: this.busy[confirm_key] }).attr('data-user-id', member.user_id)
            ]));
        }

        var $row = $.make('div', { className: 'NB-preference NB-team-member' + (controls.change_role ? ' NB-team-member-editable' : '') }, [
            $.make('div', { className: 'NB-preference-label NB-team-member-label' }, [
                this.make_avatar(member),
                $.make('div', { className: 'NB-team-member-names' }, _.compact([
                    $.make('div', { className: 'NB-preference-title NB-team-member-name' }, _.compact([
                        this.make_text('NB-team-username', member.username).attr('title', member.username),
                        is_self && $.make('span', { className: 'NB-team-you' }, gettext('You'))
                    ])),
                    $.make('div', { className: 'NB-preference-sublabel' }).text(hint)
                ]))
            ]),
            $.make('div', { className: 'NB-preference-options' }, _.compact(_.flatten([
                options,
                this.make_error('role:' + member.user_id),
                this.confirming != confirm_key && this.make_error(confirm_key)
            ])))
        ]);
        return $row;
    },

    // reader_team.js: the owner sets each teammate's role with two cards, as a choice is made in Preferences.
    make_role_cards: function (member) {
        var role = this.pending_roles[member.user_id] || member.role;
        var $cards = this.make_field_cards([
            { data: { 'data-role': 'member', 'data-user-id': member.user_id }, caption: gettext('Member'), art: 'role-member', tip: gettext('Reads with the team') },
            { data: { 'data-role': 'manager', 'data-user-id': member.user_id }, caption: gettext('Manager'), art: 'role-manager', tip: gettext('Invites and removes members and sees the activity log') }
        ], 'NB-team-role-cards' + (this.busy['role:' + member.user_id] ? ' NB-busy' : ''));
        this.mark_cards($cards, 'data-role', role);
        return $cards;
    },

    mark_cards: function ($cards, attribute, value) {
        $('.NB-pref-card', $cards).each(function () {
            var active = $(this).attr(attribute) == value;
            $(this).toggleClass('NB-active', active).attr('aria-checked', active ? 'true' : 'false');
        });
    },

    // reader_team.js: what would be a browser confirm is asked in place, under the control that asked it.
    make_confirm: function (question, button_class, button_label, key, button_data) {
        return $.make('div', { className: 'NB-team-confirm', role: 'group' }, _.compact([
            $.make('div', { className: 'NB-team-confirm-question' }, question),
            $.make('div', { className: 'NB-team-buttons' }, [
                this.make_button(button_class, this.busy[key] ? gettext('Working...') : button_label, { color: 'red', disabled: this.busy[key] }).attr(button_data || {}),
                this.make_button('NB-team-confirm-cancel', gettext('Cancel'), { disabled: this.busy[key] })
            ]),
            this.make_error(key)
        ]));
    },

    make_invite_group: function () {
        var team = this.team;
        var sections = NEWSBLUR.ReaderTeam.team_sections(team);
        var full = team.seats_used >= team.seat_limit;
        var invite_controls = _.compact([
            $.make('textarea', {
                className: 'NB-team-input NB-team-invite-emails',
                rows: 3,
                dir: 'auto',
                'data-draft': 'invite_emails',
                placeholder: gettext('name@example.com'),
                'aria-label': gettext('Email addresses')
            }),
            sections.invite_managers && $.make('div', { className: 'NB-team-invite-as' }, [
                $.make('div', { className: 'NB-team-field-label' }, gettext('They join as')),
                this.make_invite_role_cards()
            ]),
            full && $.make('div', { className: 'NB-team-text NB-team-muted' }, gettext('Every seat is taken, so nobody can join until a seat opens.')),
            $.make('div', { className: 'NB-team-buttons' }, [
                this.make_button('NB-team-send-invites', this.busy.invite ? gettext('Sending...') : gettext('Send invites'), { color: 'green', disabled: this.busy.invite })
            ]),
            this.make_error('invite')
        ]);
        var rows = [
            this.make_row('NB-team-invite', gettext('Invite by email'), sections.invite_managers ?
                gettext('Put commas or new lines between addresses. Invites last 14 days.') :
                gettext('Put commas or new lines between addresses. Everyone you invite joins as a member, and invites last 14 days.'),
                invite_controls)
        ];
        if (team.invites && team.invites.length) {
            rows.push(this.make_row('NB-team-pending', gettext('Waiting to join'),
                interpolate(ngettext('%(count)s invite', '%(count)s invites', team.invites.length), { count: team.invites.length }, true),
                $.make('div', { className: 'NB-team-invites' }, _.map(team.invites, this.make_invite, this))));
        }
        rows.push(this.make_join_link_row());
        return this.make_group(gettext('Invite'), rows);
    },

    make_invite_role_cards: function () {
        var $cards = this.make_field_cards([
            { data: { 'data-invite-role': 'member' }, caption: gettext('Member'), art: 'role-member', tip: gettext('Reads with the team') },
            { data: { 'data-invite-role': 'manager' }, caption: gettext('Manager'), art: 'role-manager', tip: gettext('Invites and removes members and sees the activity log') }
        ], 'NB-team-role-cards NB-team-invite-role');
        this.mark_cards($cards, 'data-invite-role', this.invite_role);
        return $cards;
    },

    make_invite: function (invite) {
        var key = 'revoke:' + invite.id;
        var values = {
            username: invite.invited_by || gettext('someone'),
            date: this.format_day(NEWSBLUR.ReaderTeam.parse_date(invite.expire_date))
        };
        var meta = invite.role == 'manager' ?
            gettext('Manager, invited by %(username)s, until %(date)s') :
            gettext('Member, invited by %(username)s, until %(date)s');
        return $.make('div', { className: 'NB-team-invite-item' }, _.compact([
            $.make('div', { className: 'NB-team-invite-text' }, [
                this.make_text('NB-team-invite-email', invite.email).attr('title', invite.email),
                $.make('div', { className: 'NB-team-invite-meta' }).text(interpolate(meta, values, true))
            ]),
            this.make_link_button('NB-team-revoke-invite', this.busy[key] ? gettext('Cancelling...') : gettext('Cancel invite')).attr({ 'data-invite-id': invite.id, disabled: !!this.busy[key] }),
            this.make_error(key)
        ]));
    },

    make_join_link_row: function () {
        var link = this.team.join_link;
        var controls;
        if (link) {
            controls = [
                $.make('div', { className: 'NB-team-inline' }, [
                    $.make('input', { type: 'text', className: 'NB-team-input NB-team-join-url', readonly: 'readonly', dir: 'ltr', value: link.url, 'aria-label': gettext('Join link') }),
                    this.make_button('NB-team-copy-link', gettext('Copy'))
                ]),
                $.make('div', { className: 'NB-team-link-actions' }, [
                    this.make_link_button('NB-team-new-link', gettext('Make a new link'), gettext('The link above stops working')),
                    this.make_link_button('NB-team-link-off', gettext('Turn the link off'), gettext('Nobody can join with it until you make a new one'))
                ])
            ];
        } else {
            controls = [
                $.make('div', { className: 'NB-team-text NB-team-muted' }, gettext('The team has no join link right now.')),
                $.make('div', { className: 'NB-team-buttons' }, [
                    this.make_button('NB-team-new-link', gettext('Make a join link'))
                ])
            ];
        }
        return this.make_row('NB-team-join-link', gettext('Join link'),
            gettext('Anyone with the link can join, until it\'s turned off.'),
            controls.concat([this.make_error('join_link')]));
    },

    hand_over_note: function () {
        var provider = this.team.billing && (this.team.billing.comped ? 'comp' : this.team.billing.provider);
        if (provider == 'comp') {
            return gettext('The team stays comped, so they have nothing to pay, and you stay on as a manager.');
        }
        if (provider == 'stripe' || provider == 'paypal') {
            return gettext('They pay for the team\'s plan from then on, and you stay on as a manager. The unused part of your month is refunded.');
        }
        if (provider == 'app_store' || provider == 'play') {
            return gettext('They pay for the team\'s plan from then on, and you stay on as a manager. You get an email with a link to cancel your store subscription.');
        }
        return gettext('They pay for the team\'s plan from then on, and you stay on as a manager.');
    },

    make_hand_over_group: function () {
        var team = this.team;
        var transfer = team.transfer;
        var teammates = _.reject(team.members, function (member) { return member.role == 'owner'; });
        var row;
        if (transfer && !transfer.is_pending_owner) {
            row = this.make_row('NB-team-hand-over',
                this.make_sentence(gettext('Waiting for %(username)s'), { username: transfer.pending_owner }, ['username']),
                interpolate(gettext('They have until %(date)s to take over the team.'), {
                    date: this.format_day(NEWSBLUR.ReaderTeam.parse_date(transfer.expire_date))
                }, true), [
                    this.make_button('NB-team-cancel-transfer', this.busy.hand_over ? gettext('Cancelling...') : gettext('Cancel the request'), { disabled: this.busy.hand_over }),
                    this.make_error('hand_over')
                ]);
        } else if (!teammates.length) {
            row = this.make_row('NB-team-hand-over', gettext('New owner'), this.hand_over_note(),
                $.make('div', { className: 'NB-team-text NB-team-muted' }, gettext('Invite a teammate first, then you can hand the team over to them.')));
        } else {
            var hand_over_to = this.hand_over_to;
            var selected = _.find(teammates, function (member) { return member.user_id == hand_over_to; }) ? hand_over_to : teammates[0].user_id;
            this.hand_over_to = selected;
            row = this.make_row('NB-team-hand-over', gettext('New owner'), this.hand_over_note(), [
                $.make('div', { className: 'NB-team-inline' }, [
                    $.make('select', { className: 'NB-team-hand-over-to', 'aria-label': gettext('New owner') }, _.map(teammates, function (member) {
                        return $.make('option', { value: member.user_id, selected: member.user_id == selected }).text(member.username);
                    })),
                    this.make_button('NB-team-request-transfer', this.busy.hand_over ? gettext('Asking...') : gettext('Ask them to take over'), { disabled: this.busy.hand_over })
                ]),
                this.make_error('hand_over')
            ]);
        }
        return this.make_group(gettext('Hand over the team'), [row]);
    },

    make_leave_group: function () {
        var controls = this.confirming == 'leave' ?
            this.make_confirm(this.make_sentence(gettext('Leave %(team)s now?'), { team: this.team.name }, ['team']), 'NB-team-leave-confirm', gettext('Leave'), 'leave') :
            [this.make_button('NB-team-leave', gettext('Leave the team')), this.make_error('leave')];
        return this.make_group(gettext('Leave'), [
            this.make_row('NB-team-leave-row', gettext('Leave the team'),
                gettext('Your account goes back to its own plan right away. On the free plan, your sites are muted until you pick the 64 to keep.'),
                controls)
        ]);
    },

    // =================
    // = Activity tab  =
    // =================

    make_activity_tab: function () {
        var activity = this.activity;
        var rows;
        if (activity.error && !activity.entries.length) {
            rows = [$.make('div', { className: 'NB-team-activity-empty' }, [
                $.make('div', { className: 'NB-team-error', role: 'alert' }).text(activity.error),
                this.make_button('NB-team-activity-retry', gettext('Try again'))
            ])];
        } else if (!activity.entries.length) {
            rows = [$.make('div', { className: 'NB-team-activity-empty' }, activity.loading || activity.stale ?
                [$.make('div', { className: 'NB-modal-loading NB-active' })] :
                gettext('Nothing has happened on the team yet.'))];
        } else {
            rows = _.map(activity.entries, this.make_activity_entry, this);
            if (activity.has_more || activity.error) {
                rows.push($.make('div', { className: 'NB-team-activity-more' }, _.compact([
                    activity.error && $.make('div', { className: 'NB-team-error', role: 'alert' }).text(activity.error),
                    this.make_button('NB-team-activity-next', activity.loading ? gettext('Loading...') : gettext('Show more'), { disabled: activity.loading })
                ])));
            }
        }
        return [this.make_group(gettext('Activity'), rows)];
    },

    make_activity_entry: function (entry) {
        var sentence = NEWSBLUR.ReaderTeam.activity_message(entry, this.team.members);
        var date = NEWSBLUR.ReaderTeam.parse_date(entry.date);
        return $.make('div', { className: 'NB-team-activity-entry' }, [
            $.make('div', { className: 'NB-team-activity-text' },
                this.make_sentence(sentence.message, sentence.values, ['actor', 'username', 'email', 'name', 'old_name'])),
            $.make('time', { className: 'NB-team-activity-date', datetime: date ? date.toISOString() : '' }).text(this.format_moment(date))
        ]);
    },

    load_activity: function (page) {
        if (this.activity.loading) return;
        this.activity.loading = true;
        this.activity.error = null;
        if (page == 1) this.activity.stale = false;
        this.render();
        this.model.fetch_team_activity(this.team.id, page, _.bind(function (data) {
            this.activity.loading = false;
            this.activity.page = page;
            this.activity.entries = page == 1 ? data.activities : this.activity.entries.concat(data.activities);
            this.activity.has_more = data.has_more;
            this.render();
        }, this), _.bind(function (data) {
            this.activity.loading = false;
            this.activity.error = this.failure_message(data);
            this.render();
        }, this));
    },

    // ===============
    // = Billing tab =
    // ===============

    make_billing_tab: function () {
        var state = NEWSBLUR.ReaderTeam.billing_state(this.team);
        var plan_name = NEWSBLUR.ReaderTeam.plan_name(state.plan);
        if (state.kind == 'teammate') {
            var line = state.ended ?
                gettext('The team\'s plan has ended. When %(owner)s pays for it again, the team comes straight back.') :
                gettext('%(owner)s owns this team and pays for its plan.');
            return [this.make_group(gettext('Plan'), [
                this.make_row('NB-team-billing-plan', gettext('Plan'), null, this.make_value(plan_name,
                    this.make_sentence(line, { owner: state.owner || gettext('The owner') }, ['owner'])))
            ])];
        }

        var rows = [];
        var price;
        if (state.provider == 'comp') {
            price = gettext('NewsBlur comps this team, so there\'s nothing to pay.');
        } else if (state.monthly_price === null || _.isUndefined(state.monthly_price)) {
            price = interpolate(ngettext('%(count)s seat, at the price agreed with NewsBlur', '%(count)s seats, at the price agreed with NewsBlur', this.team.seat_limit), { count: this.team.seat_limit }, true);
        } else {
            price = this.format_price(state.monthly_price);
        }
        if (state.ended) {
            rows.push(this.make_row('NB-team-billing-plan', gettext('Plan'), null, this.make_value(plan_name,
                state.paid_through ? interpolate(gettext('Ended on %(date)s'), { date: this.format_day(state.paid_through) }, true) : gettext('Ended'))));
            rows.push(this.make_row('NB-team-billing-renew', gettext('Bring it back'),
                gettext('Paying for the plan again brings the team straight back, with everyone on it.'),
                this.make_button('NB-team-open-upgrade', gettext('Renew the plan'), { color: 'green' })));
            return [this.make_group(gettext('Plan'), rows)];
        }

        rows.push(this.make_row('NB-team-billing-plan', gettext('Plan'), null, this.make_value(plan_name, price)));
        if (state.provider == 'comp') return [this.make_group(gettext('Plan'), rows)];
        var providers = {
            stripe: [gettext('Card, through Stripe'), null],
            paypal: [gettext('PayPal'), null],
            app_store: [gettext('The App Store'), gettext('Change or cancel it in the App Store, in your Apple Account\'s subscriptions.')],
            play: [gettext('Google Play'), gettext('Change or cancel it in Google Play, under Payments and subscriptions.')]
        };
        var provider = providers[state.provider] || [gettext('Not billed yet'), null];
        var manage = _.contains(state.actions, 'manage_stripe') ? this.make_button('NB-team-manage-stripe', gettext('Invoices and card')) :
            _.contains(state.actions, 'manage_paypal') && this.make_button('NB-team-manage-paypal', gettext('PayPal details'));
        rows.push(this.make_row('NB-team-billing-provider', gettext('Payment'), null, _.compact([
            this.make_value(provider[0], provider[1]),
            manage && $.make('div', { className: 'NB-team-buttons' }, [manage])
        ])));
        if (state.paid_through) {
            rows.push(this.make_row('NB-team-billing-paid', gettext('Paid through'), null, this.make_value(this.format_day(state.paid_through))));
        }
        if (state.pending) {
            var change = interpolate(gettext('Moves to %(plan)s on %(date)s'), {
                plan: NEWSBLUR.ReaderTeam.plan_name(state.pending.plan),
                date: this.format_day(state.paid_through)
            }, true);
            rows.push(this.make_row('NB-team-billing-pending', gettext('Coming up'), null, this.make_value(change,
                state.pending.ends_team ? gettext('The team ends that day, and everyone on it goes back to their own plan.') : gettext('The team keeps its current plan until then.'))));
        }
        if (_.contains(state.actions, 'change_plan')) {
            rows.push(this.make_row('NB-team-billing-change', gettext('Change plan'),
                gettext('Switch between Premium Team and Premium Team Enterprise, or move to a plan of your own.'),
                this.make_button('NB-team-open-upgrade', gettext('Change plan'))));
        }
        return [this.make_group(gettext('Plan'), rows)];
    },

    // ===============
    // = No team yet =
    // ===============

    make_none_tab: function () {
        var notice = this.left_team ?
            interpolate(gettext('You left %(team)s. Your account is back on its own plan.'), { team: this.left_team }, true) :
            this.notice;
        return [
            notice && this.make_notice(this.left_team ? 'info' : 'warning', [$.make('div', { className: 'NB-team-notice-text' }).text(notice)]),
            this.make_group(gettext('Premium Team'), [
                this.make_row('NB-team-about', gettext('What a team is'), null, $.make('div', { className: 'NB-team-text' },
                    gettext('Up to 10 NewsBlur accounts on one bill. Everyone keeps their own account, with their own sites and folders.'))),
                this.make_row('NB-team-about', gettext('What everyone gets'), null, $.make('div', { className: 'NB-team-text' },
                    gettext('Premium Pro, shared by the whole team: 10,000 sites and 10 hours of Listen a week between you.'))),
                this.make_row('NB-team-about', gettext('What it costs'), null, [
                    $.make('div', { className: 'NB-team-text' },
                        gettext('$79 a month for Premium Team, or $129 a month for Premium Team Enterprise. The person who starts the team pays, and nobody else does.')),
                    $.make('div', { className: 'NB-team-buttons' }, [
                        this.make_button('NB-team-open-upgrade', gettext('Start a team'), { color: 'green' })
                    ])
                ]),
                this.make_row('NB-team-about', gettext('Joining a team?'), null, $.make('div', { className: 'NB-team-text' },
                    gettext('Open the invite email or the join link a teammate sent you.')))
            ]),
            this.make_group(gettext('Bigger teams'), [this.make_more_seats_row()])
        ];
    },

    // ===========
    // = Actions =
    // ===========

    failure_message: function (data) {
        if (data && _.isString(data.message) && data.message && !data.status_code) return data.message;
        if (data && data.responseJSON && data.responseJSON.message) return data.responseJSON.message;
        return gettext('That didn\'t go through. Check your connection and try again.');
    },

    // reader_team.js: sends one change and draws the dialog again from the team the server answers with. key
    // names the control, which shows its own error and stays disabled while its change is out. Two controls can
    // have changes out at once, and their answers can come back in either order, so only the answer to the
    // newest change is drawn, and once every change is in the team is read again (settle_changes).
    act: function (key, action, data, options) {
        options = options || {};
        if (this.busy[key]) return;
        this.busy[key] = true;
        delete this.errors[key];
        this.set_status('saving', options.saving_message);
        this.render();

        var sent = this.changes_sent = (this.changes_sent || 0) + 1;
        this.changes_out = (this.changes_out || 0) + 1;
        if (this.changes_out > 1) this.changes_overlapped = true;

        var params = _.extend(this.team ? { team_id: this.team.id } : {}, data);
        this.model.team_action(action, params, _.bind(function (response) {
            delete this.busy[key];
            this.changes_out -= 1;
            if (response && _.isNumber(response.code) && response.code < 0) {
                this.fail(key, response, options);
                this.settle_changes();
                return;
            }
            if (response && _.has(response, 'team') && sent == this.changes_sent) this.team = response.team;
            this.activity.stale = true;
            if (options.success) options.success.call(this, response);
            this.set_status('saved', options.saved_message);
            this.render();
            this.settle_changes();
        }, this), _.bind(function (response) {
            delete this.busy[key];
            this.changes_out -= 1;
            this.fail(key, response, options);
            this.settle_changes();
        }, this));
    },

    // reader_team.js: after changes that were out together, neither answer is sure to hold the other's change,
    // so the team is read once more when the last of them is in. A failed read leaves the dialog as it is.
    settle_changes: function () {
        if (this.changes_out || !this.changes_overlapped) return;
        this.changes_overlapped = false;
        var read = this.changes_sent;
        this.model.fetch_team(_.bind(function (data) {
            if (read != this.changes_sent || this.changes_out) return;
            this.team = data.team;
            this.render();
        }, this), function () {});
    },

    // reader_team.js: render() reads every draft back out of its field, so a draft that was sent is let go at
    // the field. When sent is given, the draft is kept if the field no longer holds it: what was typed while
    // the change was out stays.
    forget_draft: function (name, sent) {
        var $field = $('[data-draft="' + name + '"]', this.$modal);
        if ($field.length && !_.isUndefined(sent) && $.trim($field.val()) != sent) return;
        $field.removeAttr('data-draft');
        delete this.drafts[name];
    },

    fail: function (key, response, options) {
        var message = this.failure_message(response);
        if (response && response.invalid_emails && response.invalid_emails.length) {
            message = interpolate(gettext('%(message)s These don\'t look like addresses: %(emails)s'), {
                message: message, emails: response.invalid_emails.join(', ')
            }, true);
        }
        this.errors[key] = message;
        if (options.failure) options.failure.call(this, response);
        this.set_status('error');
        this.render();
    },

    save_name: function (force) {
        var $input = $('.NB-team-name-input', this.$modal);
        if (!$input.length || !this.team) return;
        var name = $.trim($input.val());
        if (!force && name == this.team.name) {
            delete this.errors.name;
            return;
        }
        if (!name) {
            this.errors.name = gettext('Give the team a name.');
            this.set_status('error');
            this.render();
            return;
        }
        this.act('name', 'rename', { name: name }, {
            success: function () { this.drafts.team_name = null; }
        });
    },

    change_role: function (user_id, role) {
        var member = _.find(this.team.members, function (member) { return member.user_id == user_id; });
        if (!member || member.role == role) return;
        var key = 'role:' + user_id;
        this.pending_roles[user_id] = role;
        this.act(key, 'change_role', { user_id: user_id, role: role }, {
            success: function () { delete this.pending_roles[user_id]; },
            failure: function () { delete this.pending_roles[user_id]; }
        });
    },

    send_invites: function () {
        var emails = $.trim($('.NB-team-invite-emails', this.$modal).val());
        if (!emails) {
            this.errors.invite = gettext('Add at least one email address.');
            this.render();
            $('.NB-team-invite-emails', this.$modal).focus();
            return;
        }
        var count = _.compact(emails.split(/[\s,;]+/)).length;
        var role = NEWSBLUR.ReaderTeam.team_sections(this.team).invite_managers ? this.invite_role : 'member';
        this.act('invite', 'invite', { emails: emails, role: role }, {
            saving_message: gettext('Sending...'),
            saved_message: ngettext('Invite sent', 'Invites sent', count),
            success: function () { this.forget_draft('invite_emails', emails); }
        });
    },

    send_contact: function () {
        var $form = $('.NB-team-form', this.$modal);
        this.act('contact', 'contact', {
            team_name: $('input[name=team_name]', $form).val(),
            seats: $('input[name=seats]', $form).val(),
            note: $('textarea[name=note]', $form).val()
        }, {
            saving_message: gettext('Sending...'),
            saved_message: gettext('Sent'),
            success: function (response) {
                this.contact = { open: false, sent: response.message };
                _.each(['contact_name', 'contact_seats', 'contact_note'], function (name) { this.forget_draft(name); }, this);
            }
        });
    },

    leave_team: function () {
        var name = this.team.name;
        this.act('leave', 'leave', {}, {
            saved_message: gettext('You left the team'),
            success: function () {
                this.team = null;
                this.confirming = null;
                this.left_team = name;
                // reader_team.js: the account's plan changed under the reader, which loads again as the
                // dialog closes to show it.
                this.reload_on_close = true;
            }
        });
    },

    accept_transfer: function () {
        var transfer = this.team.transfer;
        if (transfer && transfer.monthly_price) {
            this.open_upgrade();
            return;
        }
        this.act('transfer', 'accept_transfer', {}, { saved_message: gettext('The team is yours') });
    },

    // reader_team.js: plans are bought and switched in the upgrade dialog (reader_premium_upgrade.js).
    open_upgrade: function () {
        this.close(function () {
            NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: 'team' });
        });
    },

    copy_join_link: function () {
        var $input = $('.NB-team-join-url', this.$modal);
        var copied = _.bind(function () { this.set_status('saved', gettext('Link copied')); }, this);
        var select_and_copy = _.bind(function () {
            $input.focus().select();
            var worked = false;
            try {
                worked = document.execCommand('copy');
            } catch (e) {
                worked = false;
            }
            if (worked) {
                copied();
            } else {
                this.set_status('error', gettext('Select the link and copy it'));
            }
        }, this);
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText($input.val()).then(copied, select_and_copy);
        } else {
            select_and_copy();
        }
    },

    switch_to_tab: function (name) {
        this.active_tab = name;
        NEWSBLUR.utils.hide_tip();
        this.switch_tab(name);
        if (name == 'activity' && this.activity.stale) this.load_activity(1);
        this.resize_modal();
    },

    bind_events: function () {
        var self = this;
        var on = function (selector, handler) {
            self.$modal.on('click', selector, function (e) {
                e.preventDefault();
                if ($(this).is(':disabled')) return;
                handler.call(self, $(this), e);
            });
        };

        on('.NB-modal-tab', function ($tab) { this.switch_to_tab($tab.attr('data-tab')); });
        on('.NB-team-retry', function () {
            $('.NB-team-body', this.$modal).html($.make('div', { className: 'NB-tab NB-active NB-team-loading' }, [
                $.make('div', { className: 'NB-modal-loading NB-active' })
            ]));
            this.load_team();
        });
        on('.NB-team-save-name', function () { this.save_name(true); });
        on('.NB-team-role-cards:not(.NB-team-invite-role) .NB-pref-field-card', function ($card) {
            this.change_role(parseInt($card.attr('data-user-id'), 10), $card.attr('data-role'));
        });
        on('.NB-team-invite-role .NB-pref-field-card', function ($card) {
            this.invite_role = $card.attr('data-invite-role');
            this.mark_cards($card.closest('.NB-pref-cards'), 'data-invite-role', this.invite_role);
        });
        on('.NB-team-remove', function ($button) {
            this.confirming = 'remove:' + $button.attr('data-user-id');
            this.render();
            $('.NB-team-remove-confirm', this.$modal).focus();
        });
        on('.NB-team-remove-confirm', function ($button) {
            var user_id = parseInt($button.attr('data-user-id'), 10);
            this.act('remove:' + user_id, 'remove_member', { user_id: user_id }, {
                success: function () { this.confirming = null; }
            });
        });
        on('.NB-team-confirm-cancel', function () {
            this.confirming = null;
            this.render();
        });
        on('.NB-team-leave', function () {
            this.confirming = 'leave';
            this.render();
            $('.NB-team-leave-confirm', this.$modal).focus();
        });
        on('.NB-team-leave-confirm', function () { this.leave_team(); });
        on('.NB-team-send-invites', function () { this.send_invites(); });
        on('.NB-team-revoke-invite', function ($button) {
            var invite_id = parseInt($button.attr('data-invite-id'), 10);
            this.act('revoke:' + invite_id, 'revoke_invite', { invite_id: invite_id });
        });
        on('.NB-team-copy-link', function () { this.copy_join_link(); });
        on('.NB-team-new-link', function () { this.act('join_link', 'join_link', {}); });
        on('.NB-team-link-off', function () { this.act('join_link', 'revoke_join_link', {}); });
        on('.NB-team-contact-open', function () {
            this.contact = { open: true, sent: null };
            this.render();
            $('.NB-team-form input[name=seats]', this.$modal).focus();
        });
        on('.NB-team-contact-cancel', function () {
            this.contact = { open: false, sent: null };
            delete this.errors.contact;
            this.render();
        });
        on('.NB-team-contact-send', function () { this.send_contact(); });
        on('.NB-team-request-transfer', function () {
            this.act('hand_over', 'transfer_ownership', { user_id: this.hand_over_to }, { saved_message: gettext('Request sent') });
        });
        on('.NB-team-cancel-transfer', function () { this.act('hand_over', 'cancel_transfer', {}); });
        on('.NB-team-transfer-accept', function () { this.accept_transfer(); });
        on('.NB-team-transfer-decline', function () { this.act('transfer', 'decline_transfer', {}); });
        on('.NB-team-open-upgrade', function () { this.open_upgrade(); });
        on('.NB-team-manage-stripe', function ($button) {
            $button.prop('disabled', true).text(gettext('Opening Stripe...'));
            $.redirectPost('/profile/switch_stripe_subscription', { plan: 'change_stripe' });
        });
        on('.NB-team-manage-paypal', function ($button) {
            $button.prop('disabled', true).text(gettext('Opening PayPal...'));
            $.redirectPost('/profile/switch_paypal_subscription', { plan: 'change_paypal' });
        });
        on('.NB-team-activity-next', function () { this.load_activity(this.activity.page + 1); });
        on('.NB-team-activity-retry', function () { this.load_activity(1); });

        this.$modal.on('change', '.NB-team-hand-over-to', function () {
            self.hand_over_to = parseInt($(this).val(), 10);
        });
        // reader_team.js: the owner's name for the team is saved on Enter or when the field loses focus, and
        // Escape puts the saved name back.
        this.$modal.on('keydown', '.NB-team-name-input', function (e) {
            if (e.which == 13) {
                e.preventDefault();
                self.save_name($(this).closest('.NB-team-name-prompt').length > 0);
            } else if (e.which == 27) {
                e.preventDefault();
                e.stopPropagation();
                $(this).val(self.team.name);
                self.drafts.team_name = null;
                $(this).blur();
            }
        });
        this.$modal.on('blur', '.NB-team-name-input', function () {
            if (!self.rendering) self.save_name(false);
        });
        // reader_team.js: field cards and tabs are not form fields, so they get the keys a radio button has.
        this.$modal.on('keydown', '.NB-pref-field-card, .NB-modal-tab', function (e) {
            if (e.which == 13 || e.which == 32) {
                e.preventDefault();
                $(this).click();
            }
        });
        // reader_team.js: a card's tooltip (reader_utils.js show_tip) would be left behind when the tab
        // scrolls its card away.
        this.$modal.on('scroll', '.NB-tab', function () {
            NEWSBLUR.utils.hide_tip();
        });
    },

    // reader_team.js: common/modal.js calls this as the dialog closes, while its fields can still be read, so a
    // new team name typed a moment before closing is saved too.
    handle_modal_closed: function () {
        this.closed = true;
        if (this.team && NEWSBLUR.ReaderTeam.team_sections(this.team).rename && !this.team.name_needs_confirming) {
            this.save_name(false);
        }
        NEWSBLUR.utils.hide_tip();
        if (this.reload_on_close) {
            _.delay(function () { window.location.reload(); }, 250);
        }
    }

});
