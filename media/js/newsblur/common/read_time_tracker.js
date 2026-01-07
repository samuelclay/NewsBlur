// read_time_tracker.js - Tracks active reading time for stories
//
// Philosophy: We want to measure genuine reading engagement, not just time
// with the page open. We use a "grace period" approach:
//
// - When user shows activity (scroll, mouse move, keypress), we grant them
//   a grace period where we assume they're still reading
// - Grace period is 2 minutes - long enough to read a full page/screen of text
//   without needing to scroll or interact
// - If no activity for 2+ minutes, we stop counting until next activity
// - Window must be focused (tab visible) to count at all
// - We also use Page Visibility API as a backup for tab switching
//
NEWSBLUR.ReadTimeTracker = {

    current_story_hash: null,
    read_times: {},           // {story_hash: accumulated_seconds}
    last_activity: null,
    timer_interval: null,
    is_window_focused: true,
    is_page_visible: true,
    IDLE_THRESHOLD_MS: 120000, // 2 minutes idle = stop counting
    TICK_INTERVAL_MS: 1000,    // Check every second

    start_tracking: function(story_hash) {
        if (!story_hash) return;

        // Stop tracking previous story if any
        this.stop_tracking();

        this.current_story_hash = story_hash;
        this.last_activity = Date.now();

        // Note: read_times entry is created on first _tick when user is active,
        // not here. This avoids creating entries that never get used.

        // Start the timer
        var self = this;
        this.timer_interval = setInterval(function() {
            self._tick();
        }, this.TICK_INTERVAL_MS);

        // NEWSBLUR.log(['ReadTimeTracker started', story_hash]);
    },

    stop_tracking: function() {
        if (this.timer_interval) {
            clearInterval(this.timer_interval);
            this.timer_interval = null;
        }
        this.current_story_hash = null;
    },

    get_and_reset_read_time: function(story_hash) {
        if (!story_hash || !(story_hash in this.read_times)) {
            return 0;
        }

        var seconds = this.read_times[story_hash];
        delete this.read_times[story_hash];

        // NEWSBLUR.log(['ReadTimeTracker get_and_reset', story_hash, seconds]);
        return seconds;
    },

    record_activity: function() {
        this.last_activity = Date.now();
    },

    set_window_focused: function(focused) {
        this.is_window_focused = focused;
        if (focused) {
            this.record_activity();
        }
    },

    set_page_visible: function(visible) {
        this.is_page_visible = visible;
        if (visible) {
            this.record_activity();
        }
    },

    _tick: function() {
        if (!this.current_story_hash) return;
        if (!this.is_window_focused) return;
        if (!this.is_page_visible) return;

        var now = Date.now();
        var idle_time = now - this.last_activity;

        // Only accumulate if user has been active within idle threshold
        if (idle_time < this.IDLE_THRESHOLD_MS) {
            // Initialize if needed (in case it was deleted on idle)
            if (!(this.current_story_hash in this.read_times)) {
                this.read_times[this.current_story_hash] = 0;
            }
            this.read_times[this.current_story_hash] += 1;
        } else if (this.current_story_hash in this.read_times) {
            // User went idle - delete accumulated time to prevent memory leak.
            // When they come back and start interacting again, we'll start
            // fresh. This ensures we're measuring continuous reading sessions.
            delete this.read_times[this.current_story_hash];
        }
    },

    // Bind activity events to common story containers
    bind_activity_events: function() {
        var self = this;
        var record_activity = function() {
            self.record_activity();
        };

        // Scroll events on story containers
        $(document).on('scroll', '.NB-feed-stories-container', record_activity);
        $(document).on('scroll', '.NB-story-content', record_activity);
        $(document).on('scroll', '.NB-text-view', record_activity);

        // Mouse movement on story content
        $(document).on('mousemove', '.NB-feed-story', record_activity);
        $(document).on('mousemove', '.NB-story-content', record_activity);
        $(document).on('mousemove', '.NB-text-view', record_activity);

        // Keyboard activity
        $(document).on('keydown', record_activity);

        // Window focus/blur
        $(window).on('focus', function() {
            self.set_window_focused(true);
        });
        $(window).on('blur', function() {
            self.set_window_focused(false);
        });

        // Page Visibility API - catches tab switches more reliably
        if (typeof document.hidden !== 'undefined') {
            $(document).on('visibilitychange', function() {
                self.set_page_visible(!document.hidden);
            });
        }

        // Also track scroll on the main content pane
        $('.NB-feed-stories').on('scroll', record_activity);
    }

};
