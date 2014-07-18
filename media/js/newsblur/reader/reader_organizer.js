NEWSBLUR.ReaderOrganizer = function(user_id, options) {
    var defaults = {
        width: 800,
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
            this.make_feeds()
        ]);
    },
    
    resize_modal: function(previous_height) {
        var $feedlist = $('.NB-feedchooser', this.$modal);
        var content_height = $feedlist.height() + 82;
        var container_height = this.$modal.parent().height();
        if (content_height > container_height && previous_height != content_height) {
            var chooser_height = $feedlist.height();
            var diff = Math.max(4, content_height - container_height);
            $feedlist.css({'max-height': chooser_height - diff});
            _.defer(_.bind(function() { this.resize_modal(content_height); }, this), 1);
        }
    },
    
    // =============
    // = Feed list =
    // =============
    
    make_feeds: function() {
        var feeds = this.model.feeds;
        this.feed_count = _.unique(NEWSBLUR.assets.folders.feed_ids_in_folder()).length;
        
        var $feeds = new NEWSBLUR.Views.FeedList({
            feed_chooser: true
        }).make_feeds().$el;
        
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
        
        $('.unread_count_positive', $feeds).text('On');
        $('.unread_count_negative', $feeds).text('Off');
        
        return $feeds;
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.feed' }, _.bind(function($t, $p) {
            e.preventDefault();
            
            var feed_id = parseInt($t.attr('data-id'), 10);
            if (_.contains(this.approve_list, feed_id)) {
                this.add_feed_to_decline(feed_id, true);
            } else {
                this.add_feed_to_approve(feed_id, true);
            }
        }, this));
        
    }
    
});