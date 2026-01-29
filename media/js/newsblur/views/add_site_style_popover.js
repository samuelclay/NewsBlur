NEWSBLUR.AddSiteStylePopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-add-site-style-popover",

    options: {
        'width': 460,
        'placement': 'bottom right',
        'offset': {
            top: 8,
            left: -76
        },
        'popover_class': 'NB-add-site-style-popover-container'
    },

    events: {
        "click .NB-stories-count-option": "change_stories_count",
        "click .NB-image-preview-option": "change_image_preview",
        "click .NB-content-preview-option": "change_content_preview",
        "click .NB-sort-order-option": "change_sort_order",
        "click .NB-card-density-option": "change_card_density"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.add_site_view = options.add_site_view;

        // Use function-based anchor to ensure we get the right element
        var self = this;
        this.options.anchor = function () {
            return self.add_site_view.$('.NB-add-site-style-button');
        };

        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;
        this.render();
        this.show_correct_options();
    },

    close: function () {
        this.add_site_view.$('.NB-add-site-style-button').removeClass('NB-active');
        NEWSBLUR.ReaderPopover.prototype.close.apply(this, arguments);
    },

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.$el.html($.make('div', { className: 'NB-style-popover-content' }, [
            $.make('div', { className: 'NB-style-row' }, [
                $.make('div', { className: 'NB-style-label' }, 'Stories'),
                $.make('ul', { className: 'segmented-control NB-options-stories-count' }, [
                    $.make('li', { className: 'NB-stories-count-option NB-options-stories-count-0', role: "button" }, '0'),
                    $.make('li', { className: 'NB-stories-count-option NB-options-stories-count-1', role: "button" }, '1'),
                    $.make('li', { className: 'NB-stories-count-option NB-options-stories-count-3', role: "button" }, '3'),
                    $.make('li', { className: 'NB-stories-count-option NB-options-stories-count-5', role: "button" }, '5')
                ])
            ]),
            $.make('div', { className: 'NB-style-row' }, [
                $.make('div', { className: 'NB-style-label' }, 'Image Preview'),
                $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-imagepreview NB-options-image-preview' }, [
                    $.make('li', { className: 'NB-image-preview-option NB-view-setting-imagepreview-none', role: "button" }, 'None'),
                    $.make('li', { className: 'NB-image-preview-option NB-view-setting-imagepreview-small-left', role: "button" }, [
                        $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_small_left.png' })
                    ]),
                    $.make('li', { className: 'NB-image-preview-option NB-view-setting-imagepreview-large-left', role: "button" }, [
                        $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_large_left.png' })
                    ]),
                    $.make('li', { className: 'NB-image-preview-option NB-view-setting-imagepreview-large-right', role: "button" }, [
                        $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_large_right.png' })
                    ]),
                    $.make('li', { className: 'NB-image-preview-option NB-view-setting-imagepreview-small-right', role: "button" }, [
                        $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_small_right.png' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-style-row' }, [
                $.make('div', { className: 'NB-style-label' }, 'Story Text'),
                $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-contentpreview NB-options-content-preview' }, [
                    $.make('li', { className: 'NB-content-preview-option NB-view-setting-contentpreview-title', role: "button" }, 'Title'),
                    $.make('li', { className: 'NB-content-preview-option NB-view-setting-contentpreview-small', role: "button" }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-content-preview-option NB-view-setting-contentpreview-medium', role: "button" }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-content-preview-option NB-view-setting-contentpreview-large', role: "button" }, $.make('div', { className: 'NB-icon' }))
                ])
            ]),
            $.make('div', { className: 'NB-style-row' }, [
                $.make('div', { className: 'NB-style-label' }, 'Sort By'),
                $.make('ul', { className: 'segmented-control NB-options-sort-order' }, [
                    $.make('li', { className: 'NB-sort-order-option NB-options-sort-order-relevance', role: "button" }, 'Relevance'),
                    $.make('li', { className: 'NB-sort-order-option NB-options-sort-order-subscribers', role: "button" }, 'Subscribers'),
                    $.make('li', { className: 'NB-sort-order-option NB-options-sort-order-stories', role: "button" }, 'Stories'),
                    $.make('li', { className: 'NB-sort-order-option NB-options-sort-order-name', role: "button" }, 'Name')
                ])
            ]),
            $.make('div', { className: 'NB-style-row NB-card-density-section' }, [
                $.make('div', { className: 'NB-style-label' }, 'Card Density'),
                $.make('ul', { className: 'segmented-control NB-options-card-density' }, [
                    $.make('li', { className: 'NB-card-density-option NB-options-card-density-compact', role: "button" }, 'Compact'),
                    $.make('li', { className: 'NB-card-density-option NB-options-card-density-normal', role: "button" }, 'Normal'),
                    $.make('li', { className: 'NB-card-density-option NB-options-card-density-expanded', role: "button" }, 'Full')
                ])
            ])
        ]));

        return this;
    },

    show_correct_options: function () {
        var stories_count = NEWSBLUR.assets.preference('add_site_stories_count');
        if (stories_count === undefined || stories_count === null) stories_count = 3;
        var image_preview = NEWSBLUR.assets.preference('image_preview') || 'large-right';
        var content_preview = NEWSBLUR.assets.preference('show_content_preview') || 'medium';
        var sort_order = NEWSBLUR.assets.preference('add_site_sort_order') || 'relevance';
        var card_density = NEWSBLUR.assets.preference('add_site_card_density') || 'normal';
        var view_mode = this.add_site_view.view_mode;

        this.$('.NB-stories-count-option').removeClass('NB-active');
        this.$('.NB-options-stories-count-' + stories_count).addClass('NB-active');

        this.$('.NB-image-preview-option').removeClass('NB-active');
        this.$('.NB-view-setting-imagepreview-' + image_preview).addClass('NB-active');

        this.$('.NB-content-preview-option').removeClass('NB-active');
        if (content_preview === 'title') {
            this.$('.NB-view-setting-contentpreview-title').addClass('NB-active');
        } else if (content_preview === 'small') {
            this.$('.NB-view-setting-contentpreview-small').addClass('NB-active');
        } else if (content_preview === 'medium') {
            this.$('.NB-view-setting-contentpreview-medium').addClass('NB-active');
        } else if (content_preview === 'large') {
            this.$('.NB-view-setting-contentpreview-large').addClass('NB-active');
        }

        this.$('.NB-sort-order-option').removeClass('NB-active');
        this.$('.NB-options-sort-order-' + sort_order).addClass('NB-active');

        this.$('.NB-card-density-option').removeClass('NB-active');
        this.$('.NB-options-card-density-' + card_density).addClass('NB-active');

        // Only show card density option in grid mode
        this.$('.NB-card-density-section').toggle(view_mode === 'grid');

        this.add_site_view.$('.NB-add-site-style-button').addClass('NB-active');
    },

    // ==========
    // = Events =
    // ==========

    change_stories_count: function (e) {
        var $target = $(e.currentTarget);

        if ($target.hasClass("NB-options-stories-count-0")) {
            this.update_stories_count(0);
        } else if ($target.hasClass("NB-options-stories-count-1")) {
            this.update_stories_count(1);
        } else if ($target.hasClass("NB-options-stories-count-3")) {
            this.update_stories_count(3);
        } else if ($target.hasClass("NB-options-stories-count-5")) {
            this.update_stories_count(5);
        }

        this.show_correct_options();
    },

    update_stories_count: function (setting) {
        NEWSBLUR.assets.save_preferences({ 'add_site_stories_count': setting });
        this.add_site_view.render_active_tab();
    },

    change_image_preview: function (e) {
        var $target = $(e.currentTarget);

        if ($target.hasClass("NB-view-setting-imagepreview-none")) {
            this.update_image_preview('none');
        } else if ($target.hasClass("NB-view-setting-imagepreview-small-left")) {
            this.update_image_preview('small-left');
        } else if ($target.hasClass("NB-view-setting-imagepreview-small-right")) {
            this.update_image_preview('small-right');
        } else if ($target.hasClass("NB-view-setting-imagepreview-large-left")) {
            this.update_image_preview('large-left');
        } else if ($target.hasClass("NB-view-setting-imagepreview-large-right")) {
            this.update_image_preview('large-right');
        }

        this.show_correct_options();
    },

    update_image_preview: function (setting) {
        NEWSBLUR.assets.preference('image_preview', setting);
        this.add_site_view.render_active_tab();
    },

    change_content_preview: function (e) {
        var $target = $(e.currentTarget);

        if ($target.hasClass("NB-view-setting-contentpreview-title")) {
            this.update_content_preview('title');
        } else if ($target.hasClass("NB-view-setting-contentpreview-small")) {
            this.update_content_preview('small');
        } else if ($target.hasClass("NB-view-setting-contentpreview-medium")) {
            this.update_content_preview('medium');
        } else if ($target.hasClass("NB-view-setting-contentpreview-large")) {
            this.update_content_preview('large');
        }

        this.show_correct_options();
    },

    update_content_preview: function (setting) {
        NEWSBLUR.assets.preference('show_content_preview', setting);
        this.add_site_view.render_active_tab();
    },

    change_sort_order: function (e) {
        var $target = $(e.currentTarget);

        if ($target.hasClass("NB-options-sort-order-relevance")) {
            this.update_sort_order('relevance');
        } else if ($target.hasClass("NB-options-sort-order-subscribers")) {
            this.update_sort_order('subscribers');
        } else if ($target.hasClass("NB-options-sort-order-stories")) {
            this.update_sort_order('stories');
        } else if ($target.hasClass("NB-options-sort-order-name")) {
            this.update_sort_order('name');
        }

        this.show_correct_options();
    },

    update_sort_order: function (setting) {
        NEWSBLUR.assets.save_preferences({ 'add_site_sort_order': setting });
        this.add_site_view.render_active_tab();
    },

    change_card_density: function (e) {
        var $target = $(e.currentTarget);

        if ($target.hasClass("NB-options-card-density-compact")) {
            this.update_card_density('compact');
        } else if ($target.hasClass("NB-options-card-density-normal")) {
            this.update_card_density('normal');
        } else if ($target.hasClass("NB-options-card-density-expanded")) {
            this.update_card_density('expanded');
        }

        this.show_correct_options();
    },

    update_card_density: function (setting) {
        NEWSBLUR.assets.save_preferences({ 'add_site_card_density': setting });
        this.add_site_view.render_active_tab();
    }

});
