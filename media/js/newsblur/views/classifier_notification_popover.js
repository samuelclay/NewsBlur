// classifier_notification_popover.js: Popover with Email/Web/iOS/Android toggles
// for per-classifier notifications. Appears on hover/click of the notification
// bell in classifier pills. For feed-type classifiers, delegates to the existing
// FeedNotificationView with popover mode.

NEWSBLUR.Views.ClassifierNotificationPopover = Backbone.View.extend({

    className: 'NB-classifier-notification-popover',

    events: {
        "click .NB-classifier-notif-email": "toggle_email",
        "click .NB-classifier-notif-web": "toggle_web",
        "click .NB-classifier-notif-ios": "toggle_ios",
        "click .NB-classifier-notif-android": "toggle_android"
    },

    initialize: function (options) {
        this.options = options || {};
        // Track channel states
        this.channels = {
            email: options.is_email || false,
            web: options.is_web || false,
            ios: options.is_ios || false,
            android: options.is_android || false
        };
    },

    render: function () {
        // Inactive classifiers (not liked) show an explanatory message instead of controls
        if (this.options.inactive) {
            var $content = $.make('div', { className: 'NB-classifier-notif-controls NB-notif-inactive' }, [
                $.make('div', { className: 'NB-classifier-notif-header' }, [
                    $.make('span', { className: 'NB-classifier-notif-label' }, 'Notify on match')
                ]),
                $.make('div', { className: 'NB-classifier-notif-inactive-msg' },
                    'Only applies to liked classifiers')
            ]);
            this.$el.html($content);
            return this;
        }

        var is_archive = NEWSBLUR.Globals.is_archive;
        var $header_items = [
            $.make('span', { className: 'NB-classifier-notif-label' }, 'Notify on match')
        ];
        if (!is_archive) {
            $header_items.push(
                $.make('span', { className: 'NB-classifier-notif-premium' }, 'Premium Archive')
            );
        }
        var $content = $.make('div', { className: 'NB-classifier-notif-controls' + (!is_archive ? ' NB-notif-gated' : '') }, [
            $.make('div', { className: 'NB-classifier-notif-header' }, $header_items),
            $.make('ul', { className: 'segmented-control NB-classifier-notif-types' }, [
                $.make('li', {
                    className: 'NB-classifier-notif-option NB-classifier-notif-email' +
                        (this.channels.email ? ' NB-active' : ''),
                    role: 'button'
                }, 'Email'),
                $.make('li', {
                    className: 'NB-classifier-notif-option NB-classifier-notif-web' +
                        (this.channels.web ? ' NB-active' : ''),
                    role: 'button'
                }, 'Web'),
                $.make('li', {
                    className: 'NB-classifier-notif-option NB-classifier-notif-ios' +
                        (this.channels.ios ? ' NB-active' : ''),
                    role: 'button'
                }, 'iOS'),
                $.make('li', {
                    className: 'NB-classifier-notif-option NB-classifier-notif-android' +
                        (this.channels.android ? ' NB-active' : ''),
                    role: 'button'
                }, 'Android')
            ])
        ]);

        this.$el.html($content);
        return this;
    },

    // ==========
    // = Events =
    // ==========

    toggle_email: function () { this.toggle_type('email'); },
    toggle_web: function () { this.toggle_type('web'); },
    toggle_ios: function () { this.toggle_type('ios'); },
    toggle_android: function () { this.toggle_type('android'); },

    toggle_type: function (type) {
        if (!NEWSBLUR.Globals.is_archive) {
            // Flash the premium badge to signal "denied"
            var $premium = this.$('.NB-classifier-notif-premium');
            $premium.removeClass('NB-flash');
            $premium[0].offsetWidth; // force reflow
            $premium.addClass('NB-flash');
            setTimeout(function () { $premium.removeClass('NB-flash'); }, 800);
            return;
        }
        this.channels[type] = !this.channels[type];
        var func = this.channels[type] ? 'addClass' : 'removeClass';
        this.$('.NB-classifier-notif-' + type)[func]('NB-active');
        this.save();
    },

    save: function () {
        var notification_types = [];
        _.each(this.channels, function (active, type) {
            if (active) notification_types.push(type);
        });

        var data = {
            classifier_type: this.options.classifier_type,
            classifier_value: this.options.classifier_value,
            scope: this.options.scope,
            feed_id: this.options.feed_id,
            folder_name: this.options.folder_name || '',
            notification_types: notification_types
        };

        var self = this;
        NEWSBLUR.assets.set_classifier_notification(data, function (resp) {
            // Update the cached classifier notifications on the trainer
            if (resp && resp.classifier_notifications && self.options.trainer) {
                self.options.trainer.classifier_notifications = resp.classifier_notifications;
            }
            // Update the bell icon on the pill
            if (self.options.$bell) {
                self.update_bell_display(notification_types);
            }
        });
    },

    update_bell_display: function (notification_types) {
        var $bell = this.options.$bell;
        var has_channels = notification_types.length > 0;

        if (has_channels) {
            $bell.addClass('NB-active');
        } else {
            $bell.removeClass('NB-active');
        }

        // Update channel indicators
        var $indicators = $bell.find('.NB-classifier-notif-indicators');
        $indicators.empty();
        _.each(notification_types, function (type) {
            var icon_svg = NEWSBLUR.Views.ClassifierNotificationPopover.CHANNEL_ICONS[type];
            if (icon_svg) {
                var $icon = $.make('span', { className: 'NB-channel-indicator NB-channel-' + type });
                $icon.html(icon_svg);
                $indicators.append($icon);
            }
        });
    }

}, {
    // Static properties

    BELL_SVG: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',

    CHANNEL_ICONS: {
        email: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>',
        web: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>',
        ios: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/></svg>',
        android: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/></svg>'
    }
});
