NEWSBLUR.Views.FeedNotificationView = Backbone.View.extend({
    
    events: {
        "click .NB-feed-notifications-email"        : "toggle_email",
        "click .NB-feed-notifications-ios"          : "toggle_ios",
        "click .NB-feed-notifications-android"      : "toggle_android",
        "click .NB-feed-notifications-web"          : "toggle_web"
    },
    
    initialize: function() {
    },
        
    render: function() {
        var feed = this.model;
        var $feed = $(_.template('<div class="NB-feed-notification <% if (selected) { %>selected<% } %>>\
            <div class="NB-feed-title"><%= feed.get("feed_title") %></div>\
            <div class="NB-feed-notifications">\
                <div class="NB-feed-notifications-option NB-feed-notifications-email">Email</div>\
                <div class="NB-feed-notifications-option NB-feed-notifications-web">Web</div>\
                <div class="NB-feed-notifications-option NB-feed-notifications-ios">iOS</div>\
                <div class="NB-feed-notifications-option NB-feed-notifications-android">Android</div>\
            </div>\
        </div>\
        ', {
          feed                : feed,
          selected            : this.options.selected,
          frequency_count     : this.frequency_count()
        }));
        
            // <div class="NB-feed-notification-frequency">\
            //     <select name="notifications_frequency">\
            //         <option value="0">Immediately</option>\
            //         <option value="1">Max once an hour</option>\
            //         <option value="1">Max once every six hours</option>\
            //         <option value="1">Max once every twelve hours</option>\
            //         <option value="1">Max once a day</option>\
            //     </select>\
            // </div>\
            // <div class="NB-feed-notification-frequency-count">\
            //     <%= frequency_count %> a day\
            // </div>\

        this.$el.replaceWith($feed);
        this.setElement($feed);
        
        return this;
    },
    
    frequency_count: function() {
        var freq = this.model.get('notification_frequency');
        var story_count = this.model.get('stories_per_month') / 30.0;
        
        if (!freq) freq = 0;
        if (freq == 0) {
            return Inflector.pluralize("story", Math.ceil(story_count), true);
        } else if (freq < 24) {
            return Inflector.pluralize("story", Math.ceil(story_count), true);
        } else if (freq >= 24) {
            return Inflector.pluralize("story", story_count, true);
        }
    },
    
    // ==========
    // = Events =
    // ==========
    
    toggle_email: function() {
        
    }
    
});