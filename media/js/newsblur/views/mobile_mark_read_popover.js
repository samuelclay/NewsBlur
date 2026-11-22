// mobile_mark_read_popover.js: the phone story list's mark read menu, opened from the nav bar
// (views/mobile_layout_view.js open_mark_read_menu). Like every popover on a phone it opens as a
// bottom sheet (media/css/reader/mobile.css), and picking a choice is the confirmation.
NEWSBLUR.MobileMarkReadPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-mobile-mark-read-popover",

    options: {
        'width': 280,
        'anchor': '.NB-mobile-mark-read',
        'placement': 'bottom right',
        'popover_class': 'NB-mobile-mark-read-popover-container'
    },

    events: {
        "click .NB-mobile-mark-read-option": "choose"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.render();
    },

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        var choices = [{ days: 0, title: gettext('Mark all as read') }].concat(_.map([1, 3, 7, 14], function (days) {
            return {
                days: days,
                title: interpolate(ngettext("Older than %(count)s day", "Older than %(count)s days", days), { count: days }, true)
            };
        }));
        this.$el.html($.make('div', { className: 'NB-mobile-layout-menu' }, [
            $.make('div', { className: 'NB-mobile-layout-menu-title' }, gettext('Mark as read')),
            _.map(choices, function (choice) {
                return $.make('div', {
                    className: 'NB-mobile-layout-option NB-mobile-mark-read-option',
                    'data-days': choice.days,
                    role: 'button'
                }, [
                    $.make('div', { className: 'NB-mobile-icon ' + (choice.days ? 'NB-mobile-icon-clock' : 'NB-mobile-icon-markread') }),
                    $.make('div', { className: 'NB-mobile-layout-option-text' }, [
                        $.make('div', { className: 'NB-mobile-layout-option-title' }, choice.title)
                    ])
                ]);
            })
        ]));
        return this;
    },

    choose: function (e) {
        var days = parseInt($(e.currentTarget).data('days'), 10);
        this.close();
        NEWSBLUR.app.mobile.mark_list_read(days);
    }

});
