NEWSBLUR.ReaderNotifications = function (feed_id, options) {
    var defaults = {
        'onOpen': function () {
            $(window).trigger('resize.simplemodal');
        }
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.feed_id = feed_id;
    this.feed = this.model.get_feed(feed_id);

    this.runner();
};

NEWSBLUR.ReaderNotifications.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderNotifications.prototype.constructor = NEWSBLUR.ReaderNotifications;

_.extend(NEWSBLUR.ReaderNotifications.prototype, {

    runner: function () {
        console.log(['Reader notifications', this.feed, this.feed_id]);
        this.make_modal();
        this.handle_cancel();
        this.open_modal();
        if (this.feed_id) {
            this.initialize_feed(this.feed_id);
        }

        $('input[name=notification_title_only]', this.$modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.notification_title_only) {
                $(this).attr('checked', true);
                return false;
            }
        });

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
        this.load_classifier_notifications();
    },

    initialize_feed: function (feed_id) {
        var frequency = this.feed.get('notification_frequency');
        var notifications = this.feed.get('notifications');

        NEWSBLUR.Modal.prototype.initialize_feed.call(this, feed_id);

        var $site = $(".NB-modal-section-site", this.$modal);
        $site.html(this.make_site_notification());

        var $all = $(".NB-modal-section-all", this.$modal);
        $all.html(this.make_feed_notifications());

        this.resize();
    },

    get_feed_settings: function () {
        if (this.feed.is_starred()) return;

        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');

        var settings_fn = this.options.social_feed ? this.model.get_social_settings :
            this.model.get_feed_settings;
        settings_fn.call(this.model, this.feed_id, _.bind(this.populate_settings, this));
    },

    populate_settings: function (data) {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);

        $loading.removeClass('NB-active');
        this.resize();
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-notifications NB-modal' }, [
            (this.feed && $.make('div', { className: 'NB-modal-feed-chooser-container' }, [
                this.make_feed_chooser()
            ])),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-icon' }),
                'Notifications',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('fieldset', [
                    $.make('legend', 'Notification Preferences'),
                    $.make('div', { className: 'NB-modal-section NB-modal-section-preferences' }, [
                        $.make('div', { className: 'NB-preference NB-preference-notification-title-only' }, [
                            $.make('div', { className: 'NB-preference-options' }, [
                                $.make('div', [
                                    $.make('input', { id: 'NB-preference-notificationtitleonly-1', type: 'radio', name: 'notification_title_only', value: 0 }),
                                    $.make('label', { 'for': 'NB-preference-notificationtitleonly-1' }, [
                                        'See the story title and a short content preview'
                                    ])
                                ]),
                                $.make('div', [
                                    $.make('input', { id: 'NB-preference-notificationtitleonly-2', type: 'radio', name: 'notification_title_only', value: 1 }),
                                    $.make('label', { 'for': 'NB-preference-notificationtitleonly-2' }, [
                                        'Only see the full story title'
                                    ])
                                ])
                            ]),
                            $.make('div', { className: 'NB-preference-label' }, [
                                'Story preview',
                                $.make('div', { className: 'NB-preference-sublabel' }, '')
                            ])
                        ])
                    ])
                ])
            ]),
            (this.feed && $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('fieldset', [
                    $.make('legend', 'Site Notifications'),
                    $.make('div', { className: 'NB-modal-section NB-modal-section-site' }, [
                        this.make_site_notification()
                    ])
                ])
            ])),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('fieldset', [
                    $.make('legend', 'All Notifications'),
                    $.make('div', { className: 'NB-modal-section NB-modal-section-all' }, [
                        this.make_feed_notifications()
                    ])
                ])
            ])
        ]);
    },

    handle_cancel: function () {
        var $cancel = $('.NB-modal-cancel', this.$modal);

        $cancel.click(function (e) {
            e.preventDefault();
            $.modal.close();
        });
    },

    make_feed_notification: function (feed) {
        var $feed = new NEWSBLUR.Views.FeedNotificationView({ model: feed });

        return $feed.render().$el;
    },

    sort_classifiers: function (a, b) {
        if (a.classifier_type !== b.classifier_type) {
            return a.classifier_type < b.classifier_type ? -1 : 1;
        }
        return a.classifier_value < b.classifier_value ? -1 : (a.classifier_value > b.classifier_value ? 1 : 0);
    },

    make_feed_notifications: function () {
        var self = this;
        var site_feed_id = this.feed && this.feed.id;
        var classifier_notifs = this.classifier_notifications || {};

        // Group classifier notifications by scope
        var global_classifiers = [];
        var folder_classifiers = {};
        var feed_classifiers = {};

        _.each(classifier_notifs, function (notif) {
            // Skip feed-scoped classifiers for the site feed (shown in Site section)
            if (site_feed_id && notif.scope === 'feed' && notif.feed_id == site_feed_id) return;

            if (notif.scope === 'global') {
                global_classifiers.push(notif);
            } else if (notif.scope === 'folder') {
                var folder = notif.folder_name || 'Uncategorized';
                if (!folder_classifiers[folder]) folder_classifiers[folder] = [];
                folder_classifiers[folder].push(notif);
            } else {
                var fid = notif.feed_id;
                if (!feed_classifiers[fid]) feed_classifiers[fid] = [];
                feed_classifiers[fid].push(notif);
            }
        });

        global_classifiers.sort(this.sort_classifiers);
        _.each(folder_classifiers, function (notifs) { notifs.sort(self.sort_classifiers); });
        _.each(feed_classifiers, function (notifs) { notifs.sort(self.sort_classifiers); });

        var $elements = [];

        // Global classifiers at top
        if (global_classifiers.length) {
            var $global_rows = _.map(global_classifiers, function (notif) {
                return self.make_classifier_notification_row(notif);
            });
            $elements.push($.make('div', { className: 'NB-notification-scope-section' }, [
                $.make('div', { className: 'NB-notification-scope-label' }, 'Global')
            ].concat($global_rows)));
        }

        // Folder classifiers
        var folder_names = _.keys(folder_classifiers).sort();
        _.each(folder_names, function (folder_name) {
            var $folder_rows = _.map(folder_classifiers[folder_name], function (notif) {
                return self.make_classifier_notification_row(notif);
            });
            $elements.push($.make('div', { className: 'NB-notification-scope-section' }, [
                $.make('div', { className: 'NB-notification-scope-label' }, folder_name)
            ].concat($folder_rows)));
        });

        // Feeds with feed-scoped classifiers underneath
        var feed_notifications = this.model.get_feeds().select(function (feed) {
            return (feed.get('notification_types') && feed.id != site_feed_id) ||
                   (feed_classifiers[feed.id] && feed.id != site_feed_id);
        });

        feed_notifications.sort(function (a, b) { return a.get('feed_title') < b.get('feed_title'); });

        for (var i = 0; i < feed_notifications.length; i++) {
            var feed = feed_notifications[i];
            var classifiers = feed_classifiers[feed.id];

            if (classifiers && classifiers.length) {
                var $children = [this.make_feed_notification(feed)];
                _.each(classifiers, function (notif) {
                    $children.push(self.make_classifier_notification_row(notif));
                });
                $elements.push($.make('div', { className: 'NB-feed-notification-group' }, $children));
            } else {
                $elements.push(this.make_feed_notification(feed));
            }
        }

        return $elements;
    },

    load_classifier_notifications: function () {
        var self = this;
        this.model.load_classifier_notifications(function (data) {
            self.classifier_notifications = (data && data.classifier_notifications) || {};
            var $all = $(".NB-modal-section-all", self.$modal);
            $all.html(self.make_feed_notifications());
            if (self.feed_id && self.feed) {
                var $site = $(".NB-modal-section-site", self.$modal);
                $site.html(self.make_site_notification());
            }
            self.resize();
        });
    },

    make_site_notification: function () {
        var self = this;
        var $content = [this.make_feed_notification(this.feed)];

        if (this.classifier_notifications) {
            var feed_id = this.feed_id;
            var classifiers = [];
            _.each(this.classifier_notifications, function (notif) {
                if (notif.scope === 'feed' && notif.feed_id == feed_id) {
                    classifiers.push(notif);
                }
            });
            classifiers.sort(self.sort_classifiers);
            _.each(classifiers, function (notif) {
                $content.push(self.make_classifier_notification_row(notif));
            });
        }

        return $content;
    },

    make_classifier_notification_row: function (notif) {
        var view = new NEWSBLUR.Views.ClassifierNotificationView({
            notification: notif
        });
        return view.render().$el;
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-submit-retry' }, function ($t, $p) {
            e.preventDefault();

            self.save_retry_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-delete' }, function ($t, $p) {
            e.preventDefault();

            self.delete_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-address' }, function ($t, $p) {
            e.preventDefault();

            self.change_feed_address();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-link' }, function ($t, $p) {
            e.preventDefault();

            self.change_feed_link();
        });
        $.targetIs(e, { tagSelector: '.NB-premium-only-link' }, function ($t, $p) {
            e.preventDefault();

            self.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
        });
    },

    animate_saved: function () {
        var $status = $('.NB-exception-option-view .NB-exception-option-status', this.$modal);
        $status.text('Saved').animate({
            'opacity': 1
        }, {
            'queue': false,
            'duration': 600,
            'complete': function () {
                _.delay(function () {
                    $status.animate({ 'opacity': 0 }, { 'queue': false, 'duration': 1000 });
                }, 300);
            }
        });
    },

    handle_change: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function ($t, $p) {
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_feed_settings();
        });
        $.targetIs(e, { tagSelector: '[name=notification_title_only]' }, function ($t, $p) {
            var notification_title_only = self.$modal.find("input[name=notification_title_only]:checked").val();
            console.log(['notification_title_only', notification_title_only]);
            NEWSBLUR.assets.preference('notification_title_only', notification_title_only);
        });
    }

});
