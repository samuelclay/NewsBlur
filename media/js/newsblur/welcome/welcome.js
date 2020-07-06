NEWSBLUR.Welcome = Backbone.View.extend({
    
    el: '.NB-body-inner',
    flags: {},
    rotation: 0,
    
    events: {
        "click .NB-button-login" : "show_signin_form",
        "click .NB-button-tryout" : "show_tryout",
        "click .NB-welcome-header-caption" : "click_header_caption",
        "focus input" : "stop_rotation",
        "mouseenter .NB-welcome-header-caption" : "enter_header_caption",
        "mouseleave .NB-welcome-header-caption" : "leave_header_caption"
    },
    
    initialize: function() {
        this.start_rotation();
        _.delay(_.bind(function() { 
            // this.debug_password_autocomplete();
        }, this), 500);
        NEWSBLUR.reader.$s.$layout.hide();
    },
    
    debug_password_autocomplete: function() {
        console.log(['Triggering focus']);
        this.$("input[name=login-username]").trigger('focus');
    },
    
    // ==========
    // = Header =
    // ==========
    
    fix_misalignment: function(e) {
        console.log(['Fixing misalignment', e]);
        
        this.flags.on_signin = true;
        this.show_signin_form();
    },
    
    click_header_caption: function(e) {
        this.flags.on_signin = false;
        this.enter_header_caption(e);
    },
    
    enter_header_caption: function(e) {
        this.flags.on_header_caption = true;
        var $caption = $(e.currentTarget);
        
        if (this.flags.on_signin) return;
        
        if ($caption.hasClass('NB-welcome-header-caption-signin')) {
            this.flags.on_signin = true;
            this.show_signin_form();
        } else {
            var r = parseInt($caption.data('ss'), 10);
            this.rotate_screenshots(r);
        }
    },
    
    leave_header_caption: function(e) {
        var $caption = $(e.currentTarget);

        if ($caption.hasClass('NB-welcome-header-caption-signin')) {
          
        } else {
            this.flags.on_header_caption = false;
        }
    },
    
    start_rotation: function() {
        if (this.$('.NB-welcome-header-account').hasClass('NB-active')) {
            this.stop_rotation();
        }
        var $first_img = this.$('.NB-welcome-header-image img').eq(0);
        if ($first_img[0].complete) {
            setInterval(_.bind(this.rotate_screenshots, this), 3000);            
        } else {
            $first_img.on('load', _.bind(function() {
                setInterval(_.bind(this.rotate_screenshots, this), 3000);
            }, this));
        }
    },
    
    rotate_screenshots: function(force, callback) {
        if (this.flags.on_header_caption && _.isUndefined(force)) {
            return;
        }
        if (this.flags.on_signin && _.isUndefined(force)) {
            return;
        }
        
        var NUM_CAPTIONS = 3;
        var r = force ? force - 1 : (this.rotation + 1) % NUM_CAPTIONS;
        if (!force) {
            this.rotation += 1;
        }

        var $images = $('.NB-welcome-header-image').add('.NB-welcome-header-account');
        var $captions = $('.NB-welcome-header-caption');
        var $in_img = $images.eq(r);
        var $out_img = $images.not($in_img);
        var $in_caption = $captions.eq(r);
        var $out_caption = $captions.not($in_caption);
        console.log(['Rotate screenshots', force]);
        $out_img.removeClass('NB-active');
        $in_img.addClass('NB-active');

        // $out_img.css({zIndex: 0}).stop(true).animate({
        //     bottom: -300,
        //     opacity: 0
        // }, {easing: 'easeInOutQuart', queue: false, duration: force ? 650 : 1400, complete: callback});
        // $in_img.css({zIndex: 1}).stop(true).animate({
        //     bottom: 0,
        //     opacity: 1
        // }, {easing: 'easeInOutQuart', queue: false, duration: force ? 650 : 1400});
        $out_caption.removeClass('NB-active');
        $in_caption.addClass('NB-active');
        callback && callback();
        if (r < 3) {
            this.$('input').blur();
        }
    },
    
    stop_rotation: function() {
        console.log(['stop_rotation']);
        this.flags.on_signin = true;
    },
    
    show_signin_form: function() {
        var open = !NEWSBLUR.reader.flags['sidebar_closed'];
        this.hide_tryout();
        
        this.flags.on_header_caption = true;
        this.flags.on_signin = true;
        
        var add_url = $.getQueryString('add') || $.getQueryString('url');
        if (add_url) {
            this.$("input[name=next]").val("/?add=" + add_url);
        }
        
        this.$el.scrollTo(0, 500, {queue: false, easing: 'easeInOutQuint'});
        
        _.delay(_.bind(function() {
            this.rotate_screenshots(4, _.bind(function() {
                _.delay(_.bind(function() {
                    if (this.$("input:focus").length) {
                        console.log(['Already focused']);
                        return;
                    }
                    this.$('input[name=login-username]').focus();
                }), 50);
            }, this));
        }, this), open ? 560 : 0);

    },
    
    show_tryout: function() {
        if (!NEWSBLUR.reader) return;
        
        if (!this.flags.loaded) {
            NEWSBLUR.reader.$s.$layout.layout().hide('west', true);
            NEWSBLUR.reader.$s.$layout.show();
            this.flags.loaded = true;
        }
        var open = NEWSBLUR.reader.toggle_sidebar();

        this.$('.NB-inner,.NB-inner-account').animate({
            paddingLeft: open ? 240 : 0
        }, {
            queue: false,
            easing: 'easeInOutQuint',
            duration: 560
        });
        
        this.$('.NB-welcome-container')[open ? 'addClass' : 'removeClass']('NB-welcome-tryout');
    },
    
    hide_tryout: function() {
        if (!NEWSBLUR.reader) return;
        
        NEWSBLUR.reader.close_sidebar();
        
        this.$('.NB-inner,.NB-inner-account').animate({
            paddingLeft: 0
        }, {
            queue: false,
            easing: 'easeInOutQuint',
            duration: 560
        });
        
        this.$('.NB-welcome-container').removeClass('NB-welcome-tryout');
    }

});