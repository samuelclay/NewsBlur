NEWSBLUR.Views.SocialPageLoginView = Backbone.View.extend({
    
    events: {
        "click .NB-feed-story-login"            : "toggle_login_dialog",
        "click .NB-sideoption-login-button"     : "login",
        "click .NB-sideoption-login-signup"     : "signup"
    },
    
    initialize: function() {
    },
    
    render: function() {
        this.$el.html(this.template({
            story: this.model,
            social_services: NEWSBLUR.assets.social_services
        }));
        
        return this;
    },
    
    template: _.template('\
    <div class="NB-sideoption-share-wrapper NB-sideoption-login-wrapper">\
        <div class="NB-sideoption-share NB-sideoption-login">\
            <div class="NB-modal-submit-close NB-sideoption-login-signup NB-modal-submit-button">Create an account</div>\
            <div class="NB-sideoption-divider"></div>\
            <div class="NB-sideoption-share-title">Username or email:</div>\
            <input type="text" name="username" class="NB-input" />\
            <div class="NB-sideoption-share-title">Password:</div>\
            <input type="password" name="password" class="NB-input" />\
            <div class="NB-modal-submit-green NB-sideoption-login-button NB-modal-submit-button">Login</div>\
        </div>\
    </div>\
    '),
    
    toggle_login_dialog: function(options) {
        options = options || {};
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-login');
        var $dialog = this.$('.NB-sideoption-login-wrapper');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $username = this.$('input[name=username]');
        var $password = this.$('input[name=password]');
        
        if (options.close ||
            ($sideoption.hasClass('NB-active') && !options.resize_open)) {
            // Close
            $dialog.animate({
                'height': 0
            }, {
                'duration': 300,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    this.$('.NB-error').remove();
                }, this)
            });
            $sideoption.removeClass('NB-active');
            if ($story_content.data('original_height')) {
                $story_content.animate({
                    'height': $story_content.data('original_height')
                }, {
                    'duration': 300,
                    'easing': 'easeInOutQuint',
                    'queue': false
                });
                $story_content.removeData('original_height');
            }
        } else {
            // Open/resize
            if (!options.resize_open) {
                this.$('.NB-error').remove();
            }
            $sideoption.addClass('NB-active');
            var $clone = $dialog.clone();
            var full_height = $clone.css({
                'height': 'auto',
                'position': 'absolute',
                'visibility': 'hidden'
            }).appendTo($dialog.parent()).outerHeight(true);
            $clone.remove();
            $dialog.animate({
                'height': full_height
            }, {
                'duration': options.immediate ? 0 : 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': function() {
                    $username.focus();
                }
            });
        
            var sideoptions_height = this.$('.NB-feed-story-sideoptions-container').innerHeight() + 12;
            var content_height = $story_content.innerHeight() + $story_comments.innerHeight();

            if (sideoptions_height + full_height > content_height) {
                var original_height = $story_content.height();
                var original_outerHeight = $story_content.outerHeight(true);
                $story_content.animate({
                    'height': original_outerHeight + ((full_height + sideoptions_height) - content_height)
                }, {
                    'duration': 350,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': function() {
                        if (NEWSBLUR.app.story_list) {
                            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                        }
                    }
                }).data('original_height', original_height);
            }
            var login = _.bind(function(e) {
                e.preventDefault();
                this.login();
            }, this);
            
            $username.add($password).unbind('keydown.login')
                     .bind('keydown.login', 'ctrl+return', login)
                     .bind('keydown.login', 'meta+return', login)
                     .bind('keydown.login', 'return', login);

        }
    },
    
    // ==========
    // = Events =
    // ==========
    
    signup: function() {
        
    },
    
    login: function() {
        
    }
        
});