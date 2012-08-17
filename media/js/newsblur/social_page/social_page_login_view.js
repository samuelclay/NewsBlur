NEWSBLUR.Views.SocialPageLoginView = Backbone.View.extend({
    
    events: {
        "click .NB-feed-story-login"            : "toggle_login_dialog",
        "click .NB-sideoption-login-button"     : "login",
        "click .NB-sideoption-login-signup"     : "switch_to_signup",
        "click .NB-sideoption-signup-login"     : "switch_to_login",
        "click .NB-sideoption-signup-button"    : "signup"
    },
    
    initialize: function() {
        console.log('initialized NEWSBLUR.Views.SocialPageLoginView');
    },
    
    template: _.template('\
    <div class="NB-sideoption-share-wrapper NB-sideoption-login-wrapper">\
        <div class="NB-sideoption-share NB-sideoption-login NB-active">\
            <div class="NB-modal-submit-close NB-sideoption-login-signup NB-modal-submit-button">Create an account</div>\
            <div class="NB-sideoption-divider"></div>\
            <div class="NB-sideoption-share-title">Username or email:</div>\
            <input type="text" name="login_username" class="NB-input" />\
            <div class="NB-sideoption-share-title">Password:</div>\
            <input type="password" name="login_password" class="NB-input" />\
            <div class="NB-modal-submit-green NB-sideoption-login-button NB-modal-submit-button">Login</div>\
        </div>\
        <div class="NB-sideoption-share NB-sideoption-signup">\
            <div class="NB-modal-submit-close NB-sideoption-signup-login NB-modal-submit-button"><small>Have an account?</small><br />Login</div>\
            <div class="NB-sideoption-divider"></div>\
            <div class="NB-sideoption-share-title">Username:</div>\
            <input type="text" name="signup_username" class="NB-input" />\
            <div class="NB-sideoption-share-title">Password:</div>\
            <input type="password" name="signup_password" class="NB-input" />\
            <div class="NB-sideoption-share-title">Email address:</div>\
            <input type="text" name="signup_email" class="NB-input" />\
            <div class="NB-modal-submit-green NB-sideoption-signup-button NB-modal-submit-button">Create Account</div>\
        </div>\
    </div>\
    '),
    
    toggle_login_dialog: function(options) {
        console.log('click login');
        options = options || {};
        var feed_id = this.model.get('story_feed_id');
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-login');
        var $dialog = this.$('.NB-sideoption-login-wrapper');
        var $story_content = this.$('.NB-feed-story-content,.NB-story-content');
        var $story_comments = this.$('.NB-feed-story-comments');
        var $login_username = this.$('input[name=login_username]');
        var $login_password = this.$('input[name=login_password]');
        var $signup_username = this.$('input[name=signup_username]');
        var $signup_password = this.$('input[name=signup_password]');
        var $signup_email = this.$('input[name=signup_email]');
        
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
            $clone.find('.NB-active').css({
                'position': 'relative'
            });
            var dialog_height = $clone.css({
                'height': 'auto',
                'position': 'absolute',
                'visibility': 'hidden'
            }).appendTo($dialog.parent()).outerHeight(true);
            $clone.remove();
            $dialog.animate({
                'height': dialog_height
            }, {
                'duration': options.immediate ? 0 : 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    if (this.$('.NB-sideoption-login').hasClass('NB-active')) {
                        $login_username.focus();
                    } else {
                        $signup_username.focus();
                    }
                    if (options.scroll) {
                        this.scroll_to_login();
                    }
                }, this)
            });
        
            var sideoptions_height = $sideoption.innerHeight() + 12;
            var content_height = $story_content.height() + $story_comments.innerHeight();

            if (sideoptions_height + dialog_height > content_height) {
                var original_height = $story_content.height();
                var original_outerHeight = $story_content.outerHeight(true);
                $story_content.animate({
                    'height': original_height + ((dialog_height + sideoptions_height) - content_height)
                }, {
                    'duration': 350,
                    'easing': 'easeInOutQuint',
                    'queue': false,
                    'complete': _.bind(function() {
                        if (NEWSBLUR.app.story_list) {
                            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
                        }
        
                        if (options.scroll) {
                            this.scroll_to_login();
                        }
                    }, this)
                });
                
                if (!$story_content.data('original_height')) {
                    $story_content.data('original_height', original_height);
                }
            }
            var login = _.bind(function(e) {
                e.preventDefault();
                this.login();
            }, this);
            $login_username.add($login_password)
                     .unbind('keydown.login')
                     .bind('keydown.login', 'ctrl+return', login)
                     .bind('keydown.login', 'meta+return', login)
                     .bind('keydown.login', 'return', login);
                     
            var signup = _.bind(function(e) {
                e.preventDefault();
                this.signup();
            }, this);
            $signup_username.add($signup_password).add($signup_email)
                     .unbind('keydown.login')
                     .bind('keydown.login', 'ctrl+return', signup)
                     .bind('keydown.login', 'meta+return', signup)
                     .bind('keydown.login', 'return', signup);

        }
    },
    
    scroll_to_login: function() {
        var $sideoption = this.$('.NB-sideoption.NB-feed-story-login');
        
        $('body').scrollTo($sideoption, {
            offset: -32,
            duration: 700,
            easing: 'easeInOutQuint',
            queue: false
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    clean: function() {
        this.$('.NB-error').remove();
        this.toggle_login_dialog({resize_open: true});
    },
    
    login: function() {
        this.clean();
        
        var username = this.$('input[name=login_username]').val();
        var password = this.$('input[name=login_password]').val();
        
        NEWSBLUR.assets.login(username, password, _.bind(this.post_login, this), _.bind(this.login_error, this));
    },
    
    post_login: function(data) {
        NEWSBLUR.log(["login data", data]);
        this.clean();
        
        window.location.href = this.options.story_url;
    },
    
    login_error: function(data) {
        this.clean();
        
        var error = _.first(_.values(data.errors))[0];
        this.$('.NB-sideoption-login').append($.make('div', { className: 'NB-error' }, error));
        
        this.toggle_login_dialog({resize_open: true});
    },
    
    signup: function() {
        this.clean();
        
        var username = this.$('input[name=signup_username]').val();
        var password = this.$('input[name=signup_password]').val();
        var email    = this.$('input[name=signup_email]').val();
        
        NEWSBLUR.assets.signup(username, password, email, _.bind(this.post_signup, this), _.bind(this.signup_error, this));
    },
    
    post_signup: function(data) {
        NEWSBLUR.log(["signup data", data]);
        this.clean();
        
        window.location.href = this.options.story_url;
    },
    
    signup_error: function(data) {
        this.clean();
        
        var error = _.first(_.values(data.errors))[0];
        this.$('.NB-sideoption-signup').append($.make('div', { className: 'NB-error' }, error));
        
        this.toggle_login_dialog({resize_open: true});
    },
    
    switch_to_signup: function() {
        this.switch_logins({signup: true});
    },
    
    switch_to_login: function() {
        this.switch_logins({login: true});
    },
    
    switch_logins: function(options) {
        var $login = this.$('.NB-sideoption-login');
        var $signup = this.$('.NB-sideoption-signup');
        var width = $login.closest('.NB-sideoption-share-wrapper').width();

        $login.toggleClass('NB-active', !!options.login);
        $signup.toggleClass('NB-active', !!options.signup);
        
        $login.animate({
            left: !!options.login ? 0 : -1 * width
        });
        $signup.animate({
            left: !!options.signup ? 0 : width
        });
        
        this.clean();
    }
        
});