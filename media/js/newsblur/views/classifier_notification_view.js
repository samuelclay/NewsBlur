NEWSBLUR.Views.ClassifierNotificationView = Backbone.View.extend({

    events: {
        "click .NB-classifier-notification-email": "toggle_email",
        "click .NB-classifier-notification-ios": "toggle_ios",
        "click .NB-classifier-notification-android": "toggle_android",
        "click .NB-classifier-notification-web": "toggle_web"
    },

    initialize: function (options) {
        this.notification = options.notification;
    },

    render: function () {
        var notif = this.notification;
        var notification_types = notif.notification_types || [];
        var is_email = _.contains(notification_types, 'email');
        var is_web = _.contains(notification_types, 'web');
        var is_ios = _.contains(notification_types, 'ios');
        var is_android = _.contains(notification_types, 'android');

        var $el = $.make('div', { className: 'NB-classifier-notification' }, [
            $.make('div', { className: 'NB-classifier-notification-controls' }, [
                $.make('ul', { className: 'segmented-control NB-classifier-notification-types' }, [
                    $.make('li', {
                        className: 'NB-classifier-notification-option NB-classifier-notification-email' + (is_email ? ' NB-active' : ''),
                        role: 'button'
                    }, 'Email'),
                    $.make('li', {
                        className: 'NB-classifier-notification-option NB-classifier-notification-web' + (is_web ? ' NB-active' : ''),
                        role: 'button'
                    }, 'Web'),
                    $.make('li', {
                        className: 'NB-classifier-notification-option NB-classifier-notification-ios' + (is_ios ? ' NB-active' : ''),
                        role: 'button'
                    }, 'iOS'),
                    $.make('li', {
                        className: 'NB-classifier-notification-option NB-classifier-notification-android' + (is_android ? ' NB-active' : ''),
                        role: 'button'
                    }, 'Android')
                ])
            ]),
            $.make('div', { className: 'NB-classifier-notification-pill' }, [
                $.make('span', { className: 'NB-classifier-type-badge' }, notif.classifier_type.toUpperCase()),
                (notif.is_regex && $.make('span', { className: 'NB-classifier-type-badge NB-classifier-regex-badge' }, 'REGEX')),
                $.make('span', { className: 'NB-classifier-notification-value' }, notif.classifier_value)
            ])
        ]);

        this.$el.replaceWith($el);
        this.setElement($el);

        return this;
    },

    toggle_email: function () { this.toggle_type('email'); },
    toggle_ios: function () { this.toggle_type('ios'); },
    toggle_android: function () { this.toggle_type('android'); },
    toggle_web: function () { this.toggle_type('web'); },

    toggle_type: function (type) {
        var notification_types = (this.notification.notification_types || []).slice();
        var idx = notification_types.indexOf(type);
        if (idx >= 0) {
            notification_types.splice(idx, 1);
        } else {
            notification_types.push(type);
        }
        this.notification.notification_types = notification_types;

        _.each(['web', 'ios', 'android', 'email'], _.bind(function (t) {
            this.$(".NB-classifier-notification-" + t).toggleClass('NB-active', _.contains(notification_types, t));
        }, this));

        this.save();
    },

    save: function () {
        NEWSBLUR.assets.set_classifier_notification(this.notification);
    }

});
