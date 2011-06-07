(function($) {
    
    NEWSBLUR.MobileReader = function() {
        
        // ===========
        // = Globals =
        // ===========
        
        this.model      = NEWSBLUR.AssetModel.reader();
        this.story_view = 'page';
        this.$s         = {
            $body: $('body'),
            $feed_list: $('#NB-feed-list')
        };
        this.flags      = {
            'feeds_loaded'      : false
        };
        this.locks      = {};
        this.counts     = {};
        this.cache      = {};
        this.constants  = {};
        
        this.runner();
    };
    
    NEWSBLUR.MobileReader.prototype = {
        
        runner: function() {
            this.load_feeds();
        },
        
        // =============
        // = Feed List =
        // =============
        
        load_feeds: function() {
            $.mobile.pageLoading();
            
            this.model.load_feeds_flat($.rescope(this.build_feed_list, this));
        },
        
        build_feed_list: function() {
            var self       = this;
            var folders    = this.model.folders;
            var feeds      = this.model.feeds;
            var $feed_list = this.$s.$feed_list;
            var $feeds     = '';
            _.each(folders, function(items, folder_name) {
                $feeds += '<ul data-role="listview" data-inset="true" data-theme="c" data-dividertheme="b">';
                if (folder_name && folder_name != ' ') {
                    $feeds += _.template('\
                    <li data-role="list-divider"><%= folder_name %></li>', {
                        folder_name : folder_name
                    });
                }
                _.each(items, function(item) {
                    $feeds += self.make_feed_title(item);
                });
                $feeds += '</ul>';
            });
            
            this.flags.feeds_loaded = true;
            $feed_list.html($feeds);
            $('ul', $feed_list).listview();
            $.mobile.pageLoading(true);
        },
        
        make_feed_title: function(feed_id) {
            var feed = this.model.get_feed(feed_id);
            var $feed = _.template('\
            <li>\
                <a href="#" data-feed-id="<%= feed.id %>">\
                    <img src="<%= $.favicon(feed.favicon) %>" class="ui-li-icon">\
                    <%= feed.feed_title %>\
                    <% if (feed.ps) { %>\
                        <span class="ui-li-count ui-li-count-positive"><%= feed.ps %></span>\
                    <% } %>\
                    <% if (feed.nt) { %>\
                        <span class="ui-li-count ui-li-count-positive"><%= feed.nt %></span>\
                    <% } %>\
                    <% if (feed.ng) { %>\
                        <span class="ui-li-count ui-li-count-positive"><%= feed.ng %></span>\
                    <% } %>\
                </a>\
            </li>', {
                feed : feed
            });
            return $feed;
        }
        
    };
    
})(jQuery);