NEWSBLUR.Models.DashboardRiver = Backbone.Model.extend({
    
    initialize: function() {
        var feed_title = NEWSBLUR.reader.feed_title(this.get('feed_id'));
        var favicon_url = this.favicon_url();
        this.set('feed_title', "\"<b>" + this.get('query') + "</b>\" in <b>" + feed_title + "</b>");
        this.set('favicon_url', favicon_url);
        this.list_view;
    },
    
    favicon_url: function() {
        var url;
        var feed_id = this.get('feed_id');
        
        if (feed_id == 'river:' || feed_id == 'river:infrequent') {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/ak-icon-allstories.png';
        } else if (_.string.startsWith(feed_id, 'river:')) {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/g_icn_folder.png';
        } else if (feed_id == "read") {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/g_icn_unread.png';
        } else if (feed_id == "starred") {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/clock.png';
        } else if (_.string.startsWith(feed_id, 'starred:')) {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/reader/tag.png';
        } else if (_.string.startsWith(feed_id, 'feed:')) {
            url = $.favicon(parseInt(feed_id.replace('feed:', ''), 10));
        } else if (_.string.startsWith(feed_id, 'social:')) {
            url = $.favicon(NEWSBLUR.assets.get_feed(feed_id));
        }
        
        if (!url) {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/circular/g_icn_search_black.png';
        }
        
        return url;
    },

    change_feed: function (feed_id) {
        this.set('feed_id', feed_id);
        this.initialize();
    }
    
});

NEWSBLUR.Collections.DashboardRivers = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.DashboardRiver,
        
    comparator: function(a, b) {
        if (a.get('sort_order') > b.get('sort_order'))
            return 1;
        else if (a.get('sort_order') < b.get('sort_order')) return -1;
        return 0;
    },

    count_sides: function () {
        return this.countBy(function () { return this.get('river_side'); });
    },

    left_side_rivers: function () {
        return this.side('left');
    },

    left_side_rivers: function () {
        return this.side('right');
    },

    side: function(side) {
        return this.select(function (river) {
            return river.get('river_side') == side;
        });
    }
        
});
