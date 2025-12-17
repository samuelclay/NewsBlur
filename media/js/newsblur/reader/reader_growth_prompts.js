/**
 * NewsBlur Growth Prompts
 *
 * Strategic upgrade prompts for converting engaged free users to premium.
 * Max one prompt every 30 days. Triggers:
 * - After adding a feed (when user has 5+ feeds)
 * - After reading 20 stories in a session
 */

NEWSBLUR.ReaderGrowthPrompts = function() {
    this.init();
};

NEWSBLUR.ReaderGrowthPrompts.prototype = {

    PROMPT_COOLDOWN_DAYS: 30,  // Global cooldown: max one prompt every 30 days
    SESSION_STORY_THRESHOLD: 20,  // Stories read before showing milestone prompt
    MIN_FEEDS_FOR_PROMPT: 5,  // Minimum feeds before showing feed_added prompt

    init: function() {
        this.session_stories_read = 0;
        this.prompt_shown_this_session = false;
    },

    // Check if test mode is enabled (bypasses premium check and cooldowns)
    // Supports: ?test=growth, ?test=growth1 (feed_added), ?test=growth2 (stories_read)
    is_test_mode: function() {
        var test_param = $.getQueryString('test');
        return test_param && test_param.indexOf('growth') === 0;
    },

    // Get specific test prompt type from URL
    get_test_prompt_type: function() {
        var test_param = $.getQueryString('test');
        if (test_param === 'growth1') return 'feed_added';
        if (test_param === 'growth2') return 'stories_read';
        return null;
    },

    // Check if user is eligible for any growth prompt
    should_show_prompt: function() {
        if (this.is_test_mode()) {
            return true;
        }

        // Only target free users
        if (NEWSBLUR.Globals.is_premium) return false;
        if (!NEWSBLUR.Globals.is_authenticated) return false;

        return true;
    },

    // Get user's feed count
    get_feed_count: function() {
        return NEWSBLUR.assets.feeds.size();
    },

    // Check if ANY prompt was shown recently (global 30-day cooldown)
    was_prompt_shown_recently: function() {
        // Test mode bypasses cooldown
        if (this.is_test_mode()) return false;

        var last_shown = NEWSBLUR.assets.preference('growth_prompt_last_shown');
        if (!last_shown) return false;

        var days_since = (Date.now() - last_shown) / (1000 * 60 * 60 * 24);
        return days_since < this.PROMPT_COOLDOWN_DAYS;
    },

    // Record that a prompt was shown (global timestamp)
    record_prompt_shown: function() {
        NEWSBLUR.assets.preference('growth_prompt_last_shown', Date.now());
        this.prompt_shown_this_session = true;
    },

    // Increment session stories read counter
    increment_stories_read: function() {
        if (!this.should_show_prompt()) return;

        this.session_stories_read++;

        // Check if we should show milestone prompt
        if (this.session_stories_read === this.SESSION_STORY_THRESHOLD) {
            this.maybe_show_milestone_prompt();
        }
    },

    // ============================================
    // PROMPT: Milestone prompt (after adding feed or reading stories)
    // ============================================

    // Call this when user adds a feed (only shows at 5+ feeds)
    on_feed_added: function() {
        if (!this.should_show_prompt()) return false;
        if (this.was_prompt_shown_recently()) return false;
        if (this.prompt_shown_this_session) return false;

        // Only show after user has committed with 5+ feeds
        if (this.get_feed_count() < this.MIN_FEEDS_FOR_PROMPT) return false;

        this.show_milestone_prompt('feed_added');
        return true;
    },

    // ============================================
    // PROMPT: Milestone (after reading N stories)
    // ============================================

    maybe_show_milestone_prompt: function() {
        if (!this.should_show_prompt()) return false;
        if (this.was_prompt_shown_recently()) return false;
        if (this.prompt_shown_this_session) return false;

        this.show_milestone_prompt('stories_read');
        return true;
    },

    show_milestone_prompt: function(trigger) {
        var self = this;
        trigger = trigger || 'stories_read';

        // Timeless copy based on trigger
        var title, subtitle;
        if (trigger === 'feed_added') {
            title = "Upgrade your reading";
            subtitle = "You follow " + this.get_feed_count() + " sites. Premium makes all of them better.";
        } else {
            title = "Get more from NewsBlur";
            subtitle = "Faster updates. Full-text search. Read by folder.";
        }

        var $prompt = $.make('div', { className: 'NB-growth-prompt NB-growth-prompt-milestone NB-growth-prompt-entering' }, [
            // Full-bleed header with animation
            $.make('div', { className: 'NB-growth-prompt-header' }, [
                $.make('div', { className: 'NB-growth-prompt-close' }, '×'),
                $.make('div', { className: 'NB-growth-prompt-particles' }, [
                    $.make('div', { className: 'NB-growth-prompt-particle' }),
                    $.make('div', { className: 'NB-growth-prompt-particle' }),
                    $.make('div', { className: 'NB-growth-prompt-particle' }),
                    $.make('div', { className: 'NB-growth-prompt-particle' }),
                    $.make('div', { className: 'NB-growth-prompt-particle' })
                ]),
                $.make('div', { className: 'NB-growth-prompt-icon' }, [
                    $.make('div', { className: 'NB-growth-prompt-icon-wrapper' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/growth-star.svg' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-growth-prompt-content' }, [
                $.make('div', { className: 'NB-growth-prompt-title' }, title),
                $.make('div', { className: 'NB-growth-prompt-body' }, subtitle),
                $.make('div', { className: 'NB-growth-prompt-features' }, [
                    $.make('div', { className: 'NB-growth-prompt-feature' }, [
                        $.make('div', { className: 'NB-growth-prompt-feature-icon' }),
                        $.make('span', 'Read stories by folder')
                    ]),
                    $.make('div', { className: 'NB-growth-prompt-feature' }, [
                        $.make('div', { className: 'NB-growth-prompt-feature-icon' }),
                        $.make('span', 'Full-text search across all stories')
                    ]),
                    $.make('div', { className: 'NB-growth-prompt-feature' }, [
                        $.make('div', { className: 'NB-growth-prompt-feature-icon' }),
                        $.make('span', '5× faster feed updates')
                    ])
                ]),
                $.make('div', { className: 'NB-growth-prompt-actions' }, [
                    $.make('div', { className: 'NB-growth-prompt-cta' }, 'Go Premium — $36/year'),
                    $.make('div', { className: 'NB-growth-prompt-dismiss' }, 'Maybe later')
                ])
            ])
        ]);

        $prompt.find('.NB-growth-prompt-cta').click(function() {
            NEWSBLUR.reader.open_premium_upgrade_modal();
            self.close_prompt($prompt);
        });

        $prompt.find('.NB-growth-prompt-close, .NB-growth-prompt-dismiss').click(function() {
            self.close_prompt($prompt);
        });

        this.show_prompt($prompt);
        this.record_prompt_shown();
    },

    // ============================================
    // PROMPT: Feature Gate (when hitting premium feature)
    // ============================================

    show_feature_gate_prompt: function(feature_name, feature_description) {
        var self = this;

        var $prompt = $.make('div', { className: 'NB-growth-prompt NB-growth-prompt-feature-gate NB-growth-prompt-entering' }, [
            $.make('div', { className: 'NB-growth-prompt-header' }, [
                $.make('div', { className: 'NB-growth-prompt-close' }, '×'),
                $.make('div', { className: 'NB-growth-prompt-particles' }, [
                    $.make('div', { className: 'NB-growth-prompt-particle' }),
                    $.make('div', { className: 'NB-growth-prompt-particle' }),
                    $.make('div', { className: 'NB-growth-prompt-particle' })
                ]),
                $.make('div', { className: 'NB-growth-prompt-icon' }, [
                    $.make('div', { className: 'NB-growth-prompt-icon-wrapper' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/growth-rocket.svg' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-growth-prompt-content' }, [
                $.make('div', { className: 'NB-growth-prompt-title' }, feature_name + " is Premium"),
                $.make('div', { className: 'NB-growth-prompt-body' },
                    feature_description + " Unlock this and all premium features."
                ),
                $.make('div', { className: 'NB-growth-prompt-actions' }, [
                    $.make('div', { className: 'NB-growth-prompt-cta' }, 'Unlock for $36/year'),
                    $.make('div', { className: 'NB-growth-prompt-dismiss' }, 'Not now')
                ])
            ])
        ]);

        $prompt.find('.NB-growth-prompt-cta').click(function() {
            NEWSBLUR.reader.open_premium_upgrade_modal();
            self.close_prompt($prompt);
        });

        $prompt.find('.NB-growth-prompt-close, .NB-growth-prompt-dismiss').click(function() {
            self.close_prompt($prompt);
        });

        this.show_prompt($prompt);
    },

    // ============================================
    // Common prompt display/hide methods
    // ============================================

    show_prompt: function($prompt) {
        // Don't show growth prompt if feedchooser or premium upgrade modal is open
        if ($('.NB-modal-feedchooser').length > 0 || $('.NB-modal-premium-upgrade').length > 0) {
            return false;
        }

        // Remove any existing prompts
        $('.NB-growth-prompt').remove();

        // Add to body - animation handled by CSS class
        $('body').append($prompt);
        return true;
    },

    close_prompt: function($prompt) {
        $prompt.removeClass('NB-growth-prompt-entering').addClass('NB-growth-prompt-exiting');

        setTimeout(function() {
            $prompt.remove();
        }, 250);
    },

    // ============================================
    // Trigger checks on various user actions
    // ============================================

    // Called after initial feed load - auto-show in test mode
    check_on_load: function() {
        // In test mode with specific prompt type, auto-show it
        var test_type = this.get_test_prompt_type();
        if (test_type) {
            var self = this;
            // Wait for any modal to close before showing growth prompt
            var attempt_show = function() {
                if ($('.NB-modal-feedchooser').length > 0 || $('.NB-modal-premium-upgrade').length > 0) {
                    // Modal is open, wait and try again
                    setTimeout(attempt_show, 500);
                    return;
                }
                self.show_milestone_prompt(test_type);
            };
            setTimeout(attempt_show, 500);
            return;
        }

        // Normal mode: prompts triggered by user actions only:
        // - on_feed_added(): after adding a feed
        // - maybe_show_milestone_prompt(): after reading 20 stories
        // Max one prompt every 30 days
    }
};

// Initialize globally
NEWSBLUR.growth_prompts = new NEWSBLUR.ReaderGrowthPrompts();
