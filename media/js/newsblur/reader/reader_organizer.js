NEWSBLUR.ReaderOrganizer = function(user_id, options) {
    var defaults = {
        width: 800,
        sorting: 'alphabetical',
        onOpen: _.bind(function() {
            this.resize_modal();
        }, this)
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.init();
};

NEWSBLUR.ReaderOrganizer.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderOrganizer.prototype, {
    
    init: function() {
        this.make_modal();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal NB-modal-organizer' }, [
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-icon' }),
                'Organize sites'
            ]),
            $.make('div', { className: 'NB-organizer-actionbar' }, [
                $.make('div', { className: 'NB-organizer-sorts' }, [
                    $.make('div', { className: 'NB-organizer-action-title' }, 'Sort '),
                    $.make('div', { className: 'NB-organizer-action NB-action-alphabetical NB-active' }, 'Name'),
                    $.make('div', { className: 'NB-organizer-action NB-action-subscribers' }, 'Subs'),
                    $.make('div', { className: 'NB-organizer-action NB-action-frequency' }, 'Frequency'),
                    $.make('div', { className: 'NB-organizer-action NB-action-recency' }, 'Recency'),
                    $.make('div', { className: 'NB-organizer-action NB-action-mostused' }, 'Use')
                ]),
                $.make('div', { className: 'NB-organizer-selects' }, [
                    $.make('div', { className: 'NB-organizer-action-title' }, 'Select'),
                    $.make('div', { className: 'NB-organizer-action NB-action-select-all' }, 'All'),
                    $.make('div', { className: 'NB-organizer-action NB-action-select-none' }, 'None')
                ])
            ]),
            this.make_feeds()
        ]);
    },
    
    resize_modal: function(previous_height) {
        var resize_height = 0;
        var $feedlist = $('.NB-feedchooser', this.$modal);
        var content_height = $feedlist.height() + 90;
        var container_height = this.$modal.parent().height();
        if (content_height > container_height && previous_height != content_height) {
            var chooser_height = $feedlist.height();
            var diff = Math.max(4, content_height - container_height);
            resize_height = chooser_height - diff;
            $feedlist.css({'max-height': resize_height});
            _.defer(_.bind(function() { this.resize_modal(content_height); }, this), 1);
        }
        if (resize_height) {
            this.options.resize = resize_height;
        }
    },
    
    // =============
    // = Feed list =
    // =============
    
    make_feeds: function(options) {
        var feeds = this.model.feeds;
        this.feed_count = _.unique(NEWSBLUR.assets.folders.feed_ids_in_folder()).length;
        NEWSBLUR.Collections.Folders.organizer_sortorder = this.options.sorting;
        NEWSBLUR.assets.folders.sort();
        
        this.feedlist = new NEWSBLUR.Views.FeedList({
            feed_chooser: true,
            organizer: true,
            sorting: this.options.sorting
        }).make_feeds();
        var $feeds = this.feedlist.$el;
        if (this.options.resize) {
            $feeds.css({'max-height': this.options.resize});
        }
        if ($feeds.data('sortable')) $feeds.data('sortable').disable();
        
        // Expand collapsed folders
        $('.NB-folder-collapsed', $feeds).css({
            'display': 'block',
            'opacity': 1
        }).removeClass('NB-folder-collapsed');
        
        // Pretend unfetched feeds are fine
        $('.NB-feed-unfetched', $feeds).removeClass('NB-feed-unfetched');

        // Make sure all folders are visible
        $('.NB-folder.NB-hidden', $feeds).removeClass('NB-hidden');

        NEWSBLUR.Collections.Folders.organizer_sortorder = null;
        NEWSBLUR.assets.folders.sort();
        
        NEWSBLUR.assets.feeds.off('change:highlighted')
                             .on('change:highlighted', _.bind(this.change_selection, this));
        
        return $feeds;
    },
    
    // =============
    // = Selecting =
    // =============
    
    change_select: function(select) {
        if (select == "all") {
            this.feedlist.folder_view.highlight_feeds({force_highlight: true});
        } else if (select == "none") {
            this.feedlist.folder_view.highlight_feeds({force_deselect: true});
        }
    },
    
    change_selection: function() {
        var $title = $(".NB-organizer-selects .NB-organizer-action-title", this.$modal);
        
        var count = this.feedlist.folder_view.highlighted_count();
        if (!count) {
            $title.text("Select");
        } else {
            $title.text(count + " selected");
        }
    },
    
    // ===========
    // = Sorting =
    // ===========
    
    change_sort: function(sorting) {
        this.options.sorting = sorting;
        
        $(".NB-action-"+sorting, this.$modal).addClass('NB-active').siblings().removeClass('NB-active');

        $(".NB-feedlist", this.$modal).replaceWith(this.make_feeds());
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-organizer-action', childOf: '.NB-organizer-sorts' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            var sort = $t.attr('class').match(/\bNB-action-(\w+)\b/)[1];
            this.change_sort(sort);
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-organizer-action', childOf: '.NB-organizer-selects' },
                   _.bind(function($t, $p) {
            e.preventDefault();
            
            var select = $t.attr('class').match(/\bNB-action-select-(\w+)\b/)[1];
            this.change_select(select);
        }, this));
        
    }
    
});