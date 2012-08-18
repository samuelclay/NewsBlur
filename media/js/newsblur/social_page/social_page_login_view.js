NEWSBLUR.Views.SocialPageLoginSignupView = Backbone.View.extend({
    
    events: {
        "click .NC-login-toggle-button"         : "toggle_login_dialog",
        "click .NC-request-toggle-button"       : "toggle_request_dialog",
        "click .NC-logout-button"               : "logout",
        "click .NC-login-button"                : "login",
        "click .NC-request-button"              : "request",
        "click body:not(.NC-popover)"           : "hide_dialogs"
    },
    
    initialize: function() {
    },
    
    hide_dialogs: function(){

    },
    
    toggle_login_dialog: function(options) {
        options = options || {};
        var $popover = this.$('.NC-login-popover');
        var $other_popover = this.$('.NC-request-popover');
        var $login_username = this.$('input[name=login_username]');
        var $login_password = this.$('input[name=login_password]');
        
        if (options.close ||
            ($popover.hasClass('NC-active'))) {
            // Close
            $popover.animate({
                'opacity': 0
            }, {
                'duration': 300,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    this.$('.NB-error').remove();
                }, this)
            });
            $popover.removeClass('NC-active');
        } else {
            // Open/resize
            if (!options.resize_open) {
                this.$('.NB-error').remove();
            }
            $popover.addClass('NC-active');
            $other_popover.removeClass('NC-active');
            $popover.animate({
                'opacity': 1
            }, {
                'duration': options.immediate ? 0 : 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    $login_username.focus();
                }, this)
            });
        
            var login = _.bind(function(e) {
                e.preventDefault();
                this.login();
            }, this);
            
            $login_username.add($login_password)
                 .unbind('keydown.login')
                 .bind('keydown.login', 'ctrl+return', login)
                 .bind('keydown.login', 'meta+return', login)
                 .bind('keydown.login', 'return', login);
        }
    },
    
    toggle_request_dialog: function(options) {
        options = options || {};
        var $popover = this.$('.NC-request-popover');
        var $other_popover = this.$('.NC-login-popover');
        var $request_email = this.$('input[name=request_email]');
        
        if (options.close ||
            ($popover.hasClass('NC-active'))) {
            // Close
            $popover.animate({
                'opacity': 0
            }, {
                'duration': 300,
                'easing': 'easeInOutQuint',
                'queue': false
            });
            $popover.removeClass('NC-active');
        } else {
            $popover.addClass('NC-active');
            $other_popover.removeClass('NC-active');
            $popover.animate({
                'opacity': 1
            }, {
                'duration': options.immediate ? 0 : 350,
                'easing': 'easeInOutQuint',
                'queue': false,
                'complete': _.bind(function() {
                    $request_email.focus();
                }, this)
            });
        
            var login = _.bind(function(e) {
                e.preventDefault();
                this.login();
            }, this);
            
            $request_email
                .unbind('keydown.request')
                .bind('keydown.request', 'ctrl+return', request)
                .bind('keydown.request', 'meta+return', request)
                .bind('keydown.request', 'return', request);
        }
    },
        
    // ==========
    // = Events =
    // ==========
    
    clean: function() {
        this.$('.NB-error').remove();
    },
    
    login: function() {
        this.clean();
        
        var username = this.$('input[name=login_username]').val();
        var password = this.$('input[name=login_password]').val();
        
        NEWSBLUR.assets.login(username, password, _.bind(this.post_login, this), _.bind(this.login_error, this));
    },
    
    post_login: function(data) {
        NEWSBLUR.log(["login data", data]);
        window.location.reload()
    },
    
    login_error: function(data) {
        this.clean();
        
        var error = _.first(_.values(data.errors))[0];
        this.$('.NB-sideoption-login').append($.make('div', { className: 'NB-error' }, error));
        
        this.toggle_login_dialog({resize_open: true});
    },
     
    logout: function() {
        NEWSBLUR.assets.logout(_.bind(this.post_logout, this), _.bind(this.logout_error, this));
    },
    
    post_logout: function(data) {
        window.location.reload()
    },
    
    logout_error: function(data) {
        alert('There was an error trying to logout, ouch.');
    },
    
    request: function() {
        this.clean();        
        var email    = this.$('input[name=request_email]').val();
        
        NEWSBLUR.assets.signup(email, _.bind(this.post_signup, this), _.bind(this.signup_error, this));
    },
    
    post_request: function(data) {
        NEWSBLUR.log(["signup data", data]);
        this.clean();        
        alert('request all set');
    },
    
    request_error: function(data) {
        this.clean();
        alert('request error');
    }        
});