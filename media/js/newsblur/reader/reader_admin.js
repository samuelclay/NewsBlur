NEWSBLUR.ReaderUserAdmin = function (options) {
    var defaults = {
        width: 700
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.user = this.options.user;
    this.runner();
};

NEWSBLUR.ReaderUserAdmin.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderUserAdmin.prototype.constructor = NEWSBLUR.ReaderUserAdmin;

_.extend(NEWSBLUR.ReaderUserAdmin.prototype, {

    runner: function () {
        this.make_modal();
        this.open_modal();
        this.fetch_payment_history();
        this.fetch_listen_usage();
        this.fetch_team();


        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-admin NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                gettext('User Admin')
            ]),
            new NEWSBLUR.Views.SocialProfileBadge({
                model: this.user
            }),
            $.make('fieldset', [
                $.make('legend', gettext('Statistics'))
            ]),
            $.make('div', { className: 'NB-admin-statistics' }),
            $.make('fieldset', [
                $.make('legend', gettext('Payments'))
            ]),
            $.make('ul', { className: 'NB-account-payments' }, [
                $.make('li', { className: 'NB-payments-loading' }, gettext('Loading...'))
            ]),
            $.make('fieldset', [
                $.make('legend', gettext('Listen'))
            ]),
            $.make('div', { className: 'NB-admin-listen' }, gettext('Loading...')),
            $.make('fieldset', [
                $.make('legend', gettext('Team'))
            ]),
            $.make('div', { className: 'NB-admin-team' }, gettext('Loading...')),
            $.make('fieldset', [
                $.make('legend', gettext('Actions'))
            ]),
            $.make('div', { className: 'NB-admin-actions' }, [
            ])
        ]);
    },

    // ============
    // = Payments =
    // ============

    fetch_payment_history: function () {
        this.model.fetch_payment_history(this.user.get('user_id'), _.bind(function (data) {
            var $history = $('.NB-account-payments', this.$modal).empty();
            var $actions = $(".NB-admin-actions", this.$modal).empty();
            var $statistics = $(".NB-admin-statistics", this.$modal).empty();

            _.each(data.payments, function (payment) {
                $history.append($.make('li', { className: 'NB-account-payment' }, [
                    $.make('div', { className: 'NB-account-payment-date' }, payment.payment_date),
                    $.make('div', { className: 'NB-account-payment-amount' }, "$" + payment.payment_amount),
                    $.make('div', { className: 'NB-account-payment-provider' }, payment.payment_provider)
                ]));
            });
            if (!data.payments.length) {
                $history.append($.make('i', gettext('No payments found.')));
            }

            if (data.is_premium) {
                $actions.append($.make('div', { style: 'margin-bottom: 12px' }, [
                    (data.is_premium && !data.is_archive && gettext("User is premium, expires: ")),
                    (data.is_premium && data.is_archive && gettext("User is premium ARCHIVE, expires: ")),
                    (data.premium_expire || $.make('b', gettext('NEVER')))
                ]));
                $actions.append($.make('div', { style: 'margin-bottom: 12px' }, [
                    gettext("Premium renewal: "),
                    (data.premium_renewal ? $.make('b', gettext('Active')) : gettext("Off"))
                ]));
                $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-refund", style: "float: left" }, gettext("Full Refund")));
                $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-refund-partial", style: "float: left" }, gettext("Refund $12")));
                $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-never-expire", style: "float: left" }, gettext("Never expire")));
                $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-1yr-expire", style: "float: left" }, gettext("Expire 1 YR")));
            } else {
                $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-upgrade" }, gettext("Upgrade to premium")));
            }

            $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-history", style: "float: left" }, gettext("Update History")));
            $actions.append($.make('div', { className: "NB-modal-submit-button NB-modal-submit-green NB-admin-action-opml", style: "float: left" }, "OPML"));

            var training = data.statistics.training;
            $statistics.append($.make('dl', [
                $.make('dt', gettext('Created:')),
                $.make('dd', data.statistics.created_date),
                $.make('dt', gettext('Last seen:')),
                $.make('dd', data.statistics.last_seen_date),
                $.make('dt', gettext('Last IP:')),
                $.make('dd', data.statistics.last_seen_ip),
                $.make('dt', gettext('Timezone:')),
                $.make('dd', data.statistics.timezone),
                $.make('dt', gettext('Email:')),
                $.make('dd', data.statistics.email),
                $.make('dt', gettext('Stripe Id:')),
                $.make('dd', $.make('a', { href: "https://manage.stripe.com/customers/" + data.statistics.stripe_id, className: 'NB-splash-link' }, data.statistics.stripe_id)),
                $.make('dt', gettext('Paypal email:')),
                $.make('dd', $.make('a', { href: "https://www.paypal.com/businessexp/transactions?nav=0.3.1&payer_email=" + data.statistics.paypal_email, className: 'NB-splash-link' }, data.statistics.paypal_email)),
                $.make('dt', gettext('Feeds:')),
                $.make('dd', Inflector.commas(data.statistics.feeds)),
                $.make('dt', gettext('Feed opens:')),
                $.make('dd', Inflector.commas(data.statistics.feed_opens)),
                $.make('dt', gettext('Read Stories:')),
                $.make('dd', Inflector.commas(data.statistics.read_story_count)),
                $.make('dt', gettext('Training:')),
                $.make('dd', { className: 'NB-admin-training-counts' }, [
                    $.make('span', { className: training.title_ps || training.title_ng ? '' : 'NB-grey' }, [
                        gettext('Title: '),
                        (training.title_ps && $.make('span', { className: 'NB-green' }, training.title_ps)),
                        '-',
                        (training.title_ng && $.make('span', { className: 'NB-red' }, training.title_ng))
                    ]),
                    $.make('span', { className: training.author_ps || training.author_ng ? '' : 'NB-grey' }, [
                        gettext('Author: '),
                        (training.author_ps && $.make('span', { className: 'NB-green' }, training.author_ps)),
                        '-',
                        (training.author_ng && $.make('span', { className: 'NB-red' }, training.author_ng))
                    ]),
                    $.make('span', { className: training.tag_ps || training.tag_ng ? '' : 'NB-grey' }, [
                        gettext('Tag: '),
                        (training.tag_ps && $.make('span', { className: 'NB-green' }, training.tag_ps)),
                        '-',
                        (training.tag_ng && $.make('span', { className: 'NB-red' }, training.tag_ng))
                    ]),
                    $.make('span', { className: training.feed_ps || training.feed_ng ? '' : 'NB-grey' }, [
                        gettext('Feed: '),
                        (training.feed_ps && $.make('span', { className: 'NB-green' }, training.feed_ps)),
                        '-',
                        (training.feed_ng && $.make('span', { className: 'NB-red' }, training.feed_ng))
                    ])
                ])
            ]));
            $(window).resize();
        }, this));
    },

    // ==========
    // = Listen =
    // ==========

    fetch_listen_usage: function () {
        this.model.fetch_listen_staff_usage(this.user.get('user_id'), _.bind(function (data) {
            this.render_listen_usage(data.usage);
        }, this), _.bind(function () {
            $('.NB-admin-listen', this.$modal).text(gettext("Couldn't load listening."));
        }, this));
    },

    render_listen_usage: function (usage) {
        var $listen = $('.NB-admin-listen', this.$modal).empty();
        var minutes = function (seconds) { return Math.round((seconds || 0) / 60); };
        var lines = [];
        if (usage.seconds_limit) {
            // reader_admin.js: Archive and Archive Extra count a calendar month, Pro a week (apps/listen/usage.py).
            var allowance = {
                tier: usage.tier,
                used: minutes(usage.seconds_used),
                limit: minutes(usage.seconds_limit),
                resets: usage.resets_at ? new Date(usage.resets_at).toLocaleString() : ''
            };
            lines.push(usage.period == 'month' ?
                interpolate(gettext("Plan: %(tier)s. %(used)s of %(limit)s minutes of new audio this month, resets %(resets)s."), allowance, true) :
                interpolate(gettext("Plan: %(tier)s. %(used)s of %(limit)s minutes of new audio this week, resets %(resets)s."), allowance, true));
        } else {
            lines.push(interpolate(gettext("Plan: %(tier)s. %(count)s stories previewed today."), {
                tier: usage.tier,
                count: usage.samples_used || 0
            }, true));
        }
        lines.push(interpolate(gettext("Voice previews today: %(used)s of %(limit)s."), {
            used: usage.previews_used || 0,
            limit: usage.previews_limit
        }, true));
        lines.push(usage.last_reset_at ?
            interpolate(gettext("Last manual reset: %(date)s."), {
                date: new Date(usage.last_reset_at + 'Z').toLocaleString()
            }, true) :
            gettext("Never reset."));
        _.each(lines, function (line) {
            $listen.append($.make('div', { className: 'NB-admin-listen-line' }, line));
        });
        $listen.append($.make('div', {
            className: 'NB-modal-submit-button NB-modal-submit-green NB-admin-action-listen-reset'
        }, gettext("Reset Listen usage")));
    },

    // ========
    // = Team =
    // ========

    fetch_team: function () {
        this.model.fetch_team_staff(this.user.get('user_id'), _.bind(function (data) {
            this.render_team(data);
        }, this), _.bind(function () {
            $('.NB-admin-team', this.$modal).text(gettext("Couldn't load the team."));
        }, this));
    },

    // reader_admin.js: data is the team as staff see it (apps/team/views.py staff_team), and error is the message
    // the server refused an action with.
    render_team: function (data, error) {
        this.team_data = data;
        var team = data.team;
        var $team = $('.NB-admin-team', this.$modal).empty();
        var plan_names = {
            team: gettext("Premium Team"),
            team_enterprise: gettext("Premium Team Enterprise")
        };
        var make_plan_chooser = function (plan) {
            var $chooser = $.make('select', { className: 'NB-admin-team-plan' }, _.map(plan_names, function (name, value) {
                return $.make('option', { value: value }, name);
            }));
            return $chooser.val(plan);
        };
        var make_button = function (class_name, label) {
            return $.make('div', {
                className: 'NB-modal-submit-button NB-modal-submit-green ' + class_name
            }, label);
        };

        if (!team) {
            $team.append($.make('div', { className: 'NB-admin-team-control' }, [
                $.make('span', gettext("Not on a team.")),
                data.can_comp && make_plan_chooser('team'),
                data.can_comp && make_button('NB-admin-action-team-comp', gettext("Comp a team"))
            ]));
        } else {
            var members = _.map(team.members, function (member) {
                return interpolate(gettext("%(username)s (%(role)s)"), member, true);
            });
            $team.append($.make('dl', [
                $.make('dt', gettext('Team:')),
                $.make('dd', interpolate(gettext("%(name)s (id %(id)s)"), team, true)),
                $.make('dt', gettext('Role:')),
                $.make('dd', team.role),
                $.make('dt', gettext('Owner:')),
                $.make('dd', team.owner || gettext('Nobody')),
                $.make('dt', gettext('Plan:')),
                $.make('dd', plan_names[team.plan]),
                $.make('dt', gettext('Status:')),
                $.make('dd', team.status == 'active' ? gettext('Active') : gettext('Inactive')),
                $.make('dt', gettext('Seats:')),
                $.make('dd', interpolate(gettext("%(seats_used)s of %(seat_limit)s in use"), team, true)),
                $.make('dt', gettext('Billing:')),
                $.make('dd', team.comped ? gettext('Comped, no end') :
                    _.compact([team.billing_provider, team.billing_reference]).join(', ') || gettext('None')),
                $.make('dt', gettext('Paid through:')),
                $.make('dd', team.paid_through || gettext('None')),
                (team.pending_plan && $.make('dt', gettext('Switching to:'))),
                (team.pending_plan && $.make('dd', plan_names[team.pending_plan] || team.pending_plan)),
                (team.pending_owner && $.make('dt', gettext('Handing to:'))),
                (team.pending_owner && $.make('dd', team.pending_owner)),
                $.make('dt', gettext('Members:')),
                $.make('dd', members.join(', '))
            ]));
            $team.append($.make('div', { className: 'NB-admin-team-control' }, [
                $.make('input', {
                    type: 'number',
                    className: 'NB-admin-team-seat-limit',
                    min: Math.max(team.seats_used, 1),
                    max: team.max_seat_limit,
                    value: team.seat_limit
                }),
                make_button('NB-admin-action-team-seats', gettext("Save seat limit"))
            ]));
            if (team.comped) {
                $team.append($.make('div', { className: 'NB-admin-team-control' }, [
                    make_plan_chooser(team.plan),
                    make_button('NB-admin-action-team-plan', gettext("Save plan")),
                    make_button('NB-admin-action-team-end-comp', gettext("End comp"))
                ]));
            } else if (data.can_comp) {
                $team.append($.make('div', { className: 'NB-admin-team-control' }, [
                    make_plan_chooser(team.plan),
                    make_button('NB-admin-action-team-comp', gettext("Comp this team"))
                ]));
            }
        }

        if (error) {
            $team.append($.make('div', { className: 'NB-admin-team-error' }, error));
        }
    },

    team_action: function ($button, action, data) {
        if ($button.hasClass('NB-disabled')) return;
        $button.addClass('NB-disabled').text(gettext('Saving...'));

        this.model.team_staff_action(action, _.extend({ user_id: this.user.get('user_id') }, data), _.bind(function (response) {
            this.render_team(response);
        }, this), _.bind(function (response) {
            this.render_team(this.team_data, (response && response.message) || gettext("That didn't work. Try again."));
        }, this));
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-admin-action-refund' }, function ($t, $p) {
            e.preventDefault();

            NEWSBLUR.assets.refund_premium({
                'user_id': self.user.get('user_id')
            }, function (data) {
                $(".NB-admin-action-refund").replaceWith($.make('div', interpolate(gettext("Refunded $%(amount)s"), {amount: data.refunded}, true)));
            }, function (data) {
                $(".NB-admin-action-refund").replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-refund-partial' }, function ($t, $p) {
            e.preventDefault();

            NEWSBLUR.assets.refund_premium({
                'user_id': self.user.get('user_id'),
                'partial': true
            }, function (data) {
                $(".NB-admin-action-refund").replaceWith($.make('div', interpolate(gettext("Refunded $%(amount)s"), {amount: data.refunded}, true)));
            }, function (data) {
                $(".NB-admin-action-refund").replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-never-expire' }, function ($t, $p) {
            e.preventDefault();

            NEWSBLUR.assets.never_expire_premium({
                'user_id': self.user.get('user_id')
            }, function (data) {
                self.fetch_payment_history();
            }, function (data) {
                $(".NB-admin-action-never-expire").replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-1yr-expire' }, function ($t, $p) {
            e.preventDefault();

            NEWSBLUR.assets.never_expire_premium({
                'user_id': self.user.get('user_id'),
                'years': 1
            }, function (data) {
                self.fetch_payment_history();
            }, function (data) {
                $(".NB-admin-action-never-expire").replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-upgrade' }, function ($t, $p) {
            e.preventDefault();

            NEWSBLUR.assets.upgrade_premium(self.user.get('user_id'), function () {
                $(".NB-admin-action-upgrade").replaceWith($.make('div', gettext('Upgraded!')));
                self.fetch_payment_history();
            }, function (data) {
                $(".NB-admin-action-upgrade").replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-history' }, function ($t, $p) {
            e.preventDefault();

            NEWSBLUR.assets.update_payment_history(self.user.get('user_id'), function () {
                $(".NB-admin-action-history").replaceWith($.make('div', gettext('Updated!')));
                self.fetch_payment_history();
            }, function (data) {
                $(".NB-admin-action-history").replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-listen-reset' }, function ($t, $p) {
            e.preventDefault();
            if ($t.hasClass('NB-disabled')) return;
            $t.addClass('NB-disabled').text(gettext('Resetting...'));

            NEWSBLUR.assets.reset_listen_usage(self.user.get('user_id'), function (data) {
                self.render_listen_usage(data.usage);
            }, function (data) {
                $t.replaceWith($.make('div', interpolate(gettext("Error: %(error)s"), {error: JSON.stringify(data)}, true)));
            });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-team-seats' }, function ($t, $p) {
            e.preventDefault();
            self.team_action($t, 'seat_limit', { seat_limit: $('.NB-admin-team-seat-limit', self.$modal).val() });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-team-plan' }, function ($t, $p) {
            e.preventDefault();
            self.team_action($t, 'plan', { plan: $('.NB-admin-team-plan', self.$modal).val() });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-team-comp' }, function ($t, $p) {
            e.preventDefault();
            self.team_action($t, 'comp', { plan: $('.NB-admin-team-plan', self.$modal).val() });
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-team-end-comp' }, function ($t, $p) {
            e.preventDefault();
            if (!window.confirm(gettext("End this comp? The team's plan ends now for everyone on it."))) return;
            self.team_action($t, 'end_comp', {});
        });
        $.targetIs(e, { tagSelector: '.NB-admin-action-opml' }, function ($t, $p) {
            e.preventDefault();

            window.location.href = NEWSBLUR.URLs['opml-export'] + "?user_id=" + self.user.get('user_id');
        });

    }

});
