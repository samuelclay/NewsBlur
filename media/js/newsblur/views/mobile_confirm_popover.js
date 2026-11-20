// mobile_confirm_popover.js: asks a yes or no question as a phone bottom sheet. reader.js
// show_mark_read_confirm uses it on a phone, where the feed bar it confirms in on desktop is
// hidden (media/css/reader/mobile.css), so a long-pressed "Mark newer stories as read" still asks.
NEWSBLUR.MobileConfirmPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-mobile-confirm-popover",

    options: {
        'width': 280,
        'anchor': '.NB-mobile-titles-bar',
        'placement': 'bottom right',
        'popover_class': 'NB-mobile-confirm-popover-container',
        'message': '',
        'confirm_label': '',
        'on_confirm': null
    },

    events: {
        "click .NB-mobile-confirm-yes": "confirm",
        "click .NB-mobile-confirm-no": "cancel"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.render();
    },

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        this.$el.html($.make('div', { className: 'NB-mobile-layout-menu' }, [
            $.make('div', { className: 'NB-mobile-layout-menu-title' }, this.options.message),
            $.make('div', { className: 'NB-mobile-layout-option NB-mobile-mark-read-option NB-mobile-confirm-yes', role: 'button' }, [
                $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-markread' }),
                $.make('div', { className: 'NB-mobile-layout-option-text' }, [
                    $.make('div', { className: 'NB-mobile-layout-option-title' }, this.options.confirm_label)
                ])
            ]),
            $.make('div', { className: 'NB-mobile-layout-option NB-mobile-mark-read-option NB-mobile-confirm-no', role: 'button' }, [
                $.make('div', { className: 'NB-mobile-icon' }),
                $.make('div', { className: 'NB-mobile-layout-option-text' }, [
                    $.make('div', { className: 'NB-mobile-layout-option-title' }, gettext('Cancel'))
                ])
            ])
        ]));
        return this;
    },

    confirm: function () {
        var on_confirm = this.options.on_confirm;
        this.close();
        on_confirm && on_confirm();
    },

    cancel: function () {
        this.close();
    }

});
