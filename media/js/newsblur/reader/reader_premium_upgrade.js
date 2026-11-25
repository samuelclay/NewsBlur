NEWSBLUR.ReaderPremiumUpgrade = function (options) {
    options = options || {};
    var defaults = {
        'width': 1050,
        'height': 'auto',
        'onOpen': _.bind(function () {
            // Resize after a brief delay to let content render
            _.defer(_.bind(this.resize_modal, this));
        }, this),
        'onClose': _.bind(function () {
            dialog.data.hide().empty().remove();
            dialog.container.hide().empty().remove();
            dialog.overlay.fadeOut(200, function () {
                dialog.overlay.empty().remove();
                $.modal.close(callback);
            });
            $('.NB-modal-holder').empty().remove();
        }, this)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderPremiumUpgrade.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderPremiumUpgrade.prototype.constructor = NEWSBLUR.ReaderPremiumUpgrade;

_.extend(NEWSBLUR.ReaderPremiumUpgrade.prototype, {

    runner: function () {
        this.listen_hours = this.initial_listen_hours();
        this.make_modal();
        this.apply_listen_hours();
        this.highlight_feature();
        this.make_paypal_button();
        this.open_modal();
        this.$modal.bind('mousedown', $.rescope(this.handle_mousedown, this));
        // Click rather than mousedown, so Enter and Space on a focused option choose it too.
        this.$modal.on('click', '.NB-listen-hours-option', _.bind(function (e) {
            e.preventDefault();
            this.choose_listen_hours($(e.currentTarget).data('hours'));
        }, this));
        this.$modal.on('keydown', '.NB-listen-hours', _.bind(function (e) {
            if (!_.contains(['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'], e.key)) return;
            e.preventDefault();
            this.choose_listen_hours(this.listen_hours == 10 ? 1 : 10);
            this.$modal.find('.NB-listen-hours-option[aria-checked=true]').focus();
        }, this));
    },

    // reader_premium_upgrade.js: Highlight the feature line that prompted this
    // upgrade (e.g. options.highlight_feature = 'briefing' from a briefing callout).
    highlight_feature: function () {
        if (!this.options.highlight_feature) return;
        this.$modal.find('li.NB-feature-' + this.options.highlight_feature)
            .addClass('NB-premium-feature-highlighted');
    },

    make_modal: function () {
        var self = this;
        var $creditcards = $.make('div', { className: 'NB-creditcards' }, [
            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_stripe.svg" }),
            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_visa.svg" }),
            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_mastercard.svg" }),
            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_amex.svg" }),
            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + "/img/reader/cc_discover.svg" })
        ]);

        this.$modal = $.make('div', { className: 'NB-modal-premium-upgrade NB-modal' }, [
            $.make('div', { className: 'NB-premium-upgrade-header' }, [
                $.make('h2', { className: 'NB-modal-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    gettext('Upgrade to Premium'),
                    $.make('div', { className: 'NB-icon-dropdown' })
                ]),
                (NEWSBLUR.Globals.is_premium_trial && $.make('div', { className: 'NB-premium-trial-badge' },
                    interpolate(ngettext("<strong>%(count)s day</strong> left in your premium trial", "<strong>%(count)s days</strong> left in your premium trial", NEWSBLUR.Globals.trial_days_remaining), {count: NEWSBLUR.Globals.trial_days_remaining}, true)
                ))
            ]),
            $.make('div', { className: 'NB-premium-tiers' }, [
                // Premium Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-premium' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name' }, gettext('Premium')),
                        $.make('div', { className: 'NB-premium-tier-price' }, [
                            $.make('span', { className: 'NB-premium-tier-price-amount' }, '$36'),
                            $.make('span', { className: 'NB-premium-tier-price-period' }, gettext('/year'))
                        ])
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-premium' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, gettext('Everything in Free, plus:')),
                        $.make('li', { className: 'NB-1 NB-feature-site-limit' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Follow up to 1,024 sites')
                        ]),
                        $.make('li', { className: 'NB-2 NB-feature-update-frequency' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Sites updated up to 5x more often')
                        ]),
                        $.make('li', { className: 'NB-3 NB-feature-river' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('River of News (reading by folder)')
                        ]),
                        $.make('li', { className: 'NB-4 NB-feature-search' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Search sites and folders')
                        ]),
                        $.make('li', { className: 'NB-5 NB-feature-saved-tags' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Save stories with searchable tags')
                        ]),
                        $.make('li', { className: 'NB-6 NB-feature-privacy' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Privacy options for your blurblog')
                        ]),
                        $.make('li', { className: 'NB-7 NB-feature-saved-rss' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Custom RSS feeds for saved stories')
                        ]),
                        $.make('li', { className: 'NB-8 NB-feature-text-view' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Text view extracts the story')
                        ]),
                        $.make('li', { className: 'NB-9 NB-feature-discover' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Discover related stories and sites')
                        ]),
                        $.make('li', { className: 'NB-10 NB-feature-classifiers' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Natural language text and image classifiers')
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_tier_buttons('premium', $creditcards.clone())
                    ])
                ]),
                // Archive Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-archive' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name NB-premium-archive-name' }, gettext('Premium Archive')),
                        $.make('div', { className: 'NB-premium-tier-price' }, [
                            $.make('span', { className: 'NB-premium-tier-price-amount NB-premium-archive-price' }, '$99'),
                            $.make('span', { className: 'NB-premium-tier-price-period' }, gettext('/year'))
                        ])
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-archive' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, gettext('Everything in Premium, plus:')),
                        $.make('li', { className: 'NB-1 NB-feature-site-limit' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Follow up to 4,096 sites')
                        ]),
                        $.make('li', { className: 'NB-2 NB-feature-webfeeds' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Web Feeds from any website, even without RSS')
                        ]),
                        this.make_archive_listen_feature(),
                        $.make('li', { className: 'NB-14 NB-feature-ask-ai' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Ask AI questions about stories')
                        ]),
                        $.make('li', { className: 'NB-16 NB-feature-training-scope' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Apply training across a folder')
                        ]),
                        $.make('li', { className: 'NB-17 NB-feature-training-scope' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Apply training globally')
                        ]),
                        $.make('li', { className: 'NB-4 NB-feature-briefing' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Daily briefing with your top stories and keywords')
                        ]),
                        $.make('li', { className: 'NB-7 NB-feature-archive-forever' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Every story archived and searchable forever')
                        ]),
                        $.make('li', { className: 'NB-3 NB-feature-clustering' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Cluster duplicate stories across all your feeds')
                        ]),
                        $.make('li', { className: 'NB-9 NB-feature-text-training' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Train stories on full text content')
                        ]),
                        $.make('li', { className: 'NB-10 NB-feature-notifications' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Notifications on trained intelligence classifiers')
                        ]),
                        $.make('li', { className: 'NB-5 NB-feature-choose-mark-read' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Choose when stories are marked as read')
                        ]),
                        $.make('li', { className: 'NB-6 NB-feature-auto-mark-read' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Customize auto-read by site or folder')
                        ]),
                        $.make('li', { className: 'NB-8 NB-feature-backfill' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Feeds back-filled for complete archive')
                        ]),
                        $.make('li', { className: 'NB-11 NB-feature-discover' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Discover related stories across your archive')
                        ]),
                        $.make('li', { className: 'NB-12 NB-feature-export-folders' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Export trained stories from folders')
                        ]),
                        $.make('li', { className: 'NB-13 NB-feature-stay-unread' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Stories can stay unread forever')
                        ]),
                        $.make('li', { className: 'NB-15 NB-feature-date-filter' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Filter stories by date range')
                        ]),
                        $.make('li', { className: 'NB-18 NB-feature-mcp' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Connect AI agents with MCP server and CLI')
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions NB-premium-archive-actions' }, [
                        $.make('div', { className: 'NB-premium-archive-plan', 'data-plan': 'archive' }, [
                            this.make_tier_buttons('archive', $creditcards.clone())
                        ]),
                        (this.offers_archive_extra() && $.make('div', { className: 'NB-premium-archive-plan', 'data-plan': 'archive_extra' }, [
                            this.make_tier_buttons('archive_extra', $creditcards.clone())
                        ]))
                    ])
                ]),
                // Pro Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-pro' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name' }, gettext('Premium Pro')),
                        $.make('div', { className: 'NB-premium-tier-price' }, [
                            $.make('span', { className: 'NB-premium-tier-price-amount' }, '$29'),
                            $.make('span', { className: 'NB-premium-tier-price-period' }, gettext('/month'))
                        ])
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-pro' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, gettext('Everything in Archive, plus:')),
                        $.make('li', { className: 'NB-1 NB-feature-site-limit' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Follow up to 10,000 sites')
                        ]),
                        $.make('li', { className: 'NB-2 NB-feature-update-frequency' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('All feeds fetched every 5-15 minutes')
                        ]),
                        $.make('li', { className: 'NB-3 NB-feature-regex' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Train stories with regular expressions')
                        ]),
                        $.make('li', { className: 'NB-5 NB-feature-listen' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Listen to 10 hours of stories read aloud a week')
                        ]),
                        $.make('li', { className: 'NB-feature-oauth' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Create OAuth applications')
                        ]),
                        $.make('li', { className: 'NB-4' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            gettext('Priority support')
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_tier_buttons('pro', $creditcards.clone())
                    ])
                ])
            ]),
            // Bottom row: Free and Self-Hosted side by side
            $.make('div', { className: 'NB-premium-tiers-bottom' }, [
                // Free Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-free' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name' }, gettext('Free'))
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-free' }, [
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Follow up to 64 sites'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Real-time RSS updates'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Train stories by author, tag, title'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Public blurblog sharing'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Save stories for later'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('iOS & Android apps'))
                        ])
                    ]),
                    (NEWSBLUR.Globals.is_premium_trial && $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_free_tier_status()
                    ]))
                ]),
                // Self-Hosted Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-selfhosted' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-label' }, gettext('DIY')),
                        $.make('div', { className: 'NB-premium-tier-name' }, gettext('Self-Hosted'))
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-selfhosted' }, [
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Run your own NewsBlur'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Complete data ownership'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('One command with Docker'))
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', gettext('Customize with Claude Code'))
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        $.make('a', {
                            className: 'NB-premium-selfhosted-github NB-modal-submit-button NB-modal-submit-grey',
                            href: 'https://github.com/samuelclay/NewsBlur',
                            target: '_blank'
                        }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/github-mark.svg', className: 'NB-github-icon' }),
                            gettext('View on GitHub')
                        ])
                    ])
                ])
            ])
        ]);
    },

    // ============================================
    // = Premium Archive: 1 or 10 hours of Listen =
    // ============================================

    // reader_premium_upgrade.js: Premium Archive Extra is Premium Archive with 10 hours of Listen a month instead
    // of 1, so it is a toggle on the Archive card rather than its own card. Pro already includes more, so a Pro
    // subscriber sees the Archive card without it.
    offers_archive_extra: function () {
        return !NEWSBLUR.Globals.is_pro;
    },

    initial_listen_hours: function () {
        if (NEWSBLUR.Globals.is_archive_extra) return 10;
        // An Archive subscriber who came here from Listen has used up their hour, so start on 10 hours.
        if (NEWSBLUR.Globals.is_archive && this.options.highlight_feature == 'listen') return 10;
        return 1;
    },

    make_archive_listen_feature: function () {
        if (!this.offers_archive_extra()) {
            return $.make('li', { className: 'NB-19 NB-feature-listen' }, [
                $.make('div', { className: 'NB-premium-bullet-image' }),
                gettext('Listen to 1 hour of stories read aloud a month')
            ]);
        }
        var make_option = _.bind(function (hours, plan, label, price) {
            var is_current = this.is_current_plan(plan) && !NEWSBLUR.Globals.is_premium_trial;
            return $.make('button', {
                type: 'button',
                role: 'radio',
                className: 'NB-listen-hours-option',
                'data-hours': hours
            }, [
                $.make('span', { className: 'NB-listen-hours-option-label' }, label),
                $.make('span', { className: 'NB-listen-hours-option-price' },
                    is_current ? gettext('Current plan') : interpolate(gettext('%(price)s/year'), { price: price }, true))
            ]);
        }, this);
        return $.make('li', { className: 'NB-19 NB-feature-listen NB-feature-listen-hours' }, [
            $.make('div', { className: 'NB-premium-bullet-image' }),
            $.make('div', { className: 'NB-listen-hours-title' }, gettext('Listen to 1 hour of stories read aloud a month')),
            $.make('div', {
                className: 'NB-listen-hours',
                role: 'radiogroup',
                'aria-label': gettext('Monthly listening')
            }, [
                $.make('div', { className: 'NB-listen-hours-thumb' }),
                make_option(1, 'archive', gettext('1 hour'), '$99'),
                make_option(10, 'archive_extra', gettext('10 hours'), '$159')
            ])
        ]);
    },

    apply_listen_hours: function () {
        if (!this.offers_archive_extra()) return;
        var extra = this.listen_hours == 10;
        var $card = this.$modal.find('.NB-premium-tier-archive');
        $card.toggleClass('NB-premium-archive-extra', extra);
        $card.find('.NB-premium-archive-name').text(extra ? gettext('Premium Archive Extra') : gettext('Premium Archive'));
        $card.find('.NB-premium-archive-price').text(extra ? '$159' : '$99');
        $card.find('.NB-listen-hours-title').text(extra ?
            gettext('Listen to 10 hours of stories read aloud a month') :
            gettext('Listen to 1 hour of stories read aloud a month'));
        $card.find('.NB-listen-hours-option').each(_.bind(function (i, option) {
            var selected = $(option).data('hours') == this.listen_hours;
            $(option).attr('aria-checked', selected ? 'true' : 'false').attr('tabindex', selected ? '0' : '-1');
        }, this));
        $card.find('.NB-premium-archive-plan').each(function () {
            var plan = $(this).data('plan');
            $(this).toggleClass('NB-premium-archive-plan-hidden', (plan == 'archive_extra') != extra);
        });
    },

    choose_listen_hours: function (hours) {
        if (hours == this.listen_hours) return;
        this.listen_hours = hours;
        this.apply_listen_hours();
        _.defer(_.bind(this.resize_modal, this));
    },

    is_current_plan: function (plan) {
        if (plan === 'premium') return NEWSBLUR.Globals.is_premium && !NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro;
        if (plan === 'archive') return NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_archive_extra && !NEWSBLUR.Globals.is_pro;
        if (plan === 'archive_extra') return NEWSBLUR.Globals.is_archive_extra && !NEWSBLUR.Globals.is_pro;
        if (plan === 'pro') return NEWSBLUR.Globals.is_pro;
        return false;
    },

    make_tier_buttons: function (plan, $creditcards) {
        var is_trial = NEWSBLUR.Globals.is_premium_trial;
        var has_renewal = NEWSBLUR.Globals.premium_renewal;

        // Determine user's current tier level (0=free, 1=premium, 2=archive, 3=pro)
        var user_tier = this.get_user_tier();
        var plan_tier = this.get_plan_tier(plan);

        var is_current_plan = this.is_current_plan(plan);

        // Current plan with active renewal - show status
        if (is_current_plan && !is_trial && has_renewal) {
            return $.make('div', { className: 'NB-premium-tier-status' }, [
                $.make('div', { className: 'NB-premium-tier-status-active' }, [
                    $.make('div', { className: 'NB-premium-tier-status-icon' }),
                    $.make('div', { className: 'NB-premium-tier-status-text' }, interpolate(gettext("Your %(value_1)s subscription is active"), {value_1: this.plan_name(plan)}, true))
                ]),
                $.make('div', { className: 'NB-provider-button-change NB-modal-submit-button NB-modal-submit-grey' }, gettext('Change billing details'))
            ]);
        }

        // Current plan without renewal - show restart button
        if (is_current_plan && !is_trial && !has_renewal) {
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $.make('div', { className: 'NB-premium-tier-status-active' }, [
                    $.make('div', { className: 'NB-premium-tier-status-icon' }),
                    $.make('div', { className: 'NB-premium-tier-status-text' }, interpolate(gettext("Your %(value_1)s subscription is active"), {value_1: this.plan_name(plan)}, true))
                ]),
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, interpolate(gettext("Restart your %(value_1)s subscription"), {value_1: this.plan_name(plan)}, true)),
                this.make_paypal_alternate(plan)
            ]);
        }

        // Trial user viewing their trial tier - show trial status and upgrade button
        if (is_trial && is_current_plan) {
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $.make('div', { className: 'NB-premium-tier-trial-status' }, [
                    gettext('You are trialing this plan')
                ]),
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, interpolate(gettext("Upgrade to %(value_1)s"), {value_1: this.plan_name(plan)}, true)),
                this.make_paypal_alternate(plan)
            ]);
        }

        // Higher tier user viewing lower tier - show "includes everything" and switch option
        if (!is_trial && user_tier > plan_tier && user_tier > 0) {
            var current_plan_name = this.plan_name(this.get_plan_name_from_tier(user_tier));
            return $.make('div', { className: 'NB-premium-tier-status' }, [
                $.make('div', { className: 'NB-premium-tier-status-included' }, [
                    $.make('div', { className: 'NB-premium-tier-status-icon' }),
                    $.make('div', { className: 'NB-premium-tier-status-text' }, interpolate(gettext("Your %(value_1)s subscription includes everything above"), {value_1: current_plan_name}, true))
                ]),
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-grey'
                }, interpolate(gettext("Switch to %(value_1)s"), {value_1: this.plan_name(plan)}, true))
            ]);
        }

        // Lower tier user viewing higher tier, or free/trial user - show upgrade button
        return $.make('div', { className: 'NB-premium-tier-buttons' }, [
            $creditcards,
            $.make('div', {
                className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
            }, interpolate(gettext("Upgrade to %(value_1)s"), {value_1: this.plan_name(plan)}, true)),
            this.make_paypal_alternate(plan),
            this.make_prorate_message(plan)
        ]);
    },

    get_user_tier: function () {
        // Returns user's current tier level: 0=free/trial, 1=premium, 2=archive, 2.5=archive extra, 3=pro
        if (NEWSBLUR.Globals.is_pro) return 3;
        if (NEWSBLUR.Globals.is_archive_extra) return 2.5;
        if (NEWSBLUR.Globals.is_archive) return 2;
        if (NEWSBLUR.Globals.is_premium && !NEWSBLUR.Globals.is_premium_trial) return 1;
        return 0;
    },

    get_plan_tier: function (plan) {
        // Returns tier level for a plan: 1=premium, 2=archive, 2.5=archive extra, 3=pro
        if (plan === 'pro') return 3;
        if (plan === 'archive_extra') return 2.5;
        if (plan === 'archive') return 2;
        if (plan === 'premium') return 1;
        return 0;
    },

    get_plan_name_from_tier: function (tier) {
        if (tier === 3) return 'pro';
        if (tier === 2.5) return 'archive_extra';
        if (tier === 2) return 'archive';
        if (tier === 1) return 'premium';
        return 'free';
    },

    plan_name: function (plan) {
        if (plan === 'premium') return gettext('Premium');
        if (plan === 'archive') return gettext('Premium Archive');
        if (plan === 'archive_extra') return gettext('Premium Archive Extra');
        if (plan === 'pro') return gettext('Premium Pro');
        return plan;
    },

    paypal_plan_id: function (plan) {
        if (NEWSBLUR.Globals.debug) {
            if (plan == 'premium') return "P-4RV31836YD8080909MHZROJY";
            if (plan == 'archive') return "P-2EG40290653242115MHZROQQ";
            if (plan == 'pro') return "P-1AE0908250058421JM565SVY";
        } else {
            if (plan == 'premium') return "P-48R22630SD810553FMHZONIY";
            if (plan == 'archive') return "P-5JM46230U31841226MHZOMZY";
            if (plan == 'archive_extra') return "P-42M09399PN6032344NMDG2LI";
            if (plan == 'pro') return "P-1AE0908250058421JM565SVY";
        }
        // reader_premium_upgrade.js: Archive Extra has no PayPal sandbox plan, so in development it has no
        // PayPal button.
        return null;
    },

    make_paypal_alternate: function (plan) {
        if (!this.paypal_plan_id(plan)) return;
        if (NEWSBLUR.Globals.active_provider === 'paypal') {
            return $.make('div', { className: 'NB-provider-alternate' }, [
                $.make('div', {
                    className: 'NB-stripe-button-switch-' + plan + ' NB-modal-submit-button NB-modal-submit-grey'
                }, gettext('Switch to Credit Card'))
            ]);
        }
        // reader_premium_upgrade.js: "or subscribe with [PayPal]" as one translated
        // sentence with the PayPal button as a placeholder.
        return $.make('div', { className: 'NB-provider-alternate' }, NEWSBLUR.utils.interpolate_nodes(
            gettext('or subscribe with %(paypal_button)s'),
            { paypal_button: $.make('div', { className: 'NB-splash-link NB-paypal-button', 'data-plan': plan }, '') },
            function (text) {
                return $.trim(text) ? $.make('span', { className: 'NB-provider-text' }).text(text) : null;
            }
        ));
    },

    make_prorate_message: function (plan) {
        if (!_.contains(['paypal', 'stripe'], NEWSBLUR.Globals.active_provider)) return;
        if (plan === 'premium') return; // No prorate for base premium
        return $.make('div', { className: 'NB-premium-prorate-message' },
            gettext('Your subscription will be prorated')
        );
    },

    make_free_tier_status: function () {
        var is_trial = NEWSBLUR.Globals.is_premium_trial;

        // Trial user - show when they'll become free
        if (is_trial) {
            var days = NEWSBLUR.Globals.trial_days_remaining;
            return $.make('div', { className: 'NB-premium-tier-free-status' }, [
                $.make('div', { className: 'NB-premium-tier-free-trial-notice' }, [
                    interpolate(ngettext("In %(count)s day, your premium trial ends and you'll return to Free", "In %(count)s days, your premium trial ends and you'll return to Free", days), {count: days}, true)
                ])
            ]);
        }

        // No footer needed for free or paid users
        return false;
    },

    make_paypal_button: function () {
        var self = this;
        jQuery.ajax({
            type: "GET",
            url: NEWSBLUR.URLs.paypal_checkout_js,
            dataType: "script",
            cache: true
        }).done(_.bind(function () {
            var $buttons = $(".NB-paypal-button");
            var buttons_to_render = $buttons.length;
            var buttons_rendered = 0;

            $buttons.each(function () {
                var $button = $(this);
                var plan = $button.data('plan');
                var plan_id = self.paypal_plan_id(plan);
                var random_id = 'paypal-' + Math.round(Math.random() * 100000);
                $button.attr('id', random_id);
                paypal.Buttons({
                    fundingSource: paypal.FUNDING.PAYPAL,
                    style: {
                        shape: 'rect',
                        color: 'silver',
                        layout: 'horizontal',
                        label: 'paypal',
                    },

                    createSubscription: function (data, actions) {
                        return actions.subscription.create({
                            'plan_id': plan_id,
                            'application_context': {
                                'shipping_preference': 'NO_SHIPPING',
                                'user_action': 'SUBSCRIBE_NOW'
                            },
                            'custom_id': NEWSBLUR.Globals.user_id
                        });
                    },

                    onApprove: function (data, actions) {
                        console.log('Paypal approve result', data.subscriptionID, JSON.stringify(data, null, 2));
                        if (plan == "archive" || plan == "archive_extra") {
                            actions.redirect(NEWSBLUR.URLs.paypal_archive_return);
                        } else if (plan == "pro") {
                            actions.redirect(NEWSBLUR.URLs.paypal_pro_return);
                        } else {
                            actions.redirect(NEWSBLUR.URLs.paypal_return);
                        }
                    },

                    onError: function (err) {
                        console.log(err);
                    }
                }).render('#' + random_id).then(function () {
                    buttons_rendered++;
                    if (buttons_rendered >= buttons_to_render) {
                        self.resize_modal();
                    }
                });
            });
        }, this));
    },

    resize_modal: function () {
        var $container = $('#simplemodal-container');
        var $modal = $('.NB-modal-premium-upgrade');
        if (!$container.length || !$modal.length) return;

        // Get the natural height of the modal content
        var content_height = $modal.outerHeight(true);
        var window_height = $(window).height();
        var max_height = window_height - 48; // Leave some padding

        // Set container height to fit content exactly
        var new_height = Math.max(500, Math.min(content_height, max_height));

        $container.css({
            'height': new_height,
            'max-height': max_height
        });

        // Center the modal vertically
        var top = Math.max(24, (window_height - new_height) / 2);
        $container.css('top', top);
    },

    open_stripe_checkout: function (plan, $button) {
        if ($button.hasClass('NB-disabled')) return;
        $button.attr('disabled', 'disabled');
        $button.text(gettext("Loading checkout..."));
        $button.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true);

        $.redirectPost("/profile/switch_stripe_subscription", { "plan": plan });
    },

    open_paypal_checkout: function (plan, $button) {
        if ($button.hasClass('NB-disabled')) return;
        $button.attr('disabled', 'disabled');
        $button.text(gettext("Loading PayPal..."));
        $button.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true);

        $.redirectPost("/profile/switch_paypal_subscription", { "plan": plan });
    },

    // ===========
    // = Actions =
    // ===========

    handle_mousedown: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-stripe-button-switch-premium' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.open_stripe_checkout('premium', $t);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-stripe-button-switch-archive' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.open_stripe_checkout('archive', $t);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-stripe-button-switch-pro' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.open_stripe_checkout('pro', $t);
        }, this));

        $.targetIs(e, { tagSelector: '.NB-stripe-button-switch-archive_extra' }, _.bind(function ($t, $p) {
            e.preventDefault();
            this.open_stripe_checkout('archive_extra', $t);
        }, this));


        $.targetIs(e, { tagSelector: '.NB-provider-button-change' }, _.bind(function ($t, $p) {
            e.preventDefault();
            if (NEWSBLUR.Globals.active_provider == "stripe") {
                this.open_stripe_checkout('change_stripe', $t);
            } else if (NEWSBLUR.Globals.active_provider == "paypal") {
                this.open_paypal_checkout('change_paypal', $t);
            }
        }, this));

        $.targetIs(e, { tagSelector: '.NB-provider-button-premium' }, _.bind(function ($t, $p) {
            e.preventDefault();
            if (!NEWSBLUR.Globals.active_provider || NEWSBLUR.Globals.active_provider == "stripe") {
                this.open_stripe_checkout('premium', $t);
            } else if (NEWSBLUR.Globals.active_provider == "paypal") {
                this.open_paypal_checkout('premium', $t);
            }
        }, this));

        $.targetIs(e, { tagSelector: '.NB-provider-button-archive' }, _.bind(function ($t, $p) {
            e.preventDefault();
            if (!NEWSBLUR.Globals.active_provider || NEWSBLUR.Globals.active_provider == "stripe") {
                this.open_stripe_checkout('archive', $t);
            } else if (NEWSBLUR.Globals.active_provider == "paypal") {
                this.open_paypal_checkout('archive', $t);
            }
        }, this));

        $.targetIs(e, { tagSelector: '.NB-provider-button-archive_extra' }, _.bind(function ($t, $p) {
            e.preventDefault();
            if (!NEWSBLUR.Globals.active_provider || NEWSBLUR.Globals.active_provider == "stripe") {
                this.open_stripe_checkout('archive_extra', $t);
            } else if (NEWSBLUR.Globals.active_provider == "paypal") {
                this.open_paypal_checkout('archive_extra', $t);
            }
        }, this));

        $.targetIs(e, { tagSelector: '.NB-provider-button-pro' }, _.bind(function ($t, $p) {
            e.preventDefault();
            if (!NEWSBLUR.Globals.active_provider || NEWSBLUR.Globals.active_provider == "stripe") {
                this.open_stripe_checkout('pro', $t);
            } else if (NEWSBLUR.Globals.active_provider == "paypal") {
                this.open_paypal_checkout('pro', $t);
            }
        }, this));
    }

});
