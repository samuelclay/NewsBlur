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
        var is_archive = NEWSBLUR.Globals.is_archive;
        var $content = $.make('div', { className: 'NB-classifier-notif-controls' + (!is_archive ? ' NB-notif-gated' : '') }, [
            $.make('div', { className: 'NB-classifier-notif-header' }, [
                $.make('span', { className: 'NB-classifier-notif-label' }, 'Notify on match')
            ]),
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
            var $bell = this.options.$bell;
            if ($bell) {
                // 1. Shake the bell to signal "denied"
                $bell.removeClass('NB-shake');
                $bell[0].offsetWidth;
                $bell.addClass('NB-shake');
                setTimeout(function () { $bell.removeClass('NB-shake'); }, 500);

                // 2. Show a brief "Requires Premium Archive" tooltip above the bell
                $('.NB-scope-tooltip').remove();
                var $tip = $('<div class="NB-scope-tooltip NB-scope-tooltip-denied">Requires Premium Archive</div>');
                $('body').append($tip);
                var tip_rect = $bell[0].getBoundingClientRect();
                $tip.css({
                    top: tip_rect.top - $tip.outerHeight() - 6,
                    left: tip_rect.left + tip_rect.width / 2 - $tip.outerWidth() / 2
                });
                setTimeout(function () { $tip.fadeOut(300, function () { $tip.remove(); }); }, 1500);

                // 3. Animate in the notification notice in the section header
                var $section = $bell.closest('.NB-fieldset');
                var $notice = $section.find('.NB-classifier-notif-notice');
                if ($notice.length && !$notice.hasClass('NB-visible')) {
                    $notice.removeClass('NB-fading');
                    $notice[0].offsetWidth;
                    $notice.addClass('NB-visible');
                }
            }
            return;
        }

        this.channels[type] = !this.channels[type];
        var func = this.channels[type] ? 'addClass' : 'removeClass';
        this.$('.NB-classifier-notif-' + type)[func]('NB-active');

        // Build current notification types list
        var notification_types = [];
        _.each(this.channels, function (active, t) {
            if (active) notification_types.push(t);
        });

        // Store on bell data for deferred save
        var $bell = this.options.$bell;
        if ($bell) {
            $bell.data('notification-types', notification_types);
            this.update_bell_display(notification_types);

            // Mark the parent classifier as changed if notification types differ from original
            var $classifier = $bell.closest('.NB-classifier');
            var original_types = ($bell.data('original-notification-types') || []).slice().sort().join(',');
            var current_types = notification_types.slice().sort().join(',');
            var original_state = $classifier.data('original-state') || 'neutral';
            var current_state = $classifier.hasClass('NB-classifier-like') ? 'like' :
                ($classifier.hasClass('NB-classifier-super-dislike') ? 'super_dislike' :
                ($classifier.hasClass('NB-classifier-dislike') ? 'dislike' : 'neutral'));
            var original_scope = $classifier.data('original-scope') || 'feed';
            var current_scope = $classifier.data('scope') || 'feed';

            if (current_types !== original_types || current_state !== original_state || current_scope !== original_scope) {
                $classifier.addClass('NB-classifier-changed');
            } else {
                $classifier.removeClass('NB-classifier-changed');
            }

            // Update the save button
            if (this.options.trainer) {
                this.options.trainer.update_save_button();
            }
        }
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
