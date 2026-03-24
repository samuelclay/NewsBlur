NEWSBLUR.ReaderReferrals = function (options) {
    var defaults = {
        'width': 740,
        'height': 'auto',
        'modal_container_class': 'NB-referrals-container',
        'onOpen': _.bind(function () {
            _.defer(_.bind(this.resize_modal, this));
        }, this)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderReferrals.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderReferrals.prototype.constructor = NEWSBLUR.ReaderReferrals;

_.extend(NEWSBLUR.ReaderReferrals.prototype, {

    runner: function () {
        this.make_modal();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));

        this.fetch_referral_data();
        this.fetch_gift_data();

        if (this.options.tab) {
            this.switch_tab(this.options.tab);
        }
    },

    resize_modal: function () {
        var $container = $('#simplemodal-container');
        var $modal = this.$modal;
        if (!$container.length || !$modal.length) return;

        // Temporarily remove height constraint to measure natural content height
        $container.css('height', 'auto');
        var content_height = $modal[0].scrollHeight;
        var window_height = $(window).height();
        var max_height = window_height - 48;

        var new_height = Math.min(content_height, max_height);

        $container.css({
            'height': new_height,
            'max-height': max_height
        });

        // Scroll if content exceeds window
        $('.simplemodal-wrap', $container).css({
            'overflow': content_height > max_height ? 'auto' : 'visible'
        });

        var top = Math.max(24, (window_height - new_height) / 2);
        $container.css('top', top);
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-referrals NB-modal' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-refer' }, 'Refer'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-gift' }, 'Gift')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Refer &amp; Gift',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),

            // = Refer Tab =
            $.make('div', { className: 'NB-tab NB-tab-refer NB-active' }, [
                // Hero banner
                $.make('div', { className: 'NB-referral-hero' }, [
                    $.make('div', { className: 'NB-referral-hero-illustration' }),
                    $.make('div', { className: 'NB-referral-hero-text' }, [
                        $.make('div', { className: 'NB-referral-hero-headline' }, 'Earn Free Premium'),
                        $.make('div', { className: 'NB-referral-hero-subtext' },
                            'Get a free year of premium for every person who subscribes. No cap \u2014 unlimited years of premium await.'
                        )
                    ])
                ]),

                $.make('fieldset', [
                    $.make('legend', 'Your Referral Link')
                ]),
                $.make('div', { className: 'NB-referral-url-container' }, [
                    $.make('input', {
                        className: 'NB-referral-url-input',
                        type: 'text',
                        readonly: 'readonly',
                        value: 'Loading...'
                    }),
                    $.make('div', {
                        className: 'NB-referral-copy-button NB-modal-submit-button NB-modal-submit-green'
                    }, 'Copy')
                ]),
                $.make('div', { className: 'NB-referral-url-description' },
                    'Share this link. When someone signs up and subscribes to premium, you earn a free year.'
                ),

                $.make('fieldset', [
                    $.make('legend', 'Your Referral Stats')
                ]),
                $.make('div', { className: 'NB-referral-stats' }, [
                    $.make('div', { className: 'NB-referral-stat' }, [
                        $.make('div', { className: 'NB-referral-stat-value NB-referral-stat-pending' }, '0'),
                        $.make('div', { className: 'NB-referral-stat-label' }, 'Pending')
                    ]),
                    $.make('div', { className: 'NB-referral-stat' }, [
                        $.make('div', { className: 'NB-referral-stat-value NB-referral-stat-converted' }, '0'),
                        $.make('div', { className: 'NB-referral-stat-label' }, 'Subscribed')
                    ]),
                    $.make('div', { className: 'NB-referral-stat' }, [
                        $.make('div', { className: 'NB-referral-stat-value NB-referral-stat-earned' }, '0'),
                        $.make('div', { className: 'NB-referral-stat-label NB-referral-stat-earned-label' }, 'Years Earned')
                    ])
                ]),

                $.make('fieldset', [
                    $.make('legend', 'Referral History')
                ]),
                $.make('div', { className: 'NB-referral-table-container' }, [
                    $.make('div', { className: 'NB-referral-empty' }, 'No referrals yet. Share your link to get started!')
                ])
            ]),

            // = Gift Tab =
            $.make('div', { className: 'NB-tab NB-tab-gift' }, [
                // Gift hero banner
                $.make('div', { className: 'NB-gift-hero' }, [
                    $.make('div', { className: 'NB-gift-hero-header' }, [
                        $.make('div', { className: 'NB-gift-hero-illustration' }),
                        $.make('div', { className: 'NB-gift-hero-headline' }, 'How Gifting Works')
                    ]),
                    $.make('div', { className: 'NB-gift-hero-steps' }, [
                        $.make('div', { className: 'NB-gift-hero-step' }, [
                            $.make('div', { className: 'NB-gift-hero-step-number' }, '1'),
                            $.make('div', { className: 'NB-gift-hero-step-text' }, [
                                $.make('b', 'Pick a tier & pay.'),
                                ' Choose Premium, Archive, or Pro and check out.'
                            ])
                        ]),
                        $.make('div', { className: 'NB-gift-hero-step' }, [
                            $.make('div', { className: 'NB-gift-hero-step-number' }, '2'),
                            $.make('div', { className: 'NB-gift-hero-step-text' }, [
                                $.make('b', 'Share the link.'),
                                ' Send the gift link to anyone.'
                            ])
                        ]),
                        $.make('div', { className: 'NB-gift-hero-step' }, [
                            $.make('div', { className: 'NB-gift-hero-step-number' }, '3'),
                            $.make('div', { className: 'NB-gift-hero-step-text' }, [
                                $.make('b', 'They redeem it.'),
                                ' One click and they have premium.'
                            ])
                        ]),
                        $.make('div', { className: 'NB-gift-hero-step NB-gift-hero-step-refund' }, [
                            $.make('div', { className: 'NB-gift-hero-step-number' }, '\u21A9'),
                            $.make('div', { className: 'NB-gift-hero-step-text' }, [
                                $.make('b', 'Not redeemed in 90 days?'),
                                ' You get a full refund, automatically.'
                            ])
                        ])
                    ])
                ]),

                $.make('fieldset', [
                    $.make('legend', 'Gift a Subscription')
                ]),
                $.make('div', { className: 'NB-gift-tier-selector' }, [
                    $.make('div', { className: 'NB-gift-tier NB-gift-tier-premium NB-active', 'data-tier': 'premium' }, [
                        $.make('div', { className: 'NB-gift-tier-name' }, 'Premium'),
                        $.make('div', { className: 'NB-gift-tier-price' }, '$36/year')
                    ]),
                    $.make('div', { className: 'NB-gift-tier NB-gift-tier-archive', 'data-tier': 'archive' }, [
                        $.make('div', { className: 'NB-gift-tier-name' }, 'Archive'),
                        $.make('div', { className: 'NB-gift-tier-price' }, '$99/year')
                    ]),
                    $.make('div', { className: 'NB-gift-tier NB-gift-tier-pro', 'data-tier': 'pro' }, [
                        $.make('div', { className: 'NB-gift-tier-name' }, 'Pro'),
                        $.make('div', { className: 'NB-gift-tier-price' }, '$29/month')
                    ])
                ]),

                (NEWSBLUR.Globals.is_staff ? $.make('div', { className: 'NB-gift-staff-option' }, [
                    $.make('label', [
                        $.make('input', { type: 'checkbox', className: 'NB-gift-staff-free', checked: 'checked' }),
                        ' Gift for free (staff)'
                    ])
                ]) : false),

                $.make('div', { className: 'NB-gift-form' }, [
                    $.make('div', { className: 'NB-gift-send-container NB-modal-submit' }, [
                        $.make('div', {
                            className: 'NB-gift-send-button NB-modal-submit-button NB-modal-submit-green'
                        }, 'Create Gift Link'),
                        $.make('div', { className: 'NB-gift-send-loading NB-modal-loading', style: 'display: none' })
                    ]),
                    $.make('div', { className: 'NB-gift-result', style: 'display: none' }, [
                        $.make('div', { className: 'NB-gift-result-label' }, 'Gift link created:'),
                        $.make('input', {
                            className: 'NB-gift-result-url',
                            type: 'text',
                            readonly: 'readonly'
                        }),
                        $.make('div', {
                            className: 'NB-gift-result-copy NB-modal-submit-button NB-modal-submit-green'
                        }, 'Copy')
                    ]),
                    $.make('div', { className: 'NB-gift-error', style: 'display: none' })
                ]),

                $.make('fieldset', [
                    $.make('legend', 'Gifts Sent')
                ]),
                $.make('div', { className: 'NB-gift-table-container' }, [
                    $.make('div', { className: 'NB-gift-empty' }, 'No gifts sent yet.')
                ])
            ])
        ]);
    },

    // ==========
    // = Data =
    // ==========

    fetch_referral_data: function () {
        this.model.make_request('/profile/referral_data', {}, _.bind(function (data) {
            this.populate_referral_data(data);
        }, this), null, { request_type: 'GET' });
    },

    fetch_gift_data: function () {
        this.model.make_request('/profile/gift_data', {}, _.bind(function (data) {
            this.populate_gift_data(data);
        }, this), null, { request_type: 'GET' });
    },

    populate_referral_data: function (data) {
        // Set URL
        var $url_input = $('.NB-referral-url-input', this.$modal);
        $url_input.val(data.referral_url);

        // Set stats
        $('.NB-referral-stat-pending', this.$modal).text(data.pending || 0);
        $('.NB-referral-stat-converted', this.$modal).text(data.converted || 0);
        var total_days = data.total_days_earned || 0;
        var is_pro = data.referrer_tier === 'pro';
        var earned_text, earned_label;
        if (is_pro) {
            var months = Math.floor(total_days / 30);
            earned_text = months;
            earned_label = 'Months Earned';
        } else {
            var years = Math.floor(total_days / 365);
            earned_text = years;
            earned_label = 'Years Earned';
        }
        $('.NB-referral-stat-earned', this.$modal).text(earned_text);
        $('.NB-referral-stat-earned-label', this.$modal).text(earned_label);

        // Populate table
        var $container = $('.NB-referral-table-container', this.$modal).empty();
        if (data.referrals && data.referrals.length) {
            var $table = $.make('table', { className: 'NB-referral-table' }, [
                $.make('thead', [
                    $.make('tr', [
                        $.make('th', 'Username'),
                        $.make('th', 'Date'),
                        $.make('th', 'Status'),
                        $.make('th', 'Credit')
                    ])
                ]),
                $.make('tbody')
            ]);
            _.each(data.referrals, function (ref) {
                var credit_text;
                if (ref.credit_days >= 365) {
                    var y = Math.floor(ref.credit_days / 365);
                    credit_text = y + ' year' + (y > 1 ? 's' : '');
                } else if (ref.credit_days >= 30) {
                    var m = Math.floor(ref.credit_days / 30);
                    credit_text = m + ' month' + (m > 1 ? 's' : '');
                } else if (ref.credit_days > 0) {
                    credit_text = ref.credit_days + ' days';
                } else {
                    credit_text = '-';
                }
                var status_class = ref.status === 'converted' ? 'NB-referral-status-converted' : 'NB-referral-status-pending';
                var status_label = ref.status === 'converted' ? 'subscribed' : 'pending';
                $('tbody', $table).append($.make('tr', [
                    $.make('td', ref.username),
                    $.make('td', ref.date || '-'),
                    $.make('td', [
                        $.make('span', { className: 'NB-referral-status ' + status_class }, status_label)
                    ]),
                    $.make('td', credit_text)
                ]));
            });
            $container.append($table);
        } else {
            $container.append($.make('div', { className: 'NB-referral-empty' },
                'No referrals yet. Share your link to get started!'));
        }
    },

    populate_gift_data: function (data) {
        var $container = $('.NB-gift-table-container', this.$modal).empty();
        if (data.gifts_sent && data.gifts_sent.length) {
            var $table = $.make('table', { className: 'NB-gift-table' }, [
                $.make('thead', [
                    $.make('tr', [
                        $.make('th', 'Tier'),
                        $.make('th', 'Date'),
                        $.make('th', 'Status'),
                        $.make('th', 'Link')
                    ])
                ]),
                $.make('tbody')
            ]);
            _.each(data.gifts_sent, function (gift) {
                var status = gift.refunded ? 'Refunded' : (gift.redeemed ? 'Redeemed' : 'Pending');
                var status_class = gift.redeemed ? 'NB-gift-status-redeemed' :
                    (gift.refunded ? 'NB-gift-status-refunded' : 'NB-gift-status-pending');
                var tier_name = { premium: 'Premium', archive: 'Archive', pro: 'Pro' }[gift.gift_tier] || 'Premium';
                $('tbody', $table).append($.make('tr', [
                    $.make('td', tier_name + (gift.is_staff_gift ? ' (staff)' : '')),
                    $.make('td', gift.created_date || '-'),
                    $.make('td', [
                        $.make('span', { className: 'NB-gift-status ' + status_class }, status)
                    ]),
                    $.make('td', [
                        $.make('a', { href: gift.gift_url, target: '_blank', className: 'NB-gift-link' }, 'Link')
                    ])
                ]));
            });
            $container.append($table);
        } else {
            $container.append($.make('div', { className: 'NB-gift-empty' }, 'No gifts sent yet.'));
        }
    },

    // ==========
    // = Actions =
    // ==========

    copy_to_clipboard: function (text) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text);
        } else {
            var $temp = $('<textarea>');
            $('body').append($temp);
            $temp.val(text).select();
            document.execCommand('copy');
            $temp.remove();
        }
    },

    send_gift: function () {
        var self = this;
        var $button = $('.NB-gift-send-button', this.$modal);
        var $loading = $('.NB-gift-send-loading', this.$modal);
        var $result = $('.NB-gift-result', this.$modal);
        var $error = $('.NB-gift-error', this.$modal);

        var gift_tier = $('.NB-gift-tier.NB-active', this.$modal).data('tier') || 'premium';

        $button.hide();
        $loading.show();
        $result.hide();
        $error.hide();

        this.model.make_request('/profile/gift_checkout', {
            gift_tier: gift_tier
        }, function (data) {
            $loading.hide();
            if (data.code === 1) {
                if (data.gift_url) {
                    // Staff gift - show URL directly
                    $result.show();
                    $('.NB-gift-result-url', self.$modal).val(data.gift_url);
                    $button.show();
                    self.fetch_gift_data();
                } else if (data.stripe_url) {
                    // Redirect to Stripe
                    window.location.href = data.stripe_url;
                }
            } else {
                $error.text(data.message || 'An error occurred.').show();
                $button.show();
            }
        }, function (data) {
            $loading.hide();
            $error.text('An error occurred. Please try again.').show();
            $button.show();
        });
    },

    handle_click: function (elem, e) {
        var self = this;

        // Tab switching
        $.targetIs(e, { tagSelector: '.NB-modal-tab-refer' }, function ($t, $p) {
            e.preventDefault();
            self.switch_tab('refer');
            _.defer(_.bind(self.resize_modal, self));
        });
        $.targetIs(e, { tagSelector: '.NB-modal-tab-gift' }, function ($t, $p) {
            e.preventDefault();
            self.switch_tab('gift');
            _.defer(_.bind(self.resize_modal, self));
        });

        // Copy referral URL
        $.targetIs(e, { tagSelector: '.NB-referral-copy-button' }, function ($t, $p) {
            e.preventDefault();
            var url = $('.NB-referral-url-input', self.$modal).val();
            self.copy_to_clipboard(url);
            $t.text('Copied!');
            _.delay(function () { $t.text('Copy'); }, 2000);
        });

        // Copy gift URL
        $.targetIs(e, { tagSelector: '.NB-gift-result-copy' }, function ($t, $p) {
            e.preventDefault();
            var url = $('.NB-gift-result-url', self.$modal).val();
            self.copy_to_clipboard(url);
            $t.text('Copied!');
            _.delay(function () { $t.text('Copy'); }, 2000);
        });

        // Select URL input on click
        $.targetIs(e, { tagSelector: '.NB-referral-url-input' }, function ($t, $p) {
            $t.select();
        });
        $.targetIs(e, { tagSelector: '.NB-gift-result-url' }, function ($t, $p) {
            $t.select();
        });

        // Tier selection
        $.targetIs(e, { tagSelector: '.NB-gift-tier' }, function ($t, $p) {
            e.preventDefault();
            $('.NB-gift-tier', self.$modal).removeClass('NB-active');
            $t.addClass('NB-active');
        });

        // Send gift
        $.targetIs(e, { tagSelector: '.NB-gift-send-button' }, function ($t, $p) {
            e.preventDefault();
            self.send_gift();
        });
    },

    handle_change: function (elem, e) {
    }

});
