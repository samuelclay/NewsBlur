NEWSBLUR.Views.DashboardRivers = Backbone.View.extend({
    
    el: ".NB-dashboard-rivers",

    options: {
        side: 'left'
    },

    initialize: function () {
        var side = this.options.side;
        this.setElement($(".NB-dashboard-rivers-" + side));
        this.rivers = NEWSBLUR.assets.dashboard_rivers.side(side).map(_.bind(function (river, r) {
            var river_view = new NEWSBLUR.Views.DashboardRiver({
                el: '.NB-module-' + river.get('river_side') + '-river-' + river.get('river_order'),
                active_folder: NEWSBLUR.assets.folders,
                dashboard_stories: new NEWSBLUR.Collections.Stories(),
                side: river.get('river_side'),
                model: river
            });
            console.log(['Adding river', side, river.get('river_id'), river_view, river_view.$el, this.$el])
            this.$el.append(river_view.$el);
        }, this));
    },

    load_all_stories: function () {
        this.rivers.each(function (r) { return r.load_stories(); });
    },

    new_story: function (story_hash, timestamp) {
        this.rivers.each(function (r) { r.new_story(story_hash, timestamp); });
    },

    mark_read_pubsub: function (story_hash) {
        this.rivers.each(function (r) {
            r.options.dashboard_stories.mark_read_pubsub(story_hash);
        });
    },

    mark_unread_pubsub: function (story_hash) {
        this.rivers.each(function (r) {
            r.options.dashboard_stories.mark_unread_pubsub(story_hash);
        });
    }


});
