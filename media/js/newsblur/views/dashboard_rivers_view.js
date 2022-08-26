NEWSBLUR.Views.DashboardRivers = Backbone.View.extend({
    
    el: ".NB-dashboard-rivers",

    options: {
        side: 'left'
    },

    initialize: function () {
        var side = this.options.side;
        this.setElement($(".NB-dashboard-rivers-" + side));
        this.$el.empty();
        this.rivers = NEWSBLUR.assets.dashboard_rivers.side(side).map(_.bind(function (river, r) {
            var river_view = new NEWSBLUR.Views.DashboardRiver({
                dashboard_stories: new NEWSBLUR.Collections.Stories({dashboard_river_id: river.get('river_id')}),
                model: river
            });
            // console.log(['Adding river', side, river.get('river_id'), river_view, river_view.$el, this.$el])
            this.$el.append(river_view.$el);
            
            return river_view;
        }, this));

        return this;
    },

    load_all_stories: function () {
        this.rivers.forEach(function (r) { return r.load_stories(); });
    },

    new_story: function (story_hash, timestamp) {
        this.rivers.forEach(function (r) { r.new_story(story_hash, timestamp); });
    },

    mark_read_pubsub: function (story_hash) {
        this.rivers.forEach(function (r) {
            r.options.dashboard_stories.mark_read_pubsub(story_hash);
        });
    },

    mark_unread_pubsub: function (story_hash) {
        this.rivers.forEach(function (r) {
            r.options.dashboard_stories.mark_unread_pubsub(story_hash);
        });
    },

    redraw: function () {
        this.rivers.forEach(function (r) { return r.redraw(); });
    }


});
