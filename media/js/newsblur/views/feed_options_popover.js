NEWSBLUR.FeedOptionsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-filter-popover",
    
    options: {
        'width': 236,
        'anchor': '.NB-feedbar-options',
        'placement': 'bottom right',
        offset: {
            top: -3,
            left: -100
        },
        overlay_top: true
    },
    
    events: {
        "click .NB-view-setting-option": "change_view_setting"
    },
    
    initialize: function(options) {
        if (NEWSBLUR.reader.story_layout == 'split' &&
            NEWSBLUR.assets.preference('story_pane_anchor') == 'south') {
            this.options.placement = 'top right';
            this.options.offset = {
                top: 10,
                left: -100
            };
            this.options.overlay_top = false;
        }
        
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;
        this.render();
        this.show_correct_feed_view_options_in_menu();
    },
    
    close: function() {
        NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").removeClass('NB-active');
        NEWSBLUR.ReaderPopover.prototype.close.call(this);
    },

    render: function() {
        var self = this;
        
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        
        this.$el.html($.make('div', [
            $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-readfilter' }, [
                $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-all  NB-active' }, 'All stories'),
                $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-unread' }, 'Unread only')
            ]),
            $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-newest NB-active' }, 'Newest first'),
                $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-oldest' }, 'Oldest')
            ])
        ]));
        
        return this;
    },
    
    show_correct_feed_view_options_in_menu: function() {
        var order = NEWSBLUR.assets.view_setting(this.options.feed_id, 'order');
        var read_filter = NEWSBLUR.assets.view_setting(this.options.feed_id, 'read_filter');
        var $oldest = this.$('.NB-view-setting-order-oldest');
        var $newest = this.$('.NB-view-setting-order-newest');
        var $unread = this.$('.NB-view-setting-readfilter-unread');
        var $all = this.$('.NB-view-setting-readfilter-all');

        $oldest.toggleClass('NB-active', order == 'oldest');
        $newest.toggleClass('NB-active', order != 'oldest');
        $oldest.text('Oldest' + (order == 'oldest' ? ' first' : ''));
        $newest.text('Newest' + (order != 'oldest' ? ' first' : ''));
        $unread.toggleClass('NB-active', read_filter == 'unread');
        $all.toggleClass('NB-active', read_filter != 'unread');

        NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").addClass('NB-active');
    },

    
    // ==========
    // = Events =
    // ==========
    
    change_view_setting: function(e) {
        var $target = $(e.target);
        
        if ($target.hasClass("NB-view-setting-order-newest")) {
            this.update_feed({order: 'newest'});
        } else if ($target.hasClass("NB-view-setting-order-oldest")) {
            this.update_feed({order: 'oldest'});
        } else if ($target.hasClass("NB-view-setting-readfilter-all")) {
            this.update_feed({read_filter: 'all'});
        } else if ($target.hasClass("NB-view-setting-readfilter-unread")) {
            this.update_feed({read_filter: 'unread'});
        }
        
        this.show_correct_feed_view_options_in_menu();
    },
    
    update_feed: function(setting) {
        var changed = NEWSBLUR.assets.view_setting(this.options.feed_id, setting);
        if (!changed) return;
        
        NEWSBLUR.reader.reload_feed();
    }

    
});