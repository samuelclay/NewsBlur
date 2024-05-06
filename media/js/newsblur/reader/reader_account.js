NEWSBLUR.ReaderAccount = function (options) {
    var defaults = {
        'width': 700,
        'animate_email': false,
        'change_password': false,
        'onOpen': _.bind(function () {
            this.animate_fields();
            $(window).trigger('resize.simplemodal');
        }, this)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;

    this.runner();
};

NEWSBLUR.ReaderAccount.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderAccount.prototype.constructor = NEWSBLUR.ReaderAccount;

_.extend(NEWSBLUR.ReaderAccount.prototype, {

    runner: function () {
        this.options.onOpen = _.bind(function () {
            // $(window).resize();
        }, this);
        this.make_modal();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.handle_change();
        this.select_preferences();

        this.fetch_payment_history();
        this.render_dates();

        if (this.options.tab) {
            this.switch_tab(this.options.tab);
        }
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal-account NB-modal' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-account' }, 'Account'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-premium' }, 'Payments'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-emails' }, 'Emails'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-custom' }, 'Custom CSS/JavaScript')
            ]),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Account',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('form', { className: 'NB-preferences-form' }, [
                $.make('div', { className: 'NB-tab NB-tab-account NB-active' }, [
                    $.make('div', { className: 'NB-preference NB-preference-username' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-preference-option' }, [
                                $.make('input', { id: 'NB-preference-username', type: 'text', name: 'username', value: NEWSBLUR.Globals.username })
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            $.make('label', { 'for': 'NB-preference-username' }, 'Username'),

                            $.make('div', { className: 'NB-preference-error' })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-email' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-preference-option' }, [
                                $.make('input', { id: 'NB-preference-email', type: 'text', name: 'email', value: NEWSBLUR.Globals.email })
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            $.make('label', { 'for': 'NB-preference-email' }, 'Email address'),

                            $.make('div', { className: 'NB-preference-error' })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-password' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-preference-option', style: (this.options.change_password ? 'opacity: .2' : '') }, [
                                $.make('label', { 'for': 'NB-preference-password-old' }, 'Old password'),
                                $.make('input', { id: 'NB-preference-password-old', type: 'password', name: 'old_password', value: '' })
                            ]),
                            $.make('div', { className: 'NB-preference-option' }, [
                                $.make('label', { 'for': 'NB-preference-password-new' }, 'New password'),
                                $.make('input', { id: 'NB-preference-password-new', type: 'password', name: 'new_password', value: '' })
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Change password',
                            $.make('div', { className: 'NB-preference-error' })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-opml' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('a', { className: 'NB-modal-submit-button NB-modal-submit-green', href: NEWSBLUR.URLs['opml-export'] }, 'Download OPML')
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Backup your sites',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'Download this XML file as a backup')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-delete' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-preference-saved-stories-date' }),
                            $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-account-delete-saved-stories' }, 'Delete my saved stories')
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Erase your saved stories'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-delete' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-account-delete-all-sites' }, 'Delete all of my sites')
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Erase yourself',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'Friendly note: You will be emailed a backup of your sites')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-delete' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('a', { className: 'NB-modal-submit-button NB-modal-submit-red', href: NEWSBLUR.URLs['delete-account'] }, 'Delete my account')
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Erase yourself permanently',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'Warning: This is actually permanent')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-premium' }, [
                    $.make('div', { className: 'NB-preference NB-preference-premium' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            (!NEWSBLUR.Globals.is_premium && $.make('div', [
                                $.make('div', { style: 'margin-bottom: 12px;' }, [
                                    'You have a ',
                                    $.make('b', 'free account'),
                                    '.'
                                ]),
                                $.make('a', {
                                    className: 'NB-modal-submit-button NB-modal-submit-green NB-account-premium-modal'
                                }, 'Upgrade to a Premium account')
                            ])),
                            (NEWSBLUR.Globals.is_premium && $.make('div', [
                                'Thank you! You have a ',
                                (NEWSBLUR.Globals.is_pro && $.make('b', 'premium pro account')),
                                (!NEWSBLUR.Globals.is_pro && NEWSBLUR.Globals.is_archive && $.make('b', 'premium archive account')),
                                (!NEWSBLUR.Globals.is_pro && !NEWSBLUR.Globals.is_archive && NEWSBLUR.Globals.is_premium && $.make('b', 'premium account')),
                                '.',
                                (!NEWSBLUR.Globals.is_archive && $.make('a', {
                                    className: 'NB-modal-submit-button NB-modal-submit-green NB-account-premium-modal NB-block'
                                }, 'Upgrade to a Premium Archive account'))
                            ]))
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Premium status'
                        ])
                    ]),
                    (NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-preference NB-preference-premium-renew' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: "NB-premium-renewal-details-container" }, this.make_premium_renewal_details()),
                            $.make('div', { className: 'NB-block NB-premium-expire-container' }, this.make_premium_expire()),
                            $.make('a', { href: '#', className: 'NB-block NB-account-premium-renew NB-modal-submit-button NB-modal-submit-green' }, 'Change your credit card')
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Premium details'
                        ])
                    ])),
                    $.make('div', { className: 'NB-preference NB-preference-premium-history' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('ul', { className: 'NB-account-payments' }, [
                                $.make('li', { className: 'NB-payments-loading' }, 'Loading...')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Payment history'
                        ])
                    ]),
                    (NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-preference NB-preference-premium-cancel' }, [
                        $.make('div', { className: 'NB-preference-options NB-premium-renewal-container' }, this.make_premium_renewal()),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Premium renewal'
                        ])
                    ]))
                ]),
                $.make('div', { className: 'NB-tab NB-tab-emails' }, [
                    $.make('div', { className: 'NB-preference NB-preference-emails' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-emails-1', type: 'radio', name: 'send_emails', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-emails-1' }, [
                                    'Email replies, re-shares, and new followers'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-emails-2', type: 'radio', name: 'send_emails', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-emails-2' }, [
                                    'Never ever send me an email'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Emails'
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-custom' }, [
                    $.make('fieldset', [
                        $.make('legend', 'Custom CSS'),
                        $.make('div', { className: 'NB-modal-section NB-profile-editor-blurblog-custom-css' }, [
                            $.make('textarea', { 'className': 'NB-account-custom-css', name: 'custom_css' }, _.string.trim($("#NB-custom-css").text()))
                        ])
                    ]),
                    $.make('fieldset', [
                        $.make('legend', 'Custom JavaScript'),
                        $.make('div', { className: 'NB-modal-section NB-profile-editor-blurblog-custom-js' }, [
                            $.make('textarea', { 'className': 'NB-account-custom-javascript', name: 'custom_js' }, _.string.trim($("#NB-custom-js").text()))
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-button NB-modal-submit-green NB-disabled', value: 'Change what you like above...' })
                ])
            ]).bind('submit', function (e) {
                e.preventDefault();
                self.save_account_settings();
                return false;
            })
        ]);
    },

    render_dates: function () {
        var now = new Date();
        var this_year = now.getFullYear();
        var this_month = now.getMonth();
        var this_day = now.getDate();

        var $dates = $(".NB-preference-saved-stories-date", this.$modal);

        var $months = $.make('select', { name: 'month' });
        _.each(NEWSBLUR.utils.monthNames, function (name, i) {
            var $option = $.make('option', { value: i + "" }, name);
            if (this_month == i) $option.prop('selected', true);
            $months.append($option);
        });

        var $days = $.make('select', { name: 'day' });
        _.each(_.range(0, 31), function (name, i) {
            var $option = $.make('option', { value: i + 1 + "" }, i + 1);
            if (this_day == i + 1) $option.prop('selected', true);
            $days.append($option);
        });

        var $years = $.make('select', { name: 'year' });
        _.each(_.range(2009, this_year + 1), function (name, i) {
            var $option = $.make('option', { value: name + "" }, name);
            if (this_year == name) $option.prop('selected', true);
            $years.append($option);
        });

        $dates.append($.make('span', 'Older than: '));
        $dates.append($months);
        $dates.append($days);
        $dates.append($years);
    },

    animate_fields: function () {
        if (this.options.animate_email) {
            this.switch_tab('emails');
            _.delay(_.bind(function () {
                var $emails = $('.NB-preference-emails', this.$modal);
                var bgcolor = $emails.css('backgroundColor');
                $emails.css('backgroundColor', bgcolor).animate({
                    'backgroundColor': 'orange'
                }, {
                    'queue': false,
                    'duration': 1200,
                    'easing': 'easeInQuad',
                    'complete': function () {
                        $emails.animate({
                            'backgroundColor': bgcolor
                        }, {
                            'queue': false,
                            'duration': 650,
                            'easing': 'easeOutQuad'
                        });
                    }
                });
            }, this), 200);
        } else if (this.options.change_password) {
            _.delay(_.bind(function () {
                var $emails = $('.NB-preference-password', this.$modal);
                var bgcolor = $emails.css('backgroundColor');
                $emails.css('backgroundColor', bgcolor).animate({
                    'backgroundColor': 'orange'
                }, {
                    'queue': false,
                    'duration': 1200,
                    'easing': 'easeInQuad',
                    'complete': function () {
                        $emails.animate({
                            'backgroundColor': bgcolor
                        }, {
                            'queue': false,
                            'duration': 650,
                            'easing': 'easeOutQuad'
                        });
                    }
                });
            }, this), 200);
        }

    },

    close_and_load_premium: function (options) {
        options = _.extend({}, { 'premium_only': true }, options);
        this.close(function () {
            NEWSBLUR.reader.open_feedchooser_modal(options);
        });
    },

    cancel_premium: function () {
        var $cancel = $(".NB-account-premium-cancel", this.$modal);
        $cancel.attr('disabled', 'disabled');
        $cancel.removeClass('NB-modal-submit-red');
        $cancel.addClass('NB-modal-submit-grey');
        $cancel.text("Cancelling...");

        var post_cancel = function (message) {
            $cancel.remove();
            $(".NB-account-payment.NB-scheduled").addClass('NB-canceled');
            $(".NB-preference-premium-cancel .NB-error").remove();
            $(".NB-preference-premium-cancel .NB-preference-options").append($.make("div", {
                className: "NB-error"
            }, message).fadeIn(500).css('display', 'block'));
        };

        this.model.cancel_premium_subscription(_.bind(function (data) {
            NEWSBLUR.Globals.premium_renewal = false;
            post_cancel("Your subscription will no longer automatically renew.");
        }, this), _.bind(function (data) {
            NEWSBLUR.Globals.premium_renewal = false;
            post_cancel(data.message || "You have no active subscriptions.");
        }, this));
    },

    delete_all_sites: function () {
        var $link = $(".NB-account-delete-all-sites", this.$modal);

        if (window.confirm("Positive you want to delete everything?")) {
            NEWSBLUR.assets.delete_all_sites(_.bind(function () {
                NEWSBLUR.assets.load_feeds();
                $link.replaceWith($.make('div', 'Everything has been deleted.'));
            }, this), _.bind(function () {
                $link.replaceWith($.make('div', { className: 'NB-error' }, 'There was a problem deleting your sites.'));
            }, this));
        }
    },

    delete_saved_stories: function () {
        var $link = $(".NB-account-delete-saved-stories", this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        var year = parseInt($("select[name=year]", this.$modal).val(), 10);
        var month = parseInt($("select[name=month]", this.$modal).val(), 10);
        var day = parseInt($("select[name=day]", this.$modal).val(), 10);

        var timestamp = (new Date(year, month, day)).getTime() / 1000;
        if (window.confirm("Positive you want to delete your saved stories?")) {
            $loading.addClass('NB-active');
            $link.attr('disabled', 'disabled');
            $link.text("Deleting...");

            NEWSBLUR.assets.delete_saved_stories(timestamp, _.bind(function (data) {
                $loading.removeClass('NB-active');
                NEWSBLUR.reader.update_starred_count();
                $link.replaceWith($.make('div', Inflector.pluralize('story', data.stories_deleted, true) + ' ' + Inflector.pluralize('has', data.stories_deleted) +
                    ' been deleted.'));
            }, this), _.bind(function () {
                $loading.removeClass('NB-active');
                NEWSBLUR.reader.update_starred_count();
                $link.replaceWith($.make('div', { className: 'NB-error' }, 'There was a problem deleting your saved stories.')).show();
            }, this));
        }
    },

    handle_cancel: function () {
        var $cancel = $('.NB-modal-cancel', this.$modal);

        $cancel.click(function (e) {
            e.preventDefault();
            $.modal.close();
        });
    },

    select_preferences: function () {
        var pref = this.model.preference;
        $('input[name=send_emails]', this.$modal).each(function () {
            if ($(this).val() == "" + pref('send_emails')) {
                $(this).prop('checked', true);
                return false;
            }
        });
    },

    serialize_preferences: function () {
        var preferences = {};

        $('input[type=radio]:checked, select, textarea, input[type=text], input[type=password]', this.$modal).each(function () {
            var name = $(this).attr('name');
            var preference = preferences[name] = $(this).val();
            if (preference == 'true') preferences[name] = true;
            else if (preference == 'false') preferences[name] = false;
        });
        $('input[type=checkbox]', this.$modal).each(function () {
            preferences[$(this).attr('name')] = $(this).is(':checked');
        });

        return preferences;
    },

    save_account_settings: function () {
        var self = this;
        var form = this.serialize_preferences();
        $('.NB-preference-error', this.$modal).text('');
        $('input[type=submit]', this.$modal).val('Saving...').attr('disabled', true).addClass('NB-disabled');

        NEWSBLUR.log(["form['send_emails']", form['send_emails']]);
        this.model.preference('send_emails', form['send_emails']);
        this.model.save_account_settings(form, function (data) {
            if (data.code == -1) {
                $('.NB-preference-username .NB-preference-error', this.$modal).text(data.message);
                return self.disable_save();
            } else if (data.code == -2) {
                $('.NB-preference-email .NB-preference-error', this.$modal).text(data.message);
                return self.disable_save();
            } else if (data.code == -3) {
                $('.NB-preference-password .NB-preference-error', this.$modal).text(data.message);
                return self.disable_save();
            }

            NEWSBLUR.Globals.username = data.payload.username;
            NEWSBLUR.Globals.email = data.payload.email;
            $('.NB-module-account-username').text(NEWSBLUR.Globals.username);
            $('.NB-feeds-header-user-name').text(NEWSBLUR.Globals.username);
            self.close();
        });
    },

    make_premium_expire: function () {
        return $.make('div', [
            $.make('span', { className: 'NB-raquo' }, '&raquo;'),
            ' ',
            (NEWSBLUR.Globals.premium_expire && NEWSBLUR.utils.format_date(NEWSBLUR.Globals.premium_expire)),
            (!NEWSBLUR.Globals.premium_expire && $.make('b', "Never gonna expire. Congrats!"))
        ]);
    },

    make_premium_renewal: function () {
        return $.make('div', [
            (NEWSBLUR.Globals.premium_renewal && $.make('a', { href: '#', className: 'NB-block NB-account-premium-cancel NB-modal-submit-button NB-modal-submit-red' }, 'Cancel subscription renewal')),
            (!NEWSBLUR.Globals.premium_renewal && "Your subscription is no longer active."),
            (!NEWSBLUR.Globals.premium_renewal && $.make('a', { href: '#', className: 'NB-block NB-account-premium-renew NB-modal-submit-button NB-modal-submit-green' }, 'Restart your subscription'))
        ]);
    },

    make_premium_renewal_details: function () {
        return $.make('div', [
            (NEWSBLUR.Globals.premium_renewal && $.make('div', { className: 'NB-block' }, 'Your premium account is paid until:')),
            (!NEWSBLUR.Globals.premium_renewal && $.make('div', { className: 'NB-block' }, 'Your premium account will downgrade on:'))
        ]);
    },

    fetch_payment_history: function () {
        this.model.fetch_payment_history(NEWSBLUR.Globals.user_id, _.bind(function (data) {
            var $history = $('.NB-account-payments', this.$modal).empty();

            if (NEWSBLUR.Globals.premium_renewal != data.premium_renewal) {
                NEWSBLUR.Globals.premium_renewal = data.premium_renewal;
                $(".NB-premium-renewal-container", this.$modal).html(this.make_premium_renewal());
                $(".NB-premium-renewal-details-container", this.$modal).html(this.make_premium_renewal_details());
            }

            if (NEWSBLUR.Globals.premium_expire != data.premium_expire) {
                if (data.premium_expire) {
                    NEWSBLUR.Globals.premium_expire = new Date(data.premium_expire);
                    $(".NB-premium-expire-container", this.$modal).html(this.make_premium_expire());
                }
            }

            if (!data.payments || !data.payments.length) {
                $history.append($.make('li', { className: 'NB-account-payment' }, [
                    $.make('i', 'No payments found.')
                ]));
            } else {
                if (data.next_invoice) {
                    data.payments.splice(0, 0, data.next_invoice);
                }
                _.each(data.payments, function (payment) {
                    var date = new Date(payment.payment_date);
                    $history.append($.make('li', { className: 'NB-account-payment ' + (payment.scheduled ? ' NB-scheduled' : '') + (payment.refunded ? ' NB-refunded' : '') }, [
                        $.make('div', { className: 'NB-account-payment-date' }, date.format("F d, Y")),
                        $.make('div', { className: 'NB-account-payment-amount' }, "$" + payment.payment_amount),
                        $.make('div', { className: 'NB-account-payment-provider' }, payment.payment_provider)
                    ]));
                });
            }

            $(window).resize();
        }, this));
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function ($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-account')) {
                newtab = 'account';
            } else if ($t.hasClass('NB-modal-tab-premium')) {
                newtab = 'premium';
            } else if ($t.hasClass('NB-modal-tab-emails')) {
                newtab = 'emails';
            } else if ($t.hasClass('NB-modal-tab-custom')) {
                newtab = 'custom';
            }
            self.switch_tab(newtab);
        });
        $.targetIs(e, { tagSelector: '.NB-account-premium-modal' }, function ($t, $p) {
            e.preventDefault();

            self.close_and_load_premium();
        });
        $.targetIs(e, { tagSelector: '.NB-account-premium-renew' }, function ($t, $p) {
            e.preventDefault();

            self.close_and_load_premium({ 'renew': true });
        });
        $.targetIs(e, { tagSelector: '.NB-account-premium-cancel' }, function ($t, $p) {
            e.preventDefault();

            self.cancel_premium();
        });
        $.targetIs(e, { tagSelector: '.NB-account-delete-all-sites' }, function ($t, $p) {
            e.preventDefault();

            self.delete_all_sites();
        });
        $.targetIs(e, { tagSelector: '.NB-account-delete-saved-stories' }, function ($t, $p) {
            e.preventDefault();

            self.delete_saved_stories();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-cancel' }, function ($t, $p) {
            e.preventDefault();

            self.close();
        });
    },

    handle_change: function () {
        $('input[type=radio],input[type=checkbox],select,input', this.$modal).bind('change', _.bind(this.enable_save, this));
        $('input', this.$modal).bind('keydown', _.bind(this.enable_save, this));
        $('.NB-tab-custom', this.$modal).delegate('input[type=text],textarea', 'keydown', _.bind(this.enable_save, this));
        $('.NB-tab-custom', this.$modal).delegate('input,textarea', 'change', _.bind(this.enable_save, this));
    },

    enable_save: function () {
        $('input[type=submit]', this.$modal).removeAttr('disabled').removeClass('NB-disabled').val('Save My Account');
    },

    disable_save: function () {
        this.resize();
        $('input[type=submit]', this.$modal).attr('disabled', true).addClass('NB-disabled').val('Change what you like above...');
    }

});
