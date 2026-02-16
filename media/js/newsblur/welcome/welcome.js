NEWSBLUR.Welcome = Backbone.View.extend({

    el: '.NB-body-inner',
    flags: {},

    events: {
        "click .NB-button-tryout": "show_tryout",
        "click .NB-button-login": "scroll_to_login",
        "click .NB-segment-option": "toggle_form_mode"
    },

    initialize: function () {
        this.init_webgl_background();
        this.watch_theme_changes();
        NEWSBLUR.reader.$s.$layout.hide();
    },

    // ==========
    // = WebGL  =
    // ==========

    init_webgl_background: function () {
        var canvas = document.getElementById('welcome-canvas');
        if (!canvas) return;

        if (NEWSBLUR.WelcomeBackground && NEWSBLUR.WelcomeBackground.init(canvas)) {
            var isDark = $('body').hasClass('NB-dark');
            NEWSBLUR.WelcomeBackground.setThemeImmediate(isDark);
            NEWSBLUR.WelcomeBackground.start();
        }
    },

    // ==========
    // = Theme  =
    // ==========

    watch_theme_changes: function () {
        var observer = new MutationObserver(function (mutations) {
            for (var i = 0; i < mutations.length; i++) {
                if (mutations[i].attributeName === 'class') {
                    var isDark = $('body').hasClass('NB-dark');
                    if (NEWSBLUR.WelcomeBackground) {
                        NEWSBLUR.WelcomeBackground.setTheme(isDark);
                    }
                    break;
                }
            }
        });
        observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
        this._themeObserver = observer;
    },

    // ====================
    // = Segment Control  =
    // ====================

    toggle_form_mode: function (e) {
        var $option = $(e.currentTarget);
        var is_signup = $option.hasClass('NB-segment-signup');

        this.$('.NB-segment-option').removeClass('NB-active');
        $option.addClass('NB-active');

        this.$('.NB-welcome-header-segment')[is_signup ? 'addClass' : 'removeClass']('NB-segment-right');

        var $active = this.$('.NB-formcard-panel.NB-active');
        var $next = is_signup ? this.$('.NB-formcard-signup') : this.$('.NB-formcard-login');
        var $card = this.$('.NB-welcome-header-formcard');

        if ($active[0] === $next[0]) return;

        var start_height = $card.height();

        // Stage 1: Fade out the active panel
        $active.fadeOut(150, function () {
            $active.removeClass('NB-active');

            // Measure target height with next panel visible but invisible
            $next.css({ display: 'block', opacity: 0 }).addClass('NB-active');
            var end_height = $card.height();

            // Lock card at start height
            $card.css({ height: start_height, overflow: 'hidden' });

            // Stage 2: Animate height to make room, then fade in content
            $card.animate({ height: end_height }, {
                duration: 200,
                easing: 'easeInOutQuint',
                complete: function () {
                    $card.css({ height: '', overflow: '' });
                    // Stage 3: Fade in the new panel
                    $next.animate({ opacity: 1 }, { duration: 180 });
                }
            });
        });
    },

    scroll_to_login: function () {
        this.hide_tryout();
        this.$el.scrollTo(0, 500, { queue: false, easing: 'easeInOutQuint' });
        _.delay(_.bind(function () {
            this.$('.NB-welcome-header-formcard input[type=text]').first().focus();
        }, this), 520);
    },

    // ==========
    // = Tryout =
    // ==========

    is_mobile: function () {
        return window.innerWidth <= 768;
    },

    activate_mobile_layout: function () {
        if (!NEWSBLUR.reader) return;
        if (this.flags.mobile_active) return;
        this.flags.mobile_active = true;

        // Show layout if not already visible
        if (!this.flags.loaded) {
            NEWSBLUR.reader.$s.$layout.layout().hide('west', true);
            NEWSBLUR.reader.$s.$layout.show();
            this.flags.loaded = true;
        }

        // Size sidebar to full width BEFORE adding classes to prevent flash
        NEWSBLUR.reader.layout.outerLayout.sizePane('west', window.innerWidth);

        $('body').addClass('NB-mobile-single-pane NB-welcome-tryout-active');
        this.$('.NB-welcome-container').addClass('NB-welcome-tryout');

        this.show_signup_banner();
        this.show_back_to_login_banner();
        this.show_back_to_feeds_toolbar();
        this.watch_story_selection();
    },

    show_tryout: function () {
        if (!NEWSBLUR.reader) return;
        var is_mobile = this.is_mobile();

        if (!this.flags.loaded) {
            NEWSBLUR.reader.$s.$layout.layout().hide('west', true);
            NEWSBLUR.reader.$s.$layout.show();
            this.flags.loaded = true;
        }

        // On mobile, set full-width classes and size the pane BEFORE toggling
        // so the sidebar opens at full width instead of flashing at half-width
        if (is_mobile) {
            $('body').addClass('NB-mobile-single-pane NB-welcome-tryout-active');
            NEWSBLUR.reader.layout.outerLayout.sizePane('west', window.innerWidth);
        }

        var open = NEWSBLUR.reader.toggle_sidebar();

        $('body')[open ? 'addClass' : 'removeClass']('NB-welcome-tryout-active');
        if (is_mobile) {
            $('body')[open ? 'addClass' : 'removeClass']('NB-mobile-single-pane');
        }

        if (!is_mobile) {
            this.$('.NB-welcome-header-hero').animate({
                paddingLeft: open ? 240 : 0
            }, {
                queue: false,
                easing: 'easeInOutQuint',
                duration: 560
            });
        }

        this.$('.NB-welcome-container')[open ? 'addClass' : 'removeClass']('NB-welcome-tryout');

        if (open) {
            this.show_back_to_login_banner();
            this.show_back_to_feeds_toolbar();
            if (is_mobile) {
                this.watch_story_selection();
            }
        } else {
            this.hide_signup_banner();
            this.hide_back_to_login_banner();
            this.hide_back_to_feeds_toolbar();
        }
    },

    hide_tryout: function () {
        if (!NEWSBLUR.reader) return;

        var is_mobile = this.is_mobile();
        this.flags.mobile_active = false;

        this.$('.NB-welcome-container').removeClass('NB-welcome-tryout');
        this.hide_story_pane();
        this.unwatch_story_selection();
        this.hide_signup_banner();
        this.hide_back_to_login_banner();
        this.hide_back_to_feeds_toolbar();

        // Reset URL to welcome page
        if (NEWSBLUR.router) {
            NEWSBLUR.router.navigate('');
        }

        // Show welcome content again
        NEWSBLUR.reader.$s.$body.removeClass('NB-show-reader');
        NEWSBLUR.reader.flags['splash_page_frontmost'] = true;

        if (is_mobile) {
            // Remove CSS full-width override so the layout API controls width,
            // then close sidebar with the built-in slide animation
            $('body').removeClass('NB-welcome-tryout-active NB-mobile-single-pane');

            if (!NEWSBLUR.reader.flags['sidebar_closed']) {
                NEWSBLUR.reader.close_sidebar();
            }

            // Clean up after the slide animation completes (560ms)
            _.delay(_.bind(function () {
                NEWSBLUR.reader.reset_feed();
                NEWSBLUR.reader.$s.$layout.hide();
                this.flags.loaded = false;
            }, this), 600);
        } else {
            $('body').removeClass('NB-welcome-tryout-active');

            // Close sidebar so toggle_sidebar will open it next time
            if (!NEWSBLUR.reader.flags['sidebar_closed']) {
                NEWSBLUR.reader.close_sidebar();
            }

            // Animate hero padding back, then hide layout after animation
            this.$('.NB-welcome-header-hero').animate({
                paddingLeft: 0
            }, {
                queue: false,
                easing: 'easeInOutQuint',
                duration: 560,
                complete: _.bind(function () {
                    NEWSBLUR.reader.reset_feed();
                    NEWSBLUR.reader.$s.$layout.hide();
                    this.flags.loaded = false;
                }, this)
            });
        }
    },

    // ==================
    // = Signup Banner  =
    // ==================

    show_signup_banner: function () {
        if ($('.NB-tryout-signup-banner').length) return;
        if ($('.NB-tryfeed-signup-banner').length) return;

        var self = this;
        var $banner = $.make('div', { className: 'NB-tryout-signup-banner' }, [
            $.make('div', { className: 'NB-tryout-signup-banner-logo' }),
            $.make('div', { className: 'NB-tryout-signup-banner-content' }, [
                $.make('div', { className: 'NB-tryout-signup-banner-text' }, 'This is just the demo.'),
                $.make('div', { className: 'NB-tryout-signup-banner-subtext' }, 'Sign up to read your own feeds.')
            ]),
            $.make('div', { className: 'NB-tryout-signup-banner-button' }, 'Sign up')
        ]);

        $banner.on('click', function () {
            self.scroll_to_login();
        });

        $('#story_titles').find('.NB-story-titles').before($banner);
    },

    hide_signup_banner: function () {
        $('.NB-tryout-signup-banner').remove();
    },

    // ==========================
    // = Back to Login Banner   =
    // ==========================

    show_back_to_login_banner: function () {
        if ($('.NB-tryout-back-banner').length) return;

        var self = this;
        var $banner = $.make('div', { className: 'NB-tryout-back-banner' }, [
            $.make('div', { className: 'NB-tryout-back-banner-arrow' }),
            $.make('div', { className: 'NB-tryout-back-banner-content' }, [
                $.make('div', { className: 'NB-tryout-back-banner-text' }, 'Log In or Sign Up')
            ]),
            $.make('div', { className: 'NB-tryout-back-banner-cta' }, 'Create Account')
        ]);

        $banner.on('click', function () {
            self.scroll_to_login();
        });

        $('.NB-feeds-header-wrapper').prepend($banner);
    },

    hide_back_to_login_banner: function () {
        $('.NB-tryout-back-banner').remove();
    },

    // ==============================
    // = Back to Feeds Toolbar      =
    // ==============================

    show_back_to_feeds_toolbar: function () {
        if ($('.NB-mobile-back-toolbar-feeds').length) return;

        var self = this;
        var $toolbar = $.make('div', { className: 'NB-mobile-back-toolbar NB-mobile-back-toolbar-feeds' }, [
            $.make('div', { className: 'NB-mobile-back-toolbar-arrow' }),
            $.make('div', { className: 'NB-mobile-back-toolbar-text' }, 'Back to feeds')
        ]);

        $toolbar.on('click', function () {
            self.back_to_feeds();
        });

        $('#story_titles').prepend($toolbar);
    },

    hide_back_to_feeds_toolbar: function () {
        $('.NB-mobile-back-toolbar-feeds').remove();
    },

    back_to_feeds: function () {
        if (!NEWSBLUR.reader) return;

        this.hide_story_pane();

        // Reset feed state but stay in tryout mode
        NEWSBLUR.reader.reset_feed();
        NEWSBLUR.reader.$s.$body.removeClass('NB-show-reader');
        NEWSBLUR.reader.flags['splash_page_frontmost'] = true;

        // Reset URL to root
        if (NEWSBLUR.router) {
            NEWSBLUR.router.navigate('');
        }

        // Ensure sidebar is open
        if (NEWSBLUR.reader.flags['sidebar_closed']) {
            NEWSBLUR.reader.open_sidebar();
        }
    },

    // ======================================
    // = Story Selection & Third Pane       =
    // ======================================

    watch_story_selection: function () {
        var self = this;
        // Use capture phase because story_title_view calls stopPropagation
        this._story_click_handler = function (e) {
            if ($(e.target).closest('.NB-story-title').length) {
                _.delay(function () {
                    self.show_story_pane();
                }, 100);
            }
        };
        var el = document.getElementById('story_titles');
        if (el) el.addEventListener('click', this._story_click_handler, true);
    },

    unwatch_story_selection: function () {
        var el = document.getElementById('story_titles');
        if (el && this._story_click_handler) {
            el.removeEventListener('click', this._story_click_handler, true);
        }
        this._story_click_handler = null;
    },

    show_story_pane: function () {
        $('body').addClass('NB-mobile-story-open');
        this.show_story_back_toolbar();
        this.show_story_signup_banner();
    },

    hide_story_pane: function () {
        $('body').removeClass('NB-mobile-story-open');
        this.hide_story_back_toolbar();
        this.hide_story_signup_banner();
    },

    show_story_back_toolbar: function () {
        if ($('.NB-mobile-back-toolbar-stories').length) return;

        var self = this;
        var $toolbar = $.make('div', { className: 'NB-mobile-back-toolbar NB-mobile-back-toolbar-stories' }, [
            $.make('div', { className: 'NB-mobile-back-toolbar-arrow' }),
            $.make('div', { className: 'NB-mobile-back-toolbar-text' }, 'Back to stories')
        ]);

        $toolbar.on('click', function () {
            self.hide_story_pane();
        });

        $('#story_pane').prepend($toolbar);
    },

    hide_story_back_toolbar: function () {
        $('.NB-mobile-back-toolbar-stories').remove();
    },

    // ======================================
    // = Story Pane Signup Banner            =
    // ======================================

    show_story_signup_banner: function () {
        if ($('#story_pane .NB-tryout-signup-banner').length) return;

        var self = this;
        var $banner = $.make('div', { className: 'NB-tryout-signup-banner' }, [
            $.make('div', { className: 'NB-tryout-signup-banner-logo' }),
            $.make('div', { className: 'NB-tryout-signup-banner-content' }, [
                $.make('div', { className: 'NB-tryout-signup-banner-text' }, 'This is just the demo.'),
                $.make('div', { className: 'NB-tryout-signup-banner-subtext' }, 'Sign up to read your own feeds.')
            ]),
            $.make('div', { className: 'NB-tryout-signup-banner-button' }, 'Sign up')
        ]);

        $banner.on('click', function () {
            self.scroll_to_login();
        });

        var $toolbar = $('#story_pane .NB-mobile-back-toolbar-stories');
        if ($toolbar.length) {
            $banner.insertAfter($toolbar);
        } else {
            $('#story_pane').prepend($banner);
        }
    },

    hide_story_signup_banner: function () {
        $('#story_pane .NB-tryout-signup-banner').remove();
    }

});
