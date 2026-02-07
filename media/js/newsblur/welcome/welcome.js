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
        NEWSBLUR.reader.$s.$layout.hide();
    },

    // ==========
    // = WebGL  =
    // ==========

    init_webgl_background: function () {
        var canvas = document.getElementById('welcome-canvas');
        if (!canvas) return;

        if (NEWSBLUR.WelcomeBackground && NEWSBLUR.WelcomeBackground.init(canvas)) {
            NEWSBLUR.WelcomeBackground.start();
        }
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

    show_tryout: function () {
        if (!NEWSBLUR.reader) return;

        if (!this.flags.loaded) {
            NEWSBLUR.reader.$s.$layout.layout().hide('west', true);
            NEWSBLUR.reader.$s.$layout.show();
            this.flags.loaded = true;
        }
        var open = NEWSBLUR.reader.toggle_sidebar();

        this.$('.NB-welcome-header-hero').animate({
            paddingLeft: open ? 240 : 0
        }, {
            queue: false,
            easing: 'easeInOutQuint',
            duration: 560
        });

        this.$('.NB-welcome-container')[open ? 'addClass' : 'removeClass']('NB-welcome-tryout');
    },

    hide_tryout: function () {
        if (!NEWSBLUR.reader) return;

        NEWSBLUR.reader.close_sidebar();

        this.$('.NB-welcome-header-hero').animate({
            paddingLeft: 0
        }, {
            queue: false,
            easing: 'easeInOutQuint',
            duration: 560
        });

        this.$('.NB-welcome-container').removeClass('NB-welcome-tryout');
    }

});
