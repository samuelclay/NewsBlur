// reader_ai_credits.js: Monthly AI credits for natural language filters on the web: the month
// bar, the strip under the trainer's AI sections, the AI credits tab in the account dialog and
// the notice the reader sees when credits run low or out.
//
// Every number comes from apps/analyzer/ai_credits.py state(), which arrives in
// templates/base.html NEWSBLUR.Globals.ai_credits and is refreshed by
// /analyzer/ai_classifier_usage (the trainer) and /profile/usage_billing_history (the account
// dialog). A credit is about one story through a text filter; 1 cent buys 1,000 of them.
NEWSBLUR.AICredits = {

    state: function () {
        return NEWSBLUR.Globals.ai_credits;
    },

    update: function (state) {
        if (!state) return;
        NEWSBLUR.Globals.ai_credits = state;
        NEWSBLUR.Globals.is_usage_billing = state.is_usage_billing;
        NEWSBLUR.Globals.usage_billing_limit = state.monthly_limit;
        NEWSBLUR.Globals.can_use_ai_classifiers = state.pause_reason !== 'plan';
    },

    // Self-hosted servers don't count credits, so there's nothing to show.
    is_counted: function (state) {
        return !!(state && !state.is_unlimited);
    },

    locale: function () {
        return document.documentElement.lang || undefined;
    },

    // Credits are whole numbers, grouped: "12,340".
    format_credits: function (value) {
        return Math.round(Number(value || 0)).toLocaleString(this.locale());
    },

    format_usd: function (value) {
        return Number(value || 0).toLocaleString(this.locale(), { style: 'currency', currency: 'USD' });
    },

    // "Dec 1" from "2026-12-01", in the interface language, without a timezone shift.
    format_day: function (iso) {
        var parts = (iso || '').split('-');
        var date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return date.toLocaleDateString(this.locale(), { month: 'short', day: 'numeric' });
    },

    // The month bar's color follows the intelligence colors: green while credits last, amber
    // near the end, red when filters are paused. Past the plan with usage billing it stays green.
    tone: function (state) {
        if (state.is_paused) return 'out';
        if (state.is_warning) return 'warn';
        return 'ok';
    },

    summary_text: function (state) {
        if (state.included && state.used > state.included) {
            return interpolate(ngettext(
                "%(used)s AI credits used, %(over)s past your plan's %(included)s",
                "%(used)s AI credits used, %(over)s past your plan's %(included)s",
                state.included
            ), {
                used: this.format_credits(state.used),
                over: this.format_credits(state.used - state.included),
                included: this.format_credits(state.included)
            }, true);
        }
        return interpolate(ngettext(
            "%(used)s of %(included)s AI credit used",
            "%(used)s of %(included)s AI credits used",
            state.included
        ), {
            used: this.format_credits(state.used),
            included: this.format_credits(state.included)
        }, true);
    },

    resets_text: function (state) {
        return interpolate(gettext("Resets %(date)s"), { date: this.format_day(state.resets_on) }, true);
    },

    // The month bar: green (or amber, or red) for what's used over a light gray track, a striped
    // stretch for where the last week's pace ends the month, and a notch where the plan's credits
    // end once the bar runs past them.
    make_month_bar: function (state, options) {
        options = options || {};
        var included = state.included;
        var used = state.used;
        var projected = state.forecast ? Math.max(state.forecast.credits, used) : used;
        var furthest = Math.max(used, projected);
        var scale = Math.max(included, 1);
        if (furthest > scale) {
            // The plan's notch stays at least halfway along the bar, however far the pace runs.
            scale = included ? Math.min(furthest, included * 2) : furthest;
        }
        var percent = function (credits) {
            return Math.max(0, Math.min(100, credits / scale * 100));
        };

        return $.make('div', {
            className: 'NB-ai-credits-bar NB-ai-credits-tone-' + this.tone(state) +
                (options.large ? ' NB-ai-credits-bar-large' : ''),
            role: 'img',
            'aria-label': this.summary_text(state)
        }, [
            (projected > used && $.make('div', {
                className: 'NB-ai-credits-bar-forecast',
                style: 'width: ' + percent(projected) + '%'
            })),
            $.make('div', { className: 'NB-ai-credits-bar-used', style: 'width: ' + percent(used) + '%' }),
            (included && scale > included && $.make('div', {
                className: 'NB-ai-credits-bar-notch',
                style: 'left: ' + percent(included) + '%'
            }))
        ]);
    },

    // What usage billing would add this month, as a sentence, or null when it's nothing.
    forecast_cost_text: function (state) {
        var cost = state.forecast && state.forecast.overage_usd;
        if (!cost) return null;
        return interpolate(gettext("About %(cost)s this month at your pace."), { cost: this.format_usd(cost) }, true);
    },

    forecast_text: function (state) {
        var forecast = state.forecast;
        if (!forecast) return null;
        if (forecast.runs_out_on && !state.is_paused) {
            return interpolate(gettext("At this pace your credits run out around %(date)s."),
                { date: this.format_day(forecast.runs_out_on) }, true);
        }
        var projected = Math.round(forecast.credits);
        if (!state.is_paused && projected > Math.round(state.used)) {
            return interpolate(ngettext(
                "At this pace you'll use about %(count)s credit this month.",
                "At this pace you'll use about %(count)s credits this month.",
                projected
            ), { count: this.format_credits(projected) }, true);
        }
        return null;
    },

    // The sentences and the one action for the reader's state, shared by the trainer strip
    // and the reader notice. action is 'billing' (explain and set up usage billing), 'limit'
    // (change the monthly limit), or null.
    describe: function (state) {
        var reset_day = this.format_day(state.resets_on);
        var description = { title: null, lines: [], action: null, action_note: null };
        if (state.pause_reason === 'credits') {
            description.title = interpolate(gettext("Your AI filters are paused until %(date)s."), { date: reset_day }, true);
            description.lines.push(interpolate(ngettext(
                "This month's %(count)s AI credit is used.",
                "This month's %(count)s AI credits are used.",
                state.included
            ), { count: this.format_credits(state.included) }, true));
            if (state.is_billing_available) {
                description.action = 'billing';
                description.action_label = gettext("Turn on usage billing");
                description.action_note = this.forecast_cost_text(state) ?
                    interpolate(gettext("1¢ per 1,000 credits past your plan's, about %(cost)s this month."),
                        { cost: this.format_usd(state.forecast.overage_usd) }, true) :
                    gettext("1¢ per 1,000 credits past your plan's.");
            }
        } else if (state.pause_reason === 'limit') {
            description.title = interpolate(
                gettext("Your AI filters reached your %(limit)s monthly limit and are paused until %(date)s."),
                { limit: this.format_usd(state.monthly_limit), date: reset_day }, true);
            description.action = 'limit';
            description.action_label = gettext("Change limit");
        } else if (state.is_usage_billing) {
            description.lines.push(interpolate(ngettext(
                "Usage billing is on. Credits past your %(count)s cost 1¢ per 1,000: %(cost)s so far this month.",
                "Usage billing is on. Credits past your %(count)s cost 1¢ per 1,000: %(cost)s so far this month.",
                state.included
            ), { count: this.format_credits(state.included), cost: this.format_usd(state.overage_usd) }, true));
            if (state.unbilled_usd > 0) {
                description.lines.push(interpolate(
                    gettext("%(unbilled)s is waiting to be charged: at the start of next month if it's at least %(minimum)s, or right away at %(immediate)s."),
                    {
                        unbilled: this.format_usd(state.unbilled_usd),
                        minimum: this.format_usd(state.minimum_charge_usd),
                        immediate: this.format_usd(state.immediate_charge_usd)
                    }, true));
            }
            if (state.is_warning && state.monthly_limit) {
                description.lines.push(interpolate(gettext("You're close to your %(limit)s monthly limit."),
                    { limit: this.format_usd(state.monthly_limit) }, true));
                description.action = 'limit';
                description.action_label = gettext("Change limit");
            }
        } else {
            var forecast_line = this.forecast_text(state);
            if (forecast_line) description.lines.push(forecast_line);
            if (state.is_warning && state.is_billing_available) {
                description.action = 'billing';
                description.action_label = gettext("Keep filters running");
                var cost_line = this.forecast_cost_text(state);
                description.action_note = gettext("Past your credits, filters keep running at 1¢ per 1,000 credits.") +
                    (cost_line ? ' ' + cost_line : '');
            }
        }
        return description;
    },

    make_action: function (description) {
        if (!description.action) return null;
        return $.make('div', { className: 'NB-ai-credits-action' }, [
            $.make('a', {
                href: '#',
                className: 'NB-ai-credits-open-settings NB-modal-submit-button ' +
                    (description.action === 'billing' ? 'NB-modal-submit-green' : 'NB-ai-credits-button-secondary')
            }, description.action_label),
            (description.action_note && $.make('span', { className: 'NB-ai-credits-action-note' }).text(description.action_note))
        ]);
    },

    // reader_classifier.js: The credits row at the bottom of the trainer's AI filter card, or null
    // when there's nothing to show (a self-hosted server, or a free account, whose card says so
    // instead). The row opens the account dialog's AI credits tab, which has the reset date.
    make_trainer_strip: function (state) {
        if (!this.is_counted(state) || state.pause_reason === 'plan') return null;
        var description = this.describe(state);
        return $.make('div', { className: 'NB-ai-credits-strip NB-ai-credits-tone-' + this.tone(state) }, [
            $.make('a', { href: '#', className: 'NB-ai-credits-strip-heading NB-ai-credits-open-settings' }, [
                $.make('span', { className: 'NB-ai-credits-summary' }).text(this.summary_text(state)),
                $.make('span', { className: 'NB-ai-credits-chevron', 'aria-hidden': 'true' }, '\u203a')
            ]),
            this.make_month_bar(state),
            (description.title && $.make('div', { className: 'NB-ai-credits-title' }).text(description.title)),
            _.map(description.lines, function (line) {
                return $.make('div', { className: 'NB-ai-credits-line' }).text(line);
            }),
            this.make_action(description)
        ]);
    },

    // reader_classifier.js: Under each AI section, what one filter like it spends on this site.
    estimate_text: function (credits_per_month, include_images) {
        if (credits_per_month === undefined || credits_per_month === null) return null;
        var rounded = Math.round(credits_per_month);
        if (rounded < 1) {
            return include_images ?
                gettext("An image filter on this site uses less than one credit a month.") :
                gettext("A text filter on this site uses less than one credit a month.");
        }
        var count = this.format_credits(rounded);
        return interpolate(include_images ?
            ngettext("An image filter on this site uses about %(count)s credit a month.",
                "An image filter on this site uses about %(count)s credits a month.", rounded) :
            ngettext("A text filter on this site uses about %(count)s credit a month.",
                "A text filter on this site uses about %(count)s credits a month.", rounded),
            { count: count }, true);
    },

    // reader_classifier.js: The banner for a free account, whose filters save but don't run.
    make_plan_banner: function () {
        var $tier_link = $.make('a', { href: '#', className: 'NB-classifier-premium-link' }, gettext('Premium'));
        return $.make('div', { className: 'NB-ai-filter-upgrade-banner-inner' }, [
            NEWSBLUR.utils.interpolate_nodes(
                gettext("AI filters are saved but only run on %(tier_link)s."),
                { tier_link: $tier_link },
                function (text) { return $.make('b').text(text); }
            ),
            document.createTextNode(' ' + gettext("Premium includes 1,000 AI credits a month, Archive 10,000 and Pro 100,000."))
        ]);
    },

    // ==================================
    // = Account dialog: AI credits tab =
    // ==================================

    // reader_account.js: The AI credits tab, rebuilt whenever usage_billing_history returns.
    make_settings_panel: function (state, history) {
        var self = this;
        history = history || {};
        if (!this.is_counted(state)) {
            return $.make('div', { className: 'NB-ai-credits-settings' }, [
                $.make('div', { className: 'NB-preference' }, [
                    $.make('div', { className: 'NB-preference-options' },
                        gettext("AI filters run without credits on this server.")),
                    $.make('div', { className: 'NB-preference-label' }, gettext('AI credits'))
                ])
            ]);
        }
        var description = this.describe(state);
        var forecast_line = this.forecast_text(state);
        var $month = $.make('div', { className: 'NB-preference NB-ai-credits-month' }, [
            $.make('div', { className: 'NB-preference-options' }, [
                $.make('div', { className: 'NB-ai-credits-strip-heading' }, [
                    $.make('span', { className: 'NB-ai-credits-summary' }).text(this.summary_text(state)),
                    $.make('span', { className: 'NB-ai-credits-resets' }).text(this.resets_text(state))
                ]),
                this.make_month_bar(state, { large: true }),
                (description.title && $.make('div', { className: 'NB-ai-credits-title' }).text(description.title)),
                (forecast_line && !state.is_usage_billing && $.make('div', { className: 'NB-ai-credits-line' }).text(forecast_line)),
                (state.pause_reason === 'plan' && $.make('div', { className: 'NB-ai-credits-line' }, [
                    document.createTextNode(gettext("AI filters are saved but only run on Premium. Premium includes 1,000 AI credits a month, Archive 10,000 and Pro 100,000.") + ' '),
                    $.make('a', { href: '#', className: 'NB-account-premium-modal' }, gettext("Upgrade"))
                ]))
            ]),
            $.make('div', { className: 'NB-preference-label' }, [
                gettext('This month'),
                $.make('div', { className: 'NB-preference-sublabel' },
                    gettext("A credit is about one story through a text filter. An image filter uses about 10 credits a story."))
            ])
        ]);

        var $billing = state.is_billing_available && this.make_billing_preference(state, description);
        var $invoices = state.is_usage_billing && this.make_invoices_preference(history);

        return $.make('div', { className: 'NB-ai-credits-settings' }, [$month, $billing, $invoices]);
    },

    make_limit_field: function (state) {
        return $.make('div', { className: 'NB-ai-credits-limit' }, [
            $.make('label', { 'for': 'NB-ai-credits-limit-input', className: 'NB-ai-credits-limit-label' }, gettext("Monthly limit")),
            $.make('div', { className: 'NB-ai-credits-limit-row' }, [
                $.make('span', { className: 'NB-ai-credits-limit-dollar' }, '$'),
                $.make('input', {
                    type: 'number',
                    id: 'NB-ai-credits-limit-input',
                    className: 'NB-ai-credits-limit-input',
                    placeholder: gettext('No limit'),
                    min: '1',
                    step: '1',
                    value: state.monthly_limit || ''
                }),
                $.make('a', { href: '#', className: 'NB-ai-credits-limit-save NB-modal-submit-button NB-ai-credits-button-secondary' }, gettext("Save limit"))
            ]),
            $.make('div', { className: 'NB-ai-credits-limit-help' },
                gettext("Filters pause when usage billing reaches it. Leave empty for no limit.")),
            $.make('div', { className: 'NB-ai-credits-limit-status', role: 'status' })
        ]);
    },

    make_billing_preference: function (state, description) {
        var cost_line = this.forecast_cost_text(state);
        var $options;
        if (state.is_usage_billing) {
            $options = $.make('div', { className: 'NB-preference-options' }, [
                _.map(this.describe(_.extend({}, state, { pause_reason: null, is_paused: false })).lines, function (line) {
                    return $.make('div', { className: 'NB-ai-credits-line' }).text(line);
                }),
                (state.forecast && state.forecast.overage_usd > 0 && $.make('div', { className: 'NB-ai-credits-line' }).text(
                    interpolate(gettext("At your pace, the month comes to about %(cost)s."),
                        { cost: this.format_usd(state.monthly_limit ? Math.min(state.forecast.overage_usd, state.monthly_limit) : state.forecast.overage_usd) }, true))),
                this.make_limit_field(state),
                $.make('div', { className: 'NB-ai-credits-billing-actions' }, [
                    $.make('a', { href: '#', className: 'NB-ai-credits-manage NB-modal-submit-button NB-ai-credits-button-secondary' }, gettext("Update card on Stripe")),
                    $.make('a', { href: '#', className: 'NB-ai-credits-cancel' }, gettext("Turn off usage billing"))
                ]),
                $.make('div', { className: 'NB-ai-credits-cancel-status', role: 'status' })
            ]);
        } else {
            // The button leads the section: a reader who arrives from the trainer or the notice
            // came to set it up. A monthly limit typed below it is still saved first.
            $options = $.make('div', { className: 'NB-preference-options' }, [
                $.make('a', { href: '#', className: 'NB-ai-credits-setup NB-modal-submit-button NB-modal-submit-green' }, gettext("Set up usage billing")),
                $.make('div', { className: 'NB-ai-credits-line' },
                    gettext("Past your plan's credits, filters pause until the 1st. Usage billing keeps them running at 1¢ per 1,000 credits.")),
                $.make('ul', { className: 'NB-ai-credits-terms' }, [
                    $.make('li', gettext("You only pay for credits past your plan's.")),
                    $.make('li', gettext("Charged at the end of the month, once it reaches $1. Smaller amounts wait for a later month.")),
                    $.make('li', gettext("If it reaches $10 within a month, it's charged right away.")),
                    $.make('li', gettext("Set a monthly limit, or turn usage billing off any time."))
                ]),
                (cost_line && $.make('div', { className: 'NB-ai-credits-line NB-ai-credits-forecast-cost' }).text(cost_line)),
                this.make_limit_field(state)
            ]);
        }
        return $.make('div', { className: 'NB-preference NB-ai-credits-billing' }, [
            $options,
            $.make('div', { className: 'NB-preference-label' }, [
                gettext('Usage billing'),
                $.make('div', { className: 'NB-preference-sublabel' }, state.is_usage_billing ?
                    gettext("On") : gettext("Off"))
            ])
        ]);
    },

    make_invoices_preference: function (history) {
        var self = this;
        var invoices = history.invoices || [];
        var $list = $.make('ul', { className: 'NB-account-payments NB-ai-credits-invoices' });
        if (history.upcoming_invoice) {
            $list.append($.make('li', { className: 'NB-account-payment NB-ai-credits-invoice-upcoming' }, [
                $.make('div', { className: 'NB-account-payment-date' }, this.format_day(history.upcoming_invoice.date)),
                $.make('div', { className: 'NB-account-payment-amount' }, this.format_usd(history.upcoming_invoice.amount)),
                $.make('div', { className: 'NB-account-payment-provider' }, gettext("Upcoming"))
            ]));
        }
        _.each(invoices, function (invoice) {
            $list.append($.make('li', { className: 'NB-account-payment' }, [
                $.make('div', { className: 'NB-account-payment-date' }, self.format_day(invoice.date)),
                $.make('div', { className: 'NB-account-payment-amount' }, self.format_usd(invoice.amount)),
                $.make('div', { className: 'NB-account-payment-provider' }, invoice.hosted_invoice_url ?
                    $.make('a', { href: invoice.hosted_invoice_url, target: '_blank', rel: 'noopener' }, gettext("Invoice")) :
                    invoice.status)
            ]));
        });
        if (!invoices.length && !history.upcoming_invoice) {
            $list.append($.make('li', { className: 'NB-account-payment' }, $.make('i', gettext("No usage billing charges yet."))));
        }
        return $.make('div', { className: 'NB-preference NB-ai-credits-history' }, [
            $.make('div', { className: 'NB-preference-options' }, $list),
            $.make('div', { className: 'NB-preference-label' }, gettext('Usage billing charges'))
        ]);
    },

    // Usage billing starts on Stripe Checkout, which comes back to ?next=ai_credits. A limit
    // typed before setting it up is saved first, so the very first month is capped.
    setup_usage_billing: function ($panel) {
        var self = this;
        var submit = function () {
            self.post_to('/profile/setup_usage_billing/');
        };
        var limit = $.trim($('.NB-ai-credits-limit-input', $panel).val() || '');
        if (!limit) return submit();
        NEWSBLUR.assets.save_usage_billing_limit(limit, function (data) {
            if (data.code === -1) {
                $('.NB-ai-credits-limit-status', $panel).addClass('NB-error').text(data.message);
                return;
            }
            submit();
        });
    },

    manage_usage_billing: function () {
        this.post_to('/profile/manage_usage_billing/');
    },

    // Turning usage billing off charges what's past the plan now if it's at least $1, and
    // filters pause once the plan's credits are used.
    cancel_usage_billing: function ($panel, callback) {
        var self = this;
        $('.NB-ai-credits-cancel-status', $panel).text(gettext('Turning off...'));
        NEWSBLUR.assets.cancel_usage_billing(function (data) {
            if (!data || data.code !== 0) {
                $('.NB-ai-credits-cancel-status', $panel).addClass('NB-error')
                    .text((data && data.message) || gettext("Couldn't turn off usage billing. Please try again."));
                return;
            }
            self.update(data.ai_credits);
            if (callback) callback(data);
        });
    },

    post_to: function (url) {
        var $form = $('<form method="POST"></form>').attr('action', url);
        $form.append($('<input type="hidden" name="csrfmiddlewaretoken">').val($.cookie('csrftoken')));
        $('body').append($form);
        $form.submit();
    },

    save_limit: function ($panel, callback) {
        var self = this;
        var $status = $('.NB-ai-credits-limit-status', $panel).removeClass('NB-error').text(gettext('Saving...'));
        var limit = $.trim($('.NB-ai-credits-limit-input', $panel).val() || '');
        NEWSBLUR.assets.save_usage_billing_limit(limit, function (data) {
            if (data.code === -1) {
                $status.addClass('NB-error').text(data.message);
                return;
            }
            self.update(data.ai_credits);
            $status.text(data.limit ? interpolate(gettext("Saved. Filters pause at %(limit)s a month."),
                { limit: self.format_usd(data.limit) }, true) : gettext("Saved. No monthly limit."));
            if (callback) callback(data);
        });
    },

    // ===============================
    // = Notice when credits run low =
    // ===============================

    // reader.js: Once the feed list loads, a reader near the end of their credits, or whose
    // filters paused, sees a notice once a month for each, until they close it.
    maybe_show_notice: function () {
        var state = this.state();
        if (!this.is_counted(state) || state.pause_reason === 'plan') return;
        var kind = state.is_paused ? 'paused' : (state.is_warning ? 'warning' : null);
        if (!kind) return;
        var dismissed_key = state.month + ':' + kind;
        if (NEWSBLUR.assets.preference('ai_credits_notice_dismissed') === dismissed_key) return;
        if ($('.NB-modal').length || $('.NB-ai-credits-notice').length) return;
        this.show_notice(state, dismissed_key);
    },

    show_notice: function (state, dismissed_key) {
        var self = this;
        var description = this.describe(state);
        var title = description.title || interpolate(ngettext(
            "You've used %(used)s of your %(included)s AI credit this month.",
            "You've used %(used)s of your %(included)s AI credits this month.",
            state.included
        ), { used: this.format_credits(state.used), included: this.format_credits(state.included) }, true);

        var $notice = $.make('div', {
            className: 'NB-ai-credits-notice NB-ai-credits-tone-' + this.tone(state),
            role: 'status'
        }, [
            $.make('div', { className: 'NB-ai-credits-notice-close', role: 'button', 'aria-label': gettext('Close') }, '×'),
            $.make('div', { className: 'NB-ai-credits-notice-title' }).text(title),
            this.make_month_bar(state),
            _.map(description.lines, function (line) {
                return $.make('div', { className: 'NB-ai-credits-line' }).text(line);
            }),
            this.make_action(description)
        ]);

        var close = function () {
            NEWSBLUR.assets.preference('ai_credits_notice_dismissed', dismissed_key);
            $notice.addClass('NB-ai-credits-notice-closing');
            _.delay(function () { $notice.remove(); }, 200);
        };
        $notice.on('click', '.NB-ai-credits-notice-close', close);
        $notice.on('click', '.NB-ai-credits-open-settings', function (e) {
            e.preventDefault();
            close();
            NEWSBLUR.reader.open_account_modal({ tab: 'aicredits' });
        });
        $('body').append($notice);
    }
};
