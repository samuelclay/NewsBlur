NEWSBLUR.ReaderPremiumUpgrade = function (options) {
    options = options || {};
    var defaults = {
        'width': 920,
        'height': 680,
        'onOpen': _.bind(function () {
            this.resize_modal();
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
                    $.make('ul', { className: 'NB-premium-tier-features' }, [
                        $.make('li', 'Enable every site'),
                        $.make('li', 'Sites updated up to 5x more often'),
                        $.make('li', 'River of News (reading by folder)'),
                        $.make('li', 'Search sites and folders'),
                        $.make('li', 'Save stories with searchable tags'),
                        $.make('li', 'Privacy options for your blurblog'),
                        $.make('li', 'Custom RSS feeds for saved stories'),
                        $.make('li', 'Text view extracts the story'),
                        $.make('li', 'Discover related stories and sites'),
                        $.make('li', [
                            'Feed Lyric the hungry hound for ',
                            $.make('span', { className: 'NB-premium-hungry-dog' }, '6 days'),
                            $.make('img', { className: 'NB-premium-dog-image', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/lyric.jpg' })
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
                    $.make('ul', { className: 'NB-premium-tier-features' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, 'Everything in Premium, plus:'),
                        $.make('li', 'Choose when stories are marked as read'),
                        $.make('li', 'Every story archived and searchable forever'),
                        $.make('li', 'Feeds back-filled for complete archive'),
                        $.make('li', 'Train stories on full text content'),
                        $.make('li', 'Discover related stories across your archive'),
                        $.make('li', 'Export trained stories from folders'),
                        $.make('li', 'Stories can stay unread forever'),
                        $.make('li', 'Ask AI questions about stories')
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
                    $.make('ul', { className: 'NB-premium-tier-features' }, [
                        $.make('li', { className: 'NB-premium-tier-includes' }, 'Everything in Archive, plus:'),
                        $.make('li', 'All feeds fetched every 5 minutes'),
                        $.make('li', 'Priority support')
                    ]),
                    $.make('div', { className: 'NB-premium-tier-actions' }, [
                        this.make_tier_buttons('pro', $creditcards.clone())
                    ])
                ])
            ])
        ]);
    },

    make_tier_buttons: function (plan, $creditcards) {
        var is_current_plan = (plan === 'premium' && NEWSBLUR.Globals.is_premium && !NEWSBLUR.Globals.is_archive && !NEWSBLUR.Globals.is_pro) ||
                              (plan === 'archive' && NEWSBLUR.Globals.is_archive) ||
                              (plan === 'pro' && NEWSBLUR.Globals.is_pro);

        var is_trial = NEWSBLUR.Globals.is_premium_trial;
        var has_renewal = NEWSBLUR.Globals.premium_renewal;
        var active_provider = NEWSBLUR.Globals.active_provider;

        if (is_current_plan && !is_trial && has_renewal) {
            // Already subscribed with active renewal - show "Change billing details"
            return $.make('div', { className: 'NB-premium-tier-status' }, [
                $.make('div', { className: 'NB-premium-tier-status-icon' }),
                $.make('div', { className: 'NB-premium-tier-status-text' }, 'You have a ' + this.plan_name(plan).toLowerCase() + ' subscription'),
                $.make('div', { className: 'NB-provider-button-change NB-modal-submit-button NB-modal-submit-grey' }, 'Change billing details')
            ]);
        } else if (is_current_plan && !is_trial && !has_renewal) {
            // Subscribed but needs renewal - show "Restart your X subscription"
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, 'Restart your ' + this.plan_name(plan).toLowerCase() + ' subscription'),
                this.make_paypal_alternate(plan)
            ]);
        } else if (is_trial && is_current_plan) {
            // Trial user on this tier - show trial status and upgrade button
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $.make('div', { className: 'NB-premium-tier-trial-status' }, [
                    'Your current plan · ',
                    $.make('strong', NEWSBLUR.Globals.trial_days_remaining + ' days left')
                ]),
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, 'Upgrade to ' + this.plan_name(plan)),
                this.make_paypal_alternate(plan)
            ]);
        } else {
            // New upgrade or trial user upgrading to different tier
            return $.make('div', { className: 'NB-premium-tier-buttons' }, [
                $creditcards,
                $.make('div', {
                    className: 'NB-provider-button-' + plan + ' NB-modal-submit-button NB-modal-submit-green'
                }, 'Upgrade to ' + this.plan_name(plan)),
                this.make_paypal_alternate(plan),
                this.make_prorate_message(plan)
            ]);
        }
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
            'Your existing subscription will be prorated'
        );
    },

    make_paypal_button: function () {
        jQuery.ajax({
            type: "GET",
            url: NEWSBLUR.URLs.paypal_checkout_js,
            dataType: "script",
            cache: true
        }).done(_.bind(function () {
            $(".NB-paypal-button").each(function () {
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
                }).render('#' + random_id);
            });
        }, this));
    },

    resize_modal: function () {
        // Ensure modal fits in viewport
        var container_height = this.$modal.parent().height();
        var content_height = this.$modal.height();
        if (content_height > container_height - 40) {
            this.$modal.css({ 'max-height': container_height - 40, 'overflow-y': 'auto' });
        }
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
