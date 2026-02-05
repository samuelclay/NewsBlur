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
        this.make_modal();
        this.make_paypal_button();
        this.open_modal();
        this.$modal.bind('mousedown', $.rescope(this.handle_mousedown, this));
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
                    'Upgrade to Premium',
                    $.make('div', { className: 'NB-icon-dropdown' })
                ]),
                (NEWSBLUR.Globals.is_premium_trial && $.make('div', { className: 'NB-premium-trial-badge' }, [
                    $.make('strong', NEWSBLUR.Globals.trial_days_remaining + ' day' + (NEWSBLUR.Globals.trial_days_remaining === 1 ? '' : 's')),
                    ' left in your premium trial'
                ]))
            ]),
            $.make('div', { className: 'NB-premium-tiers' }, [
                // Premium Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-premium' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name' }, 'Premium'),
                        $.make('div', { className: 'NB-premium-tier-price' }, [
                            $.make('span', { className: 'NB-premium-tier-price-amount' }, '$36'),
                            $.make('span', { className: 'NB-premium-tier-price-period' }, '/year')
                        ])
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-premium' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, 'Everything in Free, plus:'),
                        $.make('li', { className: 'NB-1' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Follow up to 1,024 sites'
                        ]),
                        $.make('li', { className: 'NB-2' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Sites updated up to 5x more often'
                        ]),
                        $.make('li', { className: 'NB-3' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'River of News (reading by folder)'
                        ]),
                        $.make('li', { className: 'NB-4' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Search sites and folders'
                        ]),
                        $.make('li', { className: 'NB-5' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Save stories with searchable tags'
                        ]),
                        $.make('li', { className: 'NB-6' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Privacy options for your blurblog'
                        ]),
                        $.make('li', { className: 'NB-7' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Custom RSS feeds for saved stories'
                        ]),
                        $.make('li', { className: 'NB-8' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Text view extracts the story'
                        ]),
                        $.make('li', { className: 'NB-9' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Discover related stories and sites'
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_tier_buttons('premium', $creditcards.clone())
                    ])
                ]),
                // Archive Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-archive' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name' }, 'Premium Archive'),
                        $.make('div', { className: 'NB-premium-tier-price' }, [
                            $.make('span', { className: 'NB-premium-tier-price-amount' }, '$99'),
                            $.make('span', { className: 'NB-premium-tier-price-period' }, '/year')
                        ])
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-archive' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, 'Everything in Premium, plus:'),
                        $.make('li', { className: 'NB-1' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Follow up to 4,096 sites'
                        ]),
                        $.make('li', { className: 'NB-2' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Choose when stories are marked as read'
                        ]),
                        $.make('li', { className: 'NB-3' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Customize auto-read by site or folder'
                        ]),
                        $.make('li', { className: 'NB-4' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Every story archived and searchable forever'
                        ]),
                        $.make('li', { className: 'NB-5' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Feeds back-filled for complete archive'
                        ]),
                        $.make('li', { className: 'NB-6' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Train stories on full text content'
                        ]),
                        $.make('li', { className: 'NB-7' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Discover related stories across your archive'
                        ]),
                        $.make('li', { className: 'NB-8' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Export trained stories from folders'
                        ]),
                        $.make('li', { className: 'NB-9' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Stories can stay unread forever'
                        ]),
                        $.make('li', { className: 'NB-10' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Ask AI questions about stories'
                        ]),
                        $.make('li', { className: 'NB-11' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Filter stories by date range'
                        ]),
                        $.make('li', { className: 'NB-12' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Apply training across a folder'
                        ]),
                        $.make('li', { className: 'NB-13' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Apply training globally'
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_tier_buttons('archive', $creditcards.clone())
                    ])
                ]),
                // Pro Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-pro' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-name' }, 'Premium Pro'),
                        $.make('div', { className: 'NB-premium-tier-price' }, [
                            $.make('span', { className: 'NB-premium-tier-price-amount' }, '$29'),
                            $.make('span', { className: 'NB-premium-tier-price-period' }, '/month')
                        ])
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-pro' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, 'Everything in Archive, plus:'),
                        $.make('li', { className: 'NB-1' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Follow up to 10,000 sites'
                        ]),
                        $.make('li', { className: 'NB-2' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'All feeds fetched every 5-15 minutes'
                        ]),
                        $.make('li', { className: 'NB-3' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Train stories with regular expressions'
                        ]),
                        $.make('li', { className: 'NB-4' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Priority support'
                        ]),
                        $.make('li', { className: 'NB-premium-tier-upcoming-header' }, 'Coming soon:'),
                        $.make('li', { className: 'NB-upcoming NB-5' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Natural language filters'
                        ]),
                        $.make('li', { className: 'NB-upcoming NB-6' }, [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            'Natural language search'
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
                        $.make('div', { className: 'NB-premium-tier-name' }, 'Free')
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-free' }, [
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Follow up to 64 sites')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Real-time RSS updates')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Train stories by author, tag, title')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Public blurblog sharing')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Save stories for later')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'iOS & Android apps')
                        ])
                    ]),
                    (NEWSBLUR.Globals.is_premium_trial && $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_free_tier_status()
                    ]))
                ]),
                // Self-Hosted Tier
                $.make('div', { className: 'NB-premium-tier NB-premium-tier-selfhosted' }, [
                    $.make('div', { className: 'NB-premium-tier-header' }, [
                        $.make('div', { className: 'NB-premium-tier-label' }, 'DIY'),
                        $.make('div', { className: 'NB-premium-tier-name' }, 'Self-Hosted')
                    ]),
                    $.make('ul', { className: 'NB-premium-tier-features NB-premium-tier-features-selfhosted' }, [
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Run your own NewsBlur')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Complete data ownership')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'One command with Docker')
                        ]),
                        $.make('li', [
                            $.make('div', { className: 'NB-premium-bullet-image' }),
                            $.make('span', 'Customize with Claude Code')
                        ])
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        $.make('a', {
                            className: 'NB-premium-selfhosted-github NB-modal-submit-button NB-modal-submit-grey',
                            href: 'https://github.com/samuelclay/NewsBlur',
                            target: '_blank'
                        }, [
                            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/github-mark.svg', className: 'NB-github-icon' }),
                            'View on GitHub'
                        ])
                    ])
                ])
            ])
        ]);
    },

    make_tier_buttons: function (plan, $creditcards) {
        var is_trial = NEWSBLUR.Globals.is_premium_trial;
        var has_renewal = NEWSBLUR.Globals.premium_renewal;

        // Determine user's current tier level (0=free, 1=premium, 2=archive, 3=pro)
        var user_tier = this.get_user_tier();
        var plan_tier = this.get_plan_tier(plan);

        var is_current_plan = (plan === 'premium' && NEWSBLUR.Globals.is_premium && !NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro) ||
            (plan === 'archive' && NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro) ||
            (plan === 'pro' && NEWSBLUR.Globals.is_pro);

        // Current plan with active renewal - show status
        if (is_current_plan && !is_trial && has_renewal) {
            return $.make('div', { className: 'NB-premium-tier-status' }, [
                $.make('div', { className: 'NB-premium-tier-status-active' }, [
                    $.make('div', { className: 'NB-premium-tier-status-icon' }),
                    $.make('div', { className: 'NB-premium-tier-status-text' }, 'Your ' + this.plan_name(plan).toLowerCase() + ' subscription is active')
                ]),
                $.make('div', { className: 'NB-provider-button-change NB-modal-submit-button NB-modal-submit-grey' }, 'Change billing details')
            ]);
        }

        // Current plan without renewal - show restart button
        if (is_current_plan && !is_trial && !has_renewal) {
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $.make('div', { className: 'NB-premium-tier-status-active' }, [
                    $.make('div', { className: 'NB-premium-tier-status-icon' }),
                    $.make('div', { className: 'NB-premium-tier-status-text' }, 'Your ' + this.plan_name(plan).toLowerCase() + ' subscription is active')
                ]),
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, 'Restart your ' + this.plan_name(plan).toLowerCase() + ' subscription'),
                this.make_paypal_alternate(plan)
            ]);
        }

        // Trial user viewing their trial tier - show trial status and upgrade button
        if (is_trial && is_current_plan) {
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $.make('div', { className: 'NB-premium-tier-trial-status' }, [
                    'You are trialing this plan'
                ]),
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, 'Upgrade to ' + this.plan_name(plan)),
                this.make_paypal_alternate(plan)
            ]);
        }

        // Higher tier user viewing lower tier - show "includes everything" and switch option
        if (!is_trial && user_tier > plan_tier && user_tier > 0) {
            var current_plan_name = this.plan_name(this.get_plan_name_from_tier(user_tier));
            return $.make('div', { className: 'NB-premium-tier-status' }, [
                $.make('div', { className: 'NB-premium-tier-status-included' }, [
                    $.make('div', { className: 'NB-premium-tier-status-icon' }),
                    $.make('div', { className: 'NB-premium-tier-status-text' }, 'Your ' + current_plan_name.toLowerCase() + ' subscription includes everything above')
                ]),
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-grey'
                }, 'Switch to ' + this.plan_name(plan).toLowerCase())
            ]);
        }

        // Lower tier user viewing higher tier, or free/trial user - show upgrade button
        return $.make('div', { className: 'NB-premium-tier-buttons' }, [
            $creditcards,
            $.make('div', {
                className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
            }, 'Upgrade to ' + this.plan_name(plan)),
            this.make_paypal_alternate(plan),
            this.make_prorate_message(plan)
        ]);
    },

    get_user_tier: function () {
        // Returns user's current tier level: 0=free/trial, 1=premium, 2=archive, 3=pro
        if (NEWSBLUR.Globals.is_pro) return 3;
        if (NEWSBLUR.Globals.is_archive) return 2;
        if (NEWSBLUR.Globals.is_premium && !NEWSBLUR.Globals.is_premium_trial) return 1;
        return 0;
    },

    get_plan_tier: function (plan) {
        // Returns tier level for a plan: 1=premium, 2=archive, 3=pro
        if (plan === 'pro') return 3;
        if (plan === 'archive') return 2;
        if (plan === 'premium') return 1;
        return 0;
    },

    get_plan_name_from_tier: function (tier) {
        if (tier === 3) return 'pro';
        if (tier === 2) return 'archive';
        if (tier === 1) return 'premium';
        return 'free';
    },

    plan_name: function (plan) {
        if (plan === 'premium') return 'Premium';
        if (plan === 'archive') return 'Premium Archive';
        if (plan === 'pro') return 'Premium Pro';
        return plan;
    },

    make_paypal_alternate: function (plan) {
        if (NEWSBLUR.Globals.active_provider === 'paypal') {
            return $.make('div', { className: 'NB-provider-alternate' }, [
                $.make('div', {
                    className: 'NB-stripe-button-switch-' + plan + ' NB-modal-submit-button NB-modal-submit-grey'
                }, 'Switch to Credit Card')
            ]);
        }
        return $.make('div', { className: 'NB-provider-alternate' }, [
            $.make('span', { className: 'NB-provider-text' }, 'or subscribe with '),
            $.make('div', { className: 'NB-splash-link NB-paypal-button', 'data-plan': plan }, '')
        ]);
    },

    make_prorate_message: function (plan) {
        if (!_.contains(['paypal', 'stripe'], NEWSBLUR.Globals.active_provider)) return;
        if (plan === 'premium') return; // No prorate for base premium
        return $.make('div', { className: 'NB-premium-prorate-message' },
            'Your subscription will be prorated'
        );
    },

    make_free_tier_status: function () {
        var is_trial = NEWSBLUR.Globals.is_premium_trial;

        // Trial user - show when they'll become free
        if (is_trial) {
            var days = NEWSBLUR.Globals.trial_days_remaining;
            return $.make('div', { className: 'NB-premium-tier-free-status' }, [
                $.make('div', { className: 'NB-premium-tier-free-trial-notice' }, [
                    'In ' + days + ' day' + (days === 1 ? '' : 's') + ', your premium trial ends ',
                    'and you\'ll return to Free'
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
                var plan_id;
                if (NEWSBLUR.Globals.debug) {
                    if (plan == 'premium') plan_id = "P-4RV31836YD8080909MHZROJY";
                    else if (plan == 'archive') plan_id = "P-2EG40290653242115MHZROQQ";
                    else if (plan == 'pro') plan_id = "P-1AE0908250058421JM565SVY";
                } else {
                    if (plan == 'premium') plan_id = "P-48R22630SD810553FMHZONIY";
                    else if (plan == 'archive') plan_id = "P-5JM46230U31841226MHZOMZY";
                    else if (plan == 'pro') plan_id = "P-1AE0908250058421JM565SVY";
                }
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
                        if (plan == "archive") {
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
        $button.text("Loading checkout...");
        $button.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true);

        $.redirectPost("/profile/switch_stripe_subscription", { "plan": plan });
    },

    open_paypal_checkout: function (plan, $button) {
        if ($button.hasClass('NB-disabled')) return;
        $button.attr('disabled', 'disabled');
        $button.text("Loading PayPal...");
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
