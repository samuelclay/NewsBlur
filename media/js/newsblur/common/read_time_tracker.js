// read_time_tracker.js - Tracks active reading time for stories
NEWSBLUR.ReadTimeTracker = {

    current_story_hash: null,
    read_times: {},           // {story_hash: accumulated_seconds}
    last_activity: null,
    timer_interval: null,
    is_window_focused: true,
    IDLE_THRESHOLD_MS: 30000, // 30 seconds idle = stop counting
    TICK_INTERVAL_MS: 1000,   // Check every second

    start_tracking: function(story_hash) {
        if (!story_hash) return;

        // Stop tracking previous story if any
        this.stop_tracking();

        this.current_story_hash = story_hash;
        this.last_activity = Date.now();

        // Initialize read time for this story if not exists
        if (!(story_hash in this.read_times)) {
            this.read_times[story_hash] = 0;
        }

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

    _tick: function() {
        if (!this.current_story_hash) return;
        if (!this.is_window_focused) return;

        var now = Date.now();
        var idle_time = now - this.last_activity;

        // Only accumulate if user has been active within idle threshold
        if (idle_time < this.IDLE_THRESHOLD_MS) {
            this.read_times[this.current_story_hash] += 1;
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

        // Also track scroll on the main content pane
        $('.NB-feed-stories').on('scroll', record_activity);
    }

};
