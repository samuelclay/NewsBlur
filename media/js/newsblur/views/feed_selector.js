NEWSBLUR.Views.FeedSelector = Backbone.View.extend({
    
    el: '.NB-feeds-selector',
    
    flags: {},
    
    events: {
        "keyup .NB-feeds-selector-input" : "keyup",
        "keydown .NB-feeds-selector-input" : "keydown"
    },
    
    selected_index: 0,
    
    initialize: function() {
        this.selected_feeds = new NEWSBLUR.Collections.Feeds();
    },
    
    toggle: function() {
        if (this.flags.showing_feed_selector) {
            this.hide_feed_selector();
        } else {
            this.show_feed_selector();
        }
    },
    
    show_feed_selector: function() {
        var $input = this.$(".NB-feeds-selector-input");
        var $feed_list    = NEWSBLUR.reader.$s.$feed_list;
        var $social_feeds = NEWSBLUR.reader.$s.$social_feeds;

        this.$el.show();
        $input.val('');
        $input.focus();
        $feed_list.addClass('NB-selector-active');
        $social_feeds.addClass('NB-selector-active');
        
        this.flags.showing_feed_selector = true;
        NEWSBLUR.reader.layout.leftLayout.sizePane('north');
    },
    
    hide_feed_selector: function() {
        if (!this.flags.showing_feed_selector) return;

        var $input = this.$(".NB-feeds-selector-input");
        var $feed_list    = NEWSBLUR.reader.$s.$feed_list;
        var $social_feeds = NEWSBLUR.reader.$s.$social_feeds;
        
        $input.blur();
        this.$el.hide();
        this.$next_feed = null;
        $feed_list.removeClass('NB-selector-active');
        $social_feeds.removeClass('NB-selector-active');
        $('.NB-feed-selector-selected').removeClass('NB-feed-selector-selected');
                    
        this.flags.showing_feed_selector = false;
        NEWSBLUR.reader.layout.leftLayout.sizePane('north');
    },
    
    filter_feed_selector: function(e) {
        var $input = this.$(".NB-feeds-selector-input");
        var input = $input.val().toLowerCase();
        if (input == this.last_input) return;
        this.last_input = input;
        
        this.selected_feeds.each(function(feed) {
            _.each(feed.views, function(view) {
                view.$el.removeClass('NB-feed-selector-active');
            });
        });
        
        var filter_fn = function(feed){ 
            return _.string.contains(feed.get('feed_title').toLowerCase(), input);
        };
        var feeds = NEWSBLUR.assets.feeds.filter(filter_fn);
        var socialsubs = NEWSBLUR.assets.social_feeds.filter(filter_fn);
        feeds = socialsubs.concat(feeds);
        
        // Clear out shown feeds on empty input
        if (input.length == 0) {
            this.selected_feeds.reset();
        }
        
        if (feeds.length) {
            this.selected_feeds.reset(feeds);
        }
        
        this.selected_feeds.each(function(feed) {
            _.each(feed.views, function(view) {
                view.$el.addClass('NB-feed-selector-active');
            });
        });
        
        this.select(0);
    },
    
    // ==============
    // = Navigation =
    // ==============
    
    keyup: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, enter: 13};
        
        if (e.which == arrow.up || e.which == arrow.down) {
            // return this.navigate(e);
        } else if (e.which == arrow.enter) {
            // return this.open(e);
        }
        
        return this.filter_feed_selector(e);
    },
    
    keydown: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40, enter: 13};
        
        if (e.which == arrow.up || e.which == arrow.down) {
            return this.navigate(e);
        } else if (e.which == arrow.enter) {
            return this.open(e);
        }
        
        // return this.filter_feed_selector(e);
    },
    
    navigate: function(e) {
        var arrow = {left: 37, up: 38, right: 39, down: 40};

        if (e.which == arrow.down) {
            this.select(1);
        } else if (e.which == arrow.up) {
            this.select(-1);
        }
        
        e.preventDefault();
        return false;
    },
    
    select: function(direction) {
        var off, on;
        
        var $current_feed = $('.NB-feed-selector-selected.NB-feed-selector-active');
        this.$next_feed = NEWSBLUR.reader.get_next_feed(direction, $current_feed);
        
        $('.NB-feed-selector-selected').removeClass('NB-feed-selector-selected');
        this.$next_feed.addClass('NB-feed-selector-selected');
    },
    
    open: function(e) {
        NEWSBLUR.reader.open_feed(this.$next_feed.data('id'), this.$next_feed);
        
        e.preventDefault();
        return false;
    }
    
});