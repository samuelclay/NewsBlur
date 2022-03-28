NEWSBLUR.Views.FollowRequestsModule = Backbone.View.extend({
    
    POLL_INTERVAL: 10 * 60 * 1000,
    
    className: 'NB-module NB-module-followrequests',
    
    initialize: function() {
        _.bindAll(this, 'start_polling');
        NEWSBLUR.assets.user_profile.bind('change:protected', this.start_polling);
    },
    
    start_polling: function() {
        if (NEWSBLUR.assets.user_profile.get('protected') && 
            NEWSBLUR.Globals.is_authenticated) {
            this.poll = setInterval(_.bind(function() {
                this.fetch_follow_requests();
            }, this), this.POLL_INTERVAL);
            this.fetch_follow_requests();
        } else {
            clearInterval(this.poll);
        }
    },
    
    fetch_follow_requests: function() {
        NEWSBLUR.assets.fetch_follow_requests(_.bind(function(data) {
            this.request_profiles = data.request_profiles || [];
            this.make_module();
        }, this));
    },
    
    make_module: function() {
        this.$el.empty();
        
        if (this.request_profiles.length) {
            var $profiles = this.make_follow_requests();
            this.$el.html($.make('h5', 'Requests to Follow You'));
            this.$el.append($profiles);
            if (!this.$el.is(":visible")) {
                this.$el.hide();
                $('.NB-modules-center').prepend(this.$el);
                this.$el.slideDown(800);
            }
        } else {
            this.$el.hide();
        }
    },
    
    make_follow_requests: function() {
        var $profiles = $.make('div', { className: '.NB-followrequests-profiles' });
        
        _.each(this.request_profiles, function(profile) {
            var profile_model = new NEWSBLUR.Models.User(profile);
            var $profile_badge = new NEWSBLUR.Views.SocialProfileBadge({
                model: profile_model,
                request_approval: true
            });
            $profiles.append($profile_badge);
        });
        
        return $profiles;
    }
    
});
