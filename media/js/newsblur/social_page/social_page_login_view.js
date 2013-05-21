NEWSBLUR.Views.SocialPageLoginSignupView = Backbone.View.extend({
    
    events: {
        "click .NB-user-tab"        : "open_user_dropdown",
        "tap .NB-user-tab"          : "open_user_dropdown",
        "click .NB-menu-logout"     : "logout",
        "click .NB-menu-newsblur"   : "open_in_newsblur",
        "click .NB-login-button"    : "login",
        "click .NB-signup-button"   : "signup",
        "click .NB-switch-login-button"  : "switch_login",
        "click .NB-switch-signup-button" : "switch_signup",
        "keypress .NB-login input"  : "maybe_login",
        "keypress .NB-signup input" : "maybe_signup"
    },

    initialize: function() {
        this.setup_login_popover();
    },
    
    setup_login_popover: function() {
        this.login_popover = this.$(".NB-user-tab").clickover({
            html: true,
            placement: "bottom",
            content: this.$(".NB-circular-popover-content").html(),
            title: this.$(".NB-circular-popover-title").html(),
            onShown: _.bind(this.on_show_popover, this),
            onHidden: _.bind(this.on_hide_popover, this)
        });
    },
    
    on_show_popover: function() {
        this.$('.NB-user-tab').addClass('NB-active');
        this.$('.popover input[name=login_username]').focus();
    },
    
    on_hide_popover: function() {
        this.$('.NB-user-tab').removeClass('NB-active');
    },
    
    toggle_login_dialog: function(options) {
        options = options || {};
        
        _.defer(_.bind(function() {
            this.login_popover.data('clickover').clickery();
        }, this));
    },
    
    open_user_dropdown: function(e) {
        e.preventDefault();
        
        if (e.currentTarget != e.target && 
            $(e.target).closest('.NB-tab-inner').parent().get(0) != e.currentTarget) {
            return;
        }
        var $button = this.$(".NB-user-tab");
        
        if (!$button.hasClass('open')) {
            _.defer(function() {
                $('html').one('click', function() {
                    $button.removeClass('open');
                });
            });
            $button.addClass('open');
            this.toggle_login_dialog();
        } else {
            $button.removeClass('open');
        }
        
    },
    
    // ==========
    // = Events =
    // ==========
    
    open_in_newsblur: function(e) {
        console.log(["open_in_newsblur", e]);
        e.preventDefault();
        window.location.href = NEWSBLUR.URLs.newsblur_page;
    },
    
    clean: function() {
        this.$('.NB-error').remove();
    },
    
    maybe_login: function(e) {
        if (e.keyCode == 13) {
            this.login();
        }
    },
    
    maybe_signup: function(e) {
        if (e.keyCode == 13) {
            this.signup();
        }
    },
    
    login: function() {
        this.clean();
        
        var username = this.$('.popover input[name=login_username]').val();
        var password = this.$('.popover input[name=login_password]').val();
        
        NEWSBLUR.assets.login(username, password, _.bind(this.post_login, this), _.bind(this.login_error, this));
    },
    
    post_login: function(data) {
        NEWSBLUR.log(["login data", data]);
        window.location.reload();
    },
    
    login_error: function(data) {
        this.clean();
        
        var error = _.first(_.values(data.errors))[0];
        this.error(error);
    },
     
    logout: function(e) {
        e.preventDefault();
        NEWSBLUR.assets.logout(_.bind(this.post_logout, this), _.bind(this.logout_error, this));
    },
    
    post_logout: function(data) {
        window.location.reload();
    },
    
    logout_error: function(data) {
        alert('There was an error trying to logout, ouch.');
    },
    
    signup: function() {
        this.clean();        
        var username    = this.$('.popover input[name=signup_username]').val();
        var email    = this.$('.popover input[name=signup_email]').val();
        var password    = this.$('.popover input[name=signup_password]').val();
        
        NEWSBLUR.assets.signup(username, email, password, _.bind(this.post_signup, this), _.bind(this.signup_error, this));
    },
    
    post_signup: function(data) {
        window.location.reload();
    },
    
    signup_error: function(data) {
        this.clean();
        
        var error = _.first(_.values(data.errors))[0];
        this.error(error);
    },
    
    error: function(message) {
        this.$('.popover .popover-title').append($.make('div', { className: 'NB-error' }, message));
    },
    
    switch_signup: function() {
        this.clean();
        this.$(".popover").removeClass("NB-show-signup")
                          .removeClass("NB-show-login")
                          .addClass("NB-show-signup");
        this.$('.popover input[name=signup_username]').focus();
    },
    
    switch_login: function() {
        this.clean();
        this.$(".popover").removeClass("NB-show-signup")
                          .removeClass("NB-show-login")
                          .addClass("NB-show-login");
        this.$('.popover input[name=login_username]').focus();
    }
    
});