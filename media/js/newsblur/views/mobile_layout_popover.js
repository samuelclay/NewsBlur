// mobile_layout_popover.js: the phone story list's layout menu, opened from the nav bar's layout
// button (views/mobile_layout_view.js). It opens as a bottom sheet like every popover on a phone
// (media/css/reader/mobile.css) and picks one of the phone layouts in common/mobile_utils.js.
NEWSBLUR.MobileLayoutPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-mobile-layout-popover",

    options: {
        'width': 280,
        'anchor': '.NB-mobile-layout-toggle',
        'placement': 'bottom right',
        'popover_class': 'NB-mobile-layout-popover-container'
    },

    events: {
        "click .NB-mobile-layout-option": "choose_layout"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.render();
    },

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        var current = NEWSBLUR.app.mobile.layout();
        var choices = [
            { layout: 'list', title: gettext('Inline list'), detail: gettext('Stories open inside the list') },
            { layout: 'page', title: gettext('Full-screen list'), detail: gettext('Stories open on their own screen') },
            { layout: 'grid', title: gettext('Grid'), detail: gettext('Story cards open on their own screen') }
        ];
        this.$el.html($.make('div', { className: 'NB-mobile-layout-menu' }, [
            $.make('div', { className: 'NB-mobile-layout-menu-title' }, gettext('Layout')),
            _.map(choices, function (choice) {
                return $.make('div', {
                    className: 'NB-mobile-layout-option' + (choice.layout === current ? ' NB-active' : ''),
                    'data-layout': choice.layout,
                    role: 'button'
                }, [
                    $.make('div', { className: 'NB-mobile-icon NB-mobile-icon-layout-' + choice.layout }),
                    $.make('div', { className: 'NB-mobile-layout-option-text' }, [
                        $.make('div', { className: 'NB-mobile-layout-option-title' }, choice.title),
                        $.make('div', { className: 'NB-mobile-layout-option-detail' }, choice.detail)
                    ]),
                    $.make('div', { className: 'NB-mobile-layout-option-check' })
                ]);
            })
        ]));
        return this;
    },

    choose_layout: function (e) {
        NEWSBLUR.app.mobile.set_layout($(e.currentTarget).data('layout'));
        this.close();
    }

});
