NEWSBLUR.Models.DashboardRiver = Backbone.Model.extend({
    
    initialize: function() {
        var feed_title = NEWSBLUR.reader.feed_title(this.get('river_id'));
        this.set('feed_title', "\"<b>" + this.get('query') + "</b>\" in <b>" + feed_title + "</b>");
    },
    
    favicon_url: function() {
        var url;
        var river_id = this.get('river_id');
        
        return $.favicon(river_id);
    },

    change_feed: function (river_id) {
        this.set('river_id', river_id);
        NEWSBLUR.assets.save_dashboard_river(river_id, this.get('river_side'), this.get('river_order'));
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

    right_side_rivers: function () {
        return this.side('right');
    },

    side: function(side) {
        return this.select(function (river) {
            return river.get('river_side') == side;
        });
    }
        
});
