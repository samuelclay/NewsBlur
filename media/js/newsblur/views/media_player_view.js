// media/js/newsblur/views/media_player_view.js
NEWSBLUR.Views.MediaPlayerView = Backbone.View.extend({

    el: '.NB-media-player',

    POSITION_SYNC_INTERVAL: 10000,
    MINI_PLAYER_HEIGHT: 96,
    QUEUE_HEADER_HEIGHT: 26,
    QUEUE_ITEM_HEIGHT: 34,
    MAX_VISIBLE_QUEUE_ITEMS: 3,
    SPEED_OPTIONS: [0.5, 0.75, 1, 1.25, 1.5, 2, 3],

    SVG_PLAY: '<svg viewBox="0 0 24 24"><polygon points="5,3 19,12 5,21"/></svg>',
    SVG_PAUSE: '<svg viewBox="0 0 24 24"><rect x="5" y="3" width="4" height="18"/><rect x="15" y="3" width="4" height="18"/></svg>',
    SVG_SKIP_BACK: '<svg viewBox="0 0 24 24"><path d="M11.99 5V1l-5 5 5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6h-2c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg>',
    SVG_SKIP_FORWARD: '<svg viewBox="0 0 24 24"><path d="M12.01 5V1l5 5-5 5V7c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6h2c0 4.42-3.58 8-8 8s-8-3.58-8-8 3.58-8 8-8z"/></svg>',
    // Next story, shown while a story is read aloud: the first Listen item in Up Next, else the
    // next story down the list (see listen_next_story_item)
    SVG_SKIP_NEXT: '<svg viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>',
    // Volume icons: mute (X), low (1 arc), medium (2 arcs), high (3 arcs)
    SVG_VOLUME_MUTE: '<svg viewBox="0 0 24 24"><path d="M4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>',
    SVG_VOLUME_LOW: '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3z"/><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/></svg>',
    SVG_VOLUME_MED: '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3z"/><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/><path d="M19 12c0-3.17-1.53-5.99-4-7.73v1.58c1.73 1.49 2.85 3.68 2.85 6.15s-1.12 4.66-2.85 6.15v1.58c2.47-1.74 4-4.56 4-7.73z"/></svg>',
    SVG_VOLUME_HIGH: '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3z"/><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/><path d="M19 12c0-3.17-1.53-5.99-4-7.73v1.58c1.73 1.49 2.85 3.68 2.85 6.15s-1.12 4.66-2.85 6.15v1.58c2.47-1.74 4-4.56 4-7.73z"/><path d="M21.5 12c0-4.28-2.13-8.06-5.5-10.22v1.52c2.61 1.97 4.35 5.13 4.35 8.7s-1.74 6.73-4.35 8.7v1.52c3.37-2.16 5.5-5.94 5.5-10.22z"/></svg>',
    SVG_EXPAND: '<svg viewBox="0 0 24 24"><path d="M7 14l5-5 5 5z"/></svg>',
    SVG_COLLAPSE: '<svg viewBox="0 0 24 24"><path d="M7 10l5 5 5-5z"/></svg>',
    SVG_CLOSE: '<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>',
    SVG_ADD_QUEUE: '<svg viewBox="0 0 24 24"><path d="M14 10H2v2h12v-2zm0-4H2v2h12V6zm4 8v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zM2 16h8v-2H2v2z"/></svg>',
    SVG_PLAY_SMALL: '<svg viewBox="0 0 24 24"><polygon points="5,3 19,12 5,21"/></svg>',
    // Headphone icon for media player branding
    SVG_HEADPHONES: '<svg viewBox="0 0 24 24"><path d="M12 1C7.03 1 3 5.03 3 10v8c0 1.66 1.34 3 3 3h2v-8H5v-3c0-3.87 3.13-7 7-7s7 3.13 7 7v3h-3v8h2c1.66 0 3-1.34 3-3v-8c0-4.97-4.03-9-9-9z"/></svg>',
    SVG_DRAG_HANDLE: '<svg viewBox="0 0 24 24"><path d="M11 18c0 1.1-.9 2-2 2s-2-.9-2-2 .9-2 2-2 2 .9 2 2zm-2-8c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0-6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm6 4c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>',
    SVG_CLEAR: '<svg viewBox="0 0 24 24"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>',
    SVG_FULLSCREEN: '<svg viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>',
    SVG_FULLSCREEN_EXIT: '<svg viewBox="0 0 24 24"><path d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z"/></svg>',
    // Speaking head for stories read aloud by Listen (apps/listen), also the voice settings button
    SVG_LISTEN: '<svg viewBox="0 0 24 24"><circle cx="9" cy="9" r="4"/><path d="M9 15c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4zm7.76-9.64l-1.68 1.69c.84 1.18.84 2.71 0 3.89l1.68 1.69c2.02-2.02 2.02-5.07 0-7.27zM20.07 2l-1.63 1.63c2.77 3.02 2.77 7.56 0 10.74L20.07 16c3.9-3.89 3.91-9.95 0-14z"/></svg>',
    LISTEN_LOADING_DELAY: 700,
    UPCOMING_STORIES_SHOWN: 3,
    PLAYBACK_STATE_REFRESH_MS: 5000,

    events: {
        'click .NB-media-player-play-pause': 'toggle_play_pause',
        'click .NB-media-player-skip-back': 'skip_back',
        'click .NB-media-player-skip-forward': 'skip_forward',
        'click .NB-media-player-next': 'listen_play_next',
        'click .NB-media-player-close': 'close_player',
        'click .NB-media-player-speed': 'cycle_speed',
        'click .NB-media-player-title': 'scroll_to_story',
        'click .NB-media-player-volume-icon': 'toggle_mute',
        'input .NB-media-player-progress': 'on_seek',
        'input .NB-media-player-volume': 'on_volume_change',
        'click .NB-media-player-queue-item': 'play_queue_item',
        'click .NB-media-player-queue-remove': 'remove_queue_item',
        'click .NB-media-player-queue-clear': 'clear_queue',
        'mousedown .NB-queue-drag-handle': 'start_drag',
        'click .NB-media-player-settings': 'open_settings',
        'click .NB-media-player-tab-queue': 'show_queue_tab',
        'click .NB-media-player-tab-history': 'show_history_tab',
        'click .NB-media-player-history-item': 'play_history_item',
        'click .NB-media-player-history-remove': 'remove_history_item',
        'click .NB-media-player-fullscreen': 'toggle_fullscreen',
        'click .NB-media-player-listen-voice-settings': 'open_listen_settings',
        'click .NB-media-player-listen-voice': 'open_listen_settings',
        'click .NB-media-player-listen-upgrade': 'open_listen_upgrade',
        'click .NB-media-player-listen-retry': 'retry_listen',
        'click .NB-media-player-upcoming-item': 'play_upcoming_item'
    },

    SVG_SETTINGS: '<svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 00.12-.61l-1.92-3.32a.49.49 0 00-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 00-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 00-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 00-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1115.6 12 3.61 3.61 0 0112 15.6z"/></svg>',

    initialize: function () {
        this.tab_id = Math.random().toString(36).substr(2, 9);
        this.is_playing = false;
        this.is_muted = false;
        this.current_media = null;
        this.media_element = null;
        this.youtube_player = null;
        this.youtube_api_ready = false;
        this._pending_youtube_id = null;
        this.position_sync_timer = null;
        this.ui_update_timer = null;
        this.playback_rate = 1.0;
        this.volume = 1.0;
        this.queue = [];
        this.history = [];
        this.showing_history = false;
        this.current_position = 0;
        this.current_duration = 0;
        this.skip_back_seconds = 15;
        this.skip_forward_seconds = 30;
        this.auto_play_next = true;
        this.remember_position = true;
        this.resume_on_load = true;
        this.state_restored = false;
        // media_player_view.js: Podcasts and videos keep their own speed; Listen items use the
        // synced listen_speed preference instead.
        this.media_playback_rate = 1.0;
        this.listen_manifest = null;
        this.listen_status = null;
        this.listen_usage = null;
        this.listen_loading = false;
        this.listen_loading_timer = null;
        this.listen_text_view_story_hash = null;
        // media_player_view.js: What plays after the current story depends on the story list, so
        // a new list or stories being marked read refresh the Next story button and the
        // "Then from" stories under Up Next.
        if (NEWSBLUR.assets && NEWSBLUR.assets.stories) {
            this.listenTo(NEWSBLUR.assets.stories, 'reset change:read_status',
                _.debounce(_.bind(this.refresh_listen_upcoming, this), 250));
        }
    },

    // ================
    // = State Restore =
    // ================

    restore_state: function () {
        this.state_restored = true;
        this.bind_playback_state_refresh();

        var state = NEWSBLUR.assets.playback_state;
        if (!state) return;

        // Always restore settings from state, even if we don't show the player
        this.skip_back_seconds = state.skip_back_seconds || 15;
        this.skip_forward_seconds = state.skip_forward_seconds || 30;
        if (state.auto_play_next !== undefined) this.auto_play_next = state.auto_play_next;
        if (state.remember_position !== undefined) this.remember_position = state.remember_position;
        if (state.resume_on_load !== undefined) this.resume_on_load = state.resume_on_load;

        // media_player_view.js: Up Next and history are shared with the iOS and Android Listen
        // players, which queue stories without setting a current item, so they're restored even
        // when there's no player to show. They appear once something plays.
        this.queue = state.queue || [];
        this.history = state.history || [];

        if (!state.current_media_url) return;

        // If resume on load is disabled, don't restore the player UI
        if (this.resume_on_load === false) return;

        this.current_media = {
            story_hash: state.current_story_hash,
            media_url: state.current_media_url,
            media_type: state.current_media_type,
            media_title: state.current_media_title,
            feed_id: state.current_feed_id,
            image_url: state.current_image_url || ''
        };
        this.playback_rate = state.current_playback_rate || 1.0;
        // media_player_view.js: The saved rate is always the podcast and video rate (see
        // saved_playback_rate); Listen items use listen_speed.
        this.media_playback_rate = this.playback_rate;
        this.volume = state.current_volume || 1.0;
        this.current_position = state.current_position || 0;
        this.current_duration = state.current_duration || 0;

        this.probe_queue_durations();

        this.render();
        this.show_player();
        this.create_media_element(this.current_media);

        // Seek to saved position after media loads (don't auto-play)
        var self = this;
        _.delay(function () {
            if (self.remember_position && self.current_position > 0) {
                self.seek_to(self.current_position);
            }
            self.update_progress_display();
        }, 1000);
    },

    // ============
    // = Rendering =
    // ============

    render: function () {
        if (!this.current_media) return this;

        var feed = NEWSBLUR.assets.get_feed(this.current_media.feed_id);
        var favicon_html = feed ? $.favicon_html(feed) : '';
        var feed_title = feed ? feed.get('feed_title') : '';
        var is_video = this.current_media.media_type === 'video' || this.current_media.media_type === 'youtube';
        var has_artwork = !is_video && this.current_media.image_url;

        var html = '<div class="NB-media-player-mini">';

        // Row 1: Now playing info
        html += '<div class="NB-media-player-row-info">';

        // Video container, artwork, or headphone icon
        if (is_video) {
            html += '<div class="NB-media-player-video-container" id="NB-media-player-video-target"></div>';
        } else if (this.is_listen()) {
            html += '<div class="NB-media-player-icon NB-media-player-icon-listen">' + this.SVG_LISTEN + '</div>';
        } else if (has_artwork) {
            html += '<div class="NB-media-player-artwork">';
            html += '<img src="' + _.escape(this.current_media.image_url) + '" />';
            html += '</div>';
        } else {
            html += '<div class="NB-media-player-icon">' + this.SVG_HEADPHONES + '</div>';
        }

        // Info: favicon + feed name + story title, stacked vertically
        html += '<div class="NB-media-player-info">';
        html += '<div class="NB-media-player-feed-row">';
        html += '<div class="NB-media-player-favicon">' + favicon_html + '</div>';
        html += '<div class="NB-media-player-feed-title">' + _.escape(feed_title) + '</div>';
        html += '</div>';
        html += '<div class="NB-media-player-title" title="' + _.escape(this.current_media.media_title) + '">' + _.escape(this.current_media.media_title) + '</div>';
        if (this.is_listen()) {
            html += '<div class="NB-media-player-listen-voice" role="button">' + _.escape(this.listen_voice_label()) + '</div>';
        }
        html += '</div>';

        // Settings + close on info row
        if (this.is_listen()) {
            html += '<div class="NB-media-player-listen-voice-settings" role="button" title="' + _.escape(gettext('Voice settings')) + '">' + this.SVG_LISTEN + '</div>';
        }
        html += '<div class="NB-media-player-settings" title="' + _.escape(gettext('Player settings')) + '">' + this.SVG_SETTINGS + '</div>';
        html += '<div class="NB-media-player-close" title="' + _.escape(gettext('Close player')) + '">' + this.SVG_CLOSE + '</div>';

        html += '</div>'; // end row-info

        // Listen: preview countdown, upgrade prompts and errors. "Preparing audio" shows in the
        // time display instead (see update_listen_loading_display).
        if (this.is_listen()) {
            html += '<div class="NB-media-player-listen-banner"></div>';
        }

        // Row 2: Full-width scrubber
        html += '<div class="NB-media-player-row-scrubber">';
        html += '<input type="range" class="NB-media-player-progress" min="0" max="1000" value="0" />';
        html += '</div>';

        // Row 3: Controls + centered time + speed + volume
        html += '<div class="NB-media-player-row-controls">';
        html += '<div class="NB-media-player-controls">';
        html += '<div class="NB-media-player-skip-back" title="' + _.escape(this.skip_back_title()) + '">' + this.SVG_SKIP_BACK + '</div>';
        html += '<div class="NB-media-player-play-pause" title="' + _.escape(gettext('Play/Pause')) + '">' + (this.is_playing ? this.SVG_PAUSE : this.SVG_PLAY) + '</div>';
        html += '<div class="NB-media-player-skip-forward" title="' + _.escape(this.skip_forward_title()) + '">' + this.SVG_SKIP_FORWARD + '</div>';
        if (this.is_listen()) {
            html += '<div class="NB-media-player-next' + (this.listen_next_story_item() ? '' : ' NB-disabled') + '" title="' + _.escape(gettext('Next story')) + '">' + this.SVG_SKIP_NEXT + '</div>';
        }
        html += '</div>';
        html += '<div class="NB-media-player-time">';
        html += '<span class="NB-media-player-time-current">' + this.format_time(this.current_position) + '</span>';
        html += '<span class="NB-media-player-time-separator">/</span>';
        html += '<span class="NB-media-player-time-duration">' + this.format_time(this.current_duration) + '</span>';
        if (this.is_listen()) {
            html += '<span class="NB-media-player-time-loading">' + _.escape(gettext('Preparing audio...')) + '</span>';
        }
        html += '</div>';
        html += '<div class="NB-media-player-right-controls">';
        html += '<div class="NB-media-player-speed" title="' + _.escape(gettext('Playback speed')) + '">' + this.format_speed(this.playback_rate) + '</div>';
        html += '<div class="NB-media-player-volume-container">';
        html += '<div class="NB-media-player-volume-icon" title="' + _.escape(gettext('Mute')) + '">' + this.get_volume_svg() + '</div>';
        html += '<div class="NB-media-player-volume-popover">';
        html += '<input type="range" class="NB-media-player-volume" min="0" max="100" value="' + Math.round(this.volume * 100) + '" />';
        html += '</div>';
        html += '</div>';
        if (is_video) {
            html += '<div class="NB-media-player-fullscreen" title="' + _.escape(gettext('Fullscreen')) + '">' + this.SVG_FULLSCREEN + '</div>';
        }
        html += '</div>';
        html += '</div>'; // end row-controls

        html += '</div>'; // end mini

        // Queue area (always visible)
        html += '<div class="NB-media-player-queue-area">';
        html += this.render_queue_html();
        html += '</div>';

        this.$el.html(html);
        this.$el.toggleClass('NB-media-player-listening', this.is_listen());
        if (this.is_listen()) {
            this.render_listen_banner({ skip_resize: true });
        }
        this.update_listen_loading_display();
        this.update_progress_display();
        if (is_video) {
            this._bind_fullscreen_change();
        }

        return this;
    },

    render_queue_html: function () {
        var upcoming = this.listen_upcoming_stories(this.UPCOMING_STORIES_SHOWN);
        if (!this.queue.length && !this.history.length && !upcoming.length) return '';

        var html = '<div class="NB-media-player-queue-header">';

        // Segmented control tabs
        html += '<ul class="segmented-control">';
        html += '<li class="NB-media-player-tab-queue' + (!this.showing_history ? ' NB-active' : '') + '">';
        html += _.escape(gettext('Up Next'));
        if (this.queue.length > 0) {
            html += '<span class="NB-media-player-queue-count">' + this.queue.length + '</span>';
        }
        html += '</li>';
        html += '<li class="NB-media-player-tab-history' + (this.showing_history ? ' NB-active' : '') + '">';
        html += _.escape(gettext('History'));
        if (this.history.length > 0) {
            html += '<span class="NB-media-player-history-count">' + this.history.length + '</span>';
        }
        html += '</li>';
        html += '</ul>';

        // Clear button (clears whichever tab is active)
        var active_list = this.showing_history ? this.history : this.queue;
        if (active_list.length > 0) {
            html += '<div class="NB-media-player-queue-clear" title="' + _.escape(gettext('Clear')) + '">' + this.SVG_CLEAR + ' ' + _.escape(gettext('Clear')) + '</div>';
        }

        html += '</div>'; // end header

        // Render active list
        if (this.showing_history) {
            html += this.render_history_list_html();
        } else {
            html += this.render_queue_list_html();
            html += this.render_upcoming_html(upcoming);
        }

        return html;
    },

    render_queue_list_html: function () {
        if (!this.queue.length) return '';

        var html = '<ul class="NB-media-player-queue">';
        for (var i = 0; i < this.queue.length; i++) {
            var item = this.queue[i];
            var feed = NEWSBLUR.assets.get_feed(item.feed_id);
            var favicon_html = feed ? $.favicon_html(feed) : '';
            var type_label = this.media_type_label(item.media_type);
            var added_label = item.added_at ? this.format_relative_date(item.added_at) : '';
            var duration_label = item.duration ? this.format_time(item.duration) : '';
            html += '<li class="NB-media-player-queue-item" data-index="' + i + '">';
            html += '<div class="NB-queue-drag-handle" title="' + _.escape(gettext('Drag to reorder')) + '">' + this.SVG_DRAG_HANDLE + '</div>';
            html += '<div class="NB-queue-favicon">' + favicon_html + '</div>';
            html += '<div class="NB-queue-info">';
            html += '<div class="NB-queue-title">' + _.escape(item.media_title) + '</div>';
            if (added_label || duration_label) {
                html += '<div class="NB-queue-date">';
                if (added_label) html += _.escape(interpolate(gettext("Added %(date)s"), {date: added_label}, true));
                if (added_label && duration_label) html += ' &middot; ';
                if (duration_label) html += duration_label;
                html += '</div>';
            }
            html += '</div>';
            html += '<div class="NB-queue-type">' + type_label + '</div>';
            html += '<div class="NB-media-player-queue-remove" data-index="' + i + '" title="' + _.escape(gettext('Remove')) + '">' + this.SVG_CLOSE + '</div>';
            html += '</li>';
        }
        html += '</ul>';
        return html;
    },

    // media_player_view.js: Under your own queue, the stories Listen auto-continues to: the next
    // unread stories in the list you're reading. Tap one to play it now.
    render_upcoming_html: function (stories) {
        if (!stories || !stories.length) return '';
        var html = '<div class="NB-media-player-upcoming">';
        html += '<div class="NB-media-player-upcoming-header">' + _.escape(interpolate(gettext('Then from %(source)s'), {
            source: this.listen_source_title()
        }, true)) + '</div>';
        html += '<ul class="NB-media-player-queue NB-media-player-upcoming-list">';
        _.each(stories, function (story) {
            var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));
            var title = this.make_listen_item(story).media_title;
            html += '<li class="NB-media-player-upcoming-item" data-story-hash="' + _.escape(story.get('story_hash')) + '">';
            html += '<div class="NB-queue-favicon">' + (feed ? $.favicon_html(feed) : '') + '</div>';
            html += '<div class="NB-queue-info"><div class="NB-queue-title">' + _.escape(title) + '</div></div>';
            html += '</li>';
        }, this);
        html += '</ul></div>';
        return html;
    },

    render_history_list_html: function () {
        if (!this.history.length) return '';

        var html = '<ul class="NB-media-player-queue NB-media-player-history-list">';
        for (var i = 0; i < this.history.length; i++) {
            var item = this.history[i];
            var feed = NEWSBLUR.assets.get_feed(item.feed_id);
            var favicon_html = feed ? $.favicon_html(feed) : '';
            var type_label = this.media_type_label(item.media_type);
            var position_label = this.format_time(item.position || 0);
            var duration_label = this.format_time(item.duration || 0);
            html += '<li class="NB-media-player-history-item" data-index="' + i + '">';
            html += '<div class="NB-queue-favicon">' + favicon_html + '</div>';
            html += '<div class="NB-queue-info">';
            html += '<div class="NB-queue-title">' + _.escape(item.media_title) + '</div>';
            html += '<div class="NB-queue-date">' + position_label + ' / ' + duration_label + '</div>';
            html += '</div>';
            html += '<div class="NB-queue-type">' + type_label + '</div>';
            html += '<div class="NB-media-player-history-remove" data-index="' + i + '" title="' + _.escape(gettext('Remove')) + '">' + this.SVG_CLOSE + '</div>';
            html += '</li>';
        }
        html += '</ul>';
        return html;
    },

    // ====================
    // = Media Detection  =
    // ====================

    detect_media_in_story: function (story, $story_el) {
        var media_items = [];
        var story_hash = story.get('story_hash');
        var story_title = story.get('story_title');
        var feed_id = story.get('story_feed_id');
        var image_url = (story.get('image_urls') && story.get('image_urls')[0]) || '';

        // Detect <audio> elements
        $story_el.find('audio').each(function () {
            var $audio = $(this);
            var src = $audio.find('source').attr('src') || $audio.attr('src');
            if (src) {
                var el = $audio[0];
                var duration = (el.duration && isFinite(el.duration)) ? el.duration : 0;
                media_items.push({
                    story_hash: story_hash,
                    media_url: src,
                    media_type: 'audio',
                    media_title: story_title,
                    feed_id: feed_id,
                    image_url: image_url,
                    duration: duration
                });
            }
        });

        // Detect <video> elements
        $story_el.find('video').each(function () {
            var $video = $(this);
            var src = $video.find('source').attr('src') || $video.attr('src');
            if (src) {
                var el = $video[0];
                var duration = (el.duration && isFinite(el.duration)) ? el.duration : 0;
                media_items.push({
                    story_hash: story_hash,
                    media_url: src,
                    media_type: 'video',
                    media_title: story_title,
                    feed_id: feed_id,
                    image_url: image_url,
                    duration: duration
                });
            }
        });

        // Detect YouTube iframes
        $story_el.find('iframe[src*="youtube.com"], iframe[src*="youtu.be"], iframe[src*="youtube-nocookie.com"]').each(function () {
            var src = $(this).attr('src');
            var video_id = NEWSBLUR.Views.MediaPlayerView.extract_youtube_id(src);
            if (video_id) {
                media_items.push({
                    story_hash: story_hash,
                    media_url: src,
                    media_type: 'youtube',
                    media_title: story_title,
                    feed_id: feed_id,
                    image_url: image_url,
                    youtube_id: video_id
                });
            }
        });

        return media_items;
    },

    // ========================
    // = Playback Abstraction =
    // ========================

    play_media: function (media_item, options) {
        options = options || {};

        // If same item is already playing, just toggle
        if (this.is_currently_playing(media_item)) {
            this.toggle_play_pause();
            return;
        }

        // Remove from queue if it's queued
        if (this.is_in_queue(media_item)) {
            NEWSBLUR.assets.remove_from_media_queue(media_item.story_hash, media_item.media_url, _.bind(function (response) {
                if (response.playback_state) {
                    this.queue = response.playback_state.queue || [];
                    this.render_queue();
                }
            }, this));
        }

        // Save current item to history before switching
        this.add_to_history_from_current();

        this.current_media = media_item;
        this.current_position = options.start_position || 0;
        this.current_duration = 0;
        this.is_playing = false;

        // Render first so the video container exists in the DOM,
        // then create element and play (still within user gesture context)
        this.render();
        this.show_player();

        this.create_media_element(media_item);

        // Seek to handoff position if provided (e.g. from inline playback)
        if (this.current_position > 0) {
            this.seek_to(this.current_position);
        }

        this.play();
        this._update_media_session();

        // Save durable state
        this.save_durable_state();
    },

    create_media_element: function (media_item, listen_options) {
        this.destroy_media_element();

        // media_player_view.js: Listen items play at listen_speed, everything else at the speed
        // last chosen for podcasts and videos.
        this.playback_rate = media_item.media_type === 'listen' ? this.listen_speed() : this.media_playback_rate;
        this.$('.NB-media-player-speed').text(this.format_speed(this.playback_rate));

        if (media_item.media_type === 'listen') {
            this.listen_manifest = null;
            this.listen_status = null;
            this.media_element = new NEWSBLUR.ListenEngine(_.extend({
                story_hash: media_item.story_hash,
                duration: media_item.duration || this.current_duration
            }, listen_options));
            this.media_element.playbackRate = this.playback_rate;
            this.media_element.volume = this.is_muted ? 0 : this.volume;
            this._bind_html5_events(this.media_element);
            this._bind_listen_events(this.media_element);
        } else if (media_item.media_type === 'audio') {
            this.media_element = new Audio(media_item.media_url);
            this.media_element.preload = 'metadata';
            this.media_element.playbackRate = this.playback_rate;
            this.media_element.volume = this.is_muted ? 0 : this.volume;
            this._bind_html5_events(this.media_element);
        } else if (media_item.media_type === 'video') {
            var $container = this.$('.NB-media-player-video-container');
            var $video = $('<video>', { preload: 'metadata' });
            $video.append($('<source>', { src: media_item.media_url }));
            $container.html($video);
            this.media_element = $video[0];
            this.media_element.playbackRate = this.playback_rate;
            this.media_element.volume = this.is_muted ? 0 : this.volume;
            this._bind_html5_events(this.media_element);
        } else if (media_item.media_type === 'youtube') {
            var youtube_id = media_item.youtube_id || NEWSBLUR.Views.MediaPlayerView.extract_youtube_id(media_item.media_url);
            if (youtube_id) {
                this._init_youtube_player(youtube_id);
            }
        }
    },

    destroy_media_element: function () {
        this.stop_ui_updates();
        if (this._fullscreen_handler) {
            document.removeEventListener('fullscreenchange', this._fullscreen_handler);
            this._fullscreen_handler = null;
        }
        if (this.media_element) {
            try {
                this.media_element.pause();
            } catch (e) { }
            if (this.media_element.destroy) {
                this.media_element.destroy();
            }
            this.media_element = null;
        }
        this.stop_listen_loading();
        if (NEWSBLUR.ListenFollowAlong) {
            NEWSBLUR.ListenFollowAlong.clear();
        }
        if (this.youtube_player) {
            try {
                this.youtube_player.destroy();
            } catch (e) { }
            this.youtube_player = null;
        }
    },

    _bind_html5_events: function (el) {
        var self = this;

        el.addEventListener('loadedmetadata', function () {
            self.current_duration = el.duration || 0;
            self.update_progress_display();
        });

        el.addEventListener('play', function () {
            self.is_playing = true;
            self.$('.NB-media-player-play-pause').html(self.SVG_PAUSE);
            self.start_ui_updates();
            self.start_position_sync();
            self.update_listen_buttons();
        });

        el.addEventListener('pause', function () {
            self.is_playing = false;
            self.$('.NB-media-player-play-pause').html(self.SVG_PLAY);
            self.stop_ui_updates();
            self.stop_position_sync();
            self.save_durable_state();
            self.update_listen_buttons();
            self.update_progress_display();
        });

        el.addEventListener('ended', function () {
            self.is_playing = false;
            self.$('.NB-media-player-play-pause').html(self.SVG_PLAY);
            self.stop_ui_updates();
            self.stop_position_sync();
            if (el instanceof NEWSBLUR.ListenEngine) {
                self.on_listen_ended();
            } else {
                self.play_next();
            }
        });

        el.addEventListener('durationchange', function () {
            if (isFinite(el.duration) && el.duration > 0) {
                self.current_duration = el.duration;
                self.update_progress_display();
            }
        });

        el.addEventListener('timeupdate', function () {
            self.current_position = el.currentTime || 0;
            self.current_duration = el.duration || 0;
        });
    },

    // ===================
    // = YouTube API     =
    // ===================

    _load_youtube_api: function () {
        if (window.YT && window.YT.Player) {
            this.youtube_api_ready = true;
            return;
        }
        if (document.querySelector('script[src*="youtube.com/iframe_api"]')) {
            return; // Already loading
        }
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        var first_script = document.getElementsByTagName('script')[0];
        first_script.parentNode.insertBefore(tag, first_script);

        var self = this;
        window.onYouTubeIframeAPIReady = function () {
            self.youtube_api_ready = true;
            if (self._pending_youtube_id) {
                self._create_youtube_player(self._pending_youtube_id);
                self._pending_youtube_id = null;
            }
        };
    },

    _init_youtube_player: function (video_id) {
        if (!this.youtube_api_ready) {
            this._pending_youtube_id = video_id;
            this._load_youtube_api();
            return;
        }
        this._create_youtube_player(video_id);
    },

    _create_youtube_player: function (video_id) {
        var self = this;
        var $container = this.$('.NB-media-player-video-container');
        $container.html('<div id="NB-yt-player"></div>');

        this.youtube_player = new YT.Player('NB-yt-player', {
            height: '45',
            width: '80',
            videoId: video_id,
            playerVars: {
                autoplay: 0,
                controls: 0,
                modestbranding: 1,
                rel: 0,
                enablejsapi: 1
            },
            events: {
                onReady: function (event) {
                    var iframe = event.target.getIframe();
                    if (iframe) {
                        iframe.setAttribute('allowfullscreen', '');
                        iframe.setAttribute('allow', 'fullscreen');
                    }
                    event.target.setPlaybackRate(self.playback_rate);
                    event.target.setVolume(self.is_muted ? 0 : self.volume * 100);
                    if (self.current_position > 0) {
                        event.target.seekTo(self.current_position, true);
                    }
                    // Auto-play if we just initiated playback
                    if (self.is_playing) {
                        event.target.playVideo();
                    }
                },
                onStateChange: function (event) {
                    switch (event.data) {
                        case YT.PlayerState.PLAYING:
                            self.is_playing = true;
                            self.$('.NB-media-player-play-pause').html(self.SVG_PAUSE);
                            self.start_ui_updates();
                            self.start_position_sync();
                            break;
                        case YT.PlayerState.PAUSED:
                            self.is_playing = false;
                            self.$('.NB-media-player-play-pause').html(self.SVG_PLAY);
                            self.stop_ui_updates();
                            self.stop_position_sync();
                            self.save_durable_state();
                            break;
                        case YT.PlayerState.ENDED:
                            self.is_playing = false;
                            self.$('.NB-media-player-play-pause').html(self.SVG_PLAY);
                            self.stop_ui_updates();
                            self.stop_position_sync();
                            self.play_next();
                            break;
                    }
                }
            }
        });
    },

    // ===================
    // = Unified Controls =
    // ===================

    play: function () {
        if (this.media_element && this.media_element.preview_finished) {
            // media_player_view.js: A finished Listen preview stays stopped on its upgrade prompt.
            this.render_listen_banner();
            return;
        }
        if (this.youtube_player && typeof this.youtube_player.playVideo === 'function') {
            this.youtube_player.playVideo();
        } else if (this.media_element) {
            var promise = this.media_element.play();
            if (promise) {
                promise.catch(function () { });
            }
        }
        this.is_playing = true;
        this.$('.NB-media-player-play-pause').html(this.SVG_PAUSE);
        this.update_listen_buttons();
    },

    pause: function () {
        if (this.youtube_player && typeof this.youtube_player.pauseVideo === 'function') {
            this.youtube_player.pauseVideo();
        } else if (this.media_element) {
            this.media_element.pause();
        }
        this.is_playing = false;
        this.$('.NB-media-player-play-pause').html(this.SVG_PLAY);
        this.update_listen_buttons();
    },

    toggle_play_pause: function (e) {
        if (e) e.stopPropagation();
        if (this.is_playing) {
            this.pause();
        } else {
            this.play();
        }
    },

    seek_to: function (seconds) {
        if (this.youtube_player && typeof this.youtube_player.seekTo === 'function') {
            this.youtube_player.seekTo(seconds, true);
        } else if (this.media_element) {
            this.media_element.currentTime = seconds;
        }
        this.current_position = seconds;
        this.update_progress_display();
    },

    skip_back: function (e) {
        if (e) e.stopPropagation();
        var new_pos = Math.max(0, this.get_current_time() - this.skip_back_seconds);
        this.seek_to(new_pos);
    },

    skip_forward: function (e) {
        if (e) e.stopPropagation();
        var new_pos = Math.min(this.get_duration(), this.get_current_time() + this.skip_forward_seconds);
        this.seek_to(new_pos);
    },

    _update_media_session: function () {
        if (!('mediaSession' in navigator) || !this.current_media) return;

        var feed = NEWSBLUR.assets.get_feed(this.current_media.feed_id);
        var artwork = [];
        if (this.current_media.image_url) {
            artwork.push({ src: this.current_media.image_url });
        } else if (this.is_listen() && this.current_media.feed_id) {
            // media_player_view.js: Stories read aloud show the feed's favicon on the lock screen.
            artwork.push({ src: NEWSBLUR.URLs.favicon.replace('{id}', this.current_media.feed_id) });
        }

        navigator.mediaSession.metadata = new MediaMetadata({
            title: this.current_media.media_title || '',
            artist: feed ? feed.get('feed_title') : '',
            artwork: artwork
        });

        var self = this;
        navigator.mediaSession.setActionHandler('play', function () { self.play(); });
        navigator.mediaSession.setActionHandler('pause', function () { self.pause(); });
        navigator.mediaSession.setActionHandler('seekbackward', function (details) {
            var offset = details.seekOffset || self.skip_back_seconds;
            var new_pos = Math.max(0, self.get_current_time() - offset);
            self.seek_to(new_pos);
        });
        navigator.mediaSession.setActionHandler('seekforward', function (details) {
            var offset = details.seekOffset || self.skip_forward_seconds;
            var new_pos = Math.min(self.get_duration(), self.get_current_time() + offset);
            self.seek_to(new_pos);
        });
        navigator.mediaSession.setActionHandler('previoustrack', function () {
            self.skip_back();
        });
        navigator.mediaSession.setActionHandler('nexttrack', function () {
            // media_player_view.js: A story read aloud goes to the next story, the same one the
            // Next story button plays. Podcasts and videos play what's queued, else skip ahead.
            if (self.is_listen()) {
                if (!self.listen_play_next()) self.skip_forward();
            } else if (self.queue.length > 0) {
                self.play_next();
            } else {
                self.skip_forward();
            }
        });
        navigator.mediaSession.setActionHandler('stop', function () {
            self.close_player();
        });
        // media_player_view.js: Lets the system's scrubber (lock screen, media controls) seek.
        try {
            navigator.mediaSession.setActionHandler('seekto', function (details) {
                if (details && _.isNumber(details.seekTime)) self.seek_to(details.seekTime);
            });
        } catch (e) { }
    },

    update_skip_labels: function () {
        this.$('.NB-media-player-skip-back').attr('title', this.skip_back_title());
        this.$('.NB-media-player-skip-forward').attr('title', this.skip_forward_title());
        this.$('.NB-media-player-skip-back .NB-skip-label').text(this.skip_back_seconds);
        this.$('.NB-media-player-skip-forward .NB-skip-label').text(this.skip_forward_seconds);
    },

    open_settings: function (e) {
        if (e) e.stopPropagation();
        NEWSBLUR.MediaPlayerSettingsPopover.create({
            anchor: this.$('.NB-media-player-settings')
        });
    },

    get_current_time: function () {
        if (this.youtube_player && typeof this.youtube_player.getCurrentTime === 'function') {
            return this.youtube_player.getCurrentTime() || 0;
        } else if (this.media_element) {
            return this.media_element.currentTime || 0;
        }
        return this.current_position;
    },

    get_duration: function () {
        if (this.youtube_player && typeof this.youtube_player.getDuration === 'function') {
            return this.youtube_player.getDuration() || 0;
        } else if (this.media_element) {
            return this.media_element.duration || 0;
        }
        return this.current_duration;
    },

    cycle_speed: function (e) {
        if (e) e.stopPropagation();
        var current = this.playback_rate;
        // media_player_view.js: The Listen speed slider allows rates between the presets, so step
        // to the next preset above the current rate.
        var next_rate = _.find(this.SPEED_OPTIONS, function (rate) { return rate > current + 0.001; });
        this.set_playback_rate(next_rate || this.SPEED_OPTIONS[0]);
    },

    // media_player_view.js: The playback state keeps the podcast and video speed. A Listen
    // session's speed lives in listen_speed, so it never carries over to the next podcast.
    saved_playback_rate: function () {
        return this.is_listen() ? this.media_playback_rate : this.playback_rate;
    },

    // media_player_view.js: options.save = false applies the rate without saving it, for the
    // Listen speed slider while it's being dragged (listen_settings_popover.js).
    set_playback_rate: function (rate, options) {
        options = options || {};
        this.playback_rate = Math.round(Math.max(0.5, Math.min(3, parseFloat(rate) || 1)) * 100) / 100;

        if (this.youtube_player && typeof this.youtube_player.setPlaybackRate === 'function') {
            this.youtube_player.setPlaybackRate(this.playback_rate);
        } else if (this.media_element) {
            this.media_element.playbackRate = this.playback_rate;
        }

        this.$('.NB-media-player-speed').text(this.format_speed(this.playback_rate));
        if (options.save === false) return;

        if (this.is_listen()) {
            // media_player_view.js: listen_speed is stored as a decimal string, like "1.05".
            NEWSBLUR.assets.preference('listen_speed', String(this.playback_rate));
        } else {
            this.media_playback_rate = this.playback_rate;
        }
        this.save_durable_state();
        this.trigger('playback_rate_changed', this.playback_rate);
    },

    on_seek: function (e) {
        var val = parseInt(e.target.value, 10);
        var duration = this.get_duration();
        if (duration > 0) {
            var new_pos = (val / 1000) * duration;
            this.seek_to(new_pos);
            this.save_durable_state();
        }
    },

    on_volume_change: function (e) {
        var val = parseInt(e.target.value, 10);
        this.volume = val / 100;
        this.is_muted = this.volume === 0;

        if (this.youtube_player && typeof this.youtube_player.setVolume === 'function') {
            this.youtube_player.setVolume(this.volume * 100);
        } else if (this.media_element) {
            this.media_element.volume = this.volume;
        }

        this.$('.NB-media-player-volume-icon').html(this.get_volume_svg());
    },

    toggle_mute: function (e) {
        if (e) e.stopPropagation();
        this.is_muted = !this.is_muted;

        if (this.youtube_player && typeof this.youtube_player.setVolume === 'function') {
            this.youtube_player.setVolume(this.is_muted ? 0 : this.volume * 100);
        } else if (this.media_element) {
            this.media_element.volume = this.is_muted ? 0 : this.volume;
        }

        this.$('.NB-media-player-volume-icon').html(this.get_volume_svg());
        this.$('.NB-media-player-volume').val(this.is_muted ? 0 : Math.round(this.volume * 100));
    },

    // ==============
    // = Fullscreen =
    // ==============

    toggle_fullscreen: function (e) {
        if (e) e.stopPropagation();
        var target = null;

        if (this.youtube_player) {
            target = this.$('.NB-media-player-video-container iframe')[0];
        } else if (this.media_element && this.media_element.tagName === 'VIDEO') {
            target = this.media_element;
        }

        if (!target) return;

        if (document.fullscreenElement) {
            document.exitFullscreen();
        } else {
            target.requestFullscreen().catch(function () { });
        }
    },

    _bind_fullscreen_change: function () {
        if (this._fullscreen_handler) return;
        var self = this;
        this._fullscreen_handler = function () {
            var $btn = self.$('.NB-media-player-fullscreen');
            if (document.fullscreenElement) {
                $btn.html(self.SVG_FULLSCREEN_EXIT).attr('title', gettext('Exit fullscreen'));
            } else {
                $btn.html(self.SVG_FULLSCREEN).attr('title', gettext('Fullscreen'));
            }
        };
        document.addEventListener('fullscreenchange', this._fullscreen_handler);
    },

    // ==============
    // = Queue Mgmt =
    // ==============

    is_currently_playing: function (media_item) {
        if (!this.current_media || !media_item) return false;
        return this.current_media.story_hash === media_item.story_hash &&
               this.current_media.media_url === media_item.media_url;
    },

    is_in_queue: function (media_item) {
        if (!media_item) return false;
        return _.any(this.queue, function (q) {
            return q.story_hash === media_item.story_hash &&
                   q.media_url === media_item.media_url;
        });
    },

    add_to_queue: function (media_item, position) {
        // If nothing is playing, play immediately instead
        if (!this.current_media) {
            this.play_media(media_item);
            return;
        }

        // Don't queue an item that's already playing
        if (this.is_currently_playing(media_item)) return;

        // If already in queue, remove first then re-add at new position
        if (this.is_in_queue(media_item)) {
            NEWSBLUR.assets.remove_from_media_queue(media_item.story_hash, media_item.media_url, _.bind(function (response) {
                if (response.playback_state) {
                    this.queue = response.playback_state.queue || [];
                }
                this._do_add_to_queue(media_item, position);
            }, this));
            return;
        }

        this._do_add_to_queue(media_item, position);
    },

    _do_add_to_queue: function (media_item, position) {
        var self = this;
        var data = _.extend({}, media_item);
        if (position !== undefined) {
            data.position = position;
        }

        // media_player_view.js: Listen items have no file to probe; their duration comes from the manifest.
        var needs_probe = !data.duration && data.media_type !== 'listen';

        NEWSBLUR.assets.add_to_media_queue(data, _.bind(function (response) {
            if (response.playback_state) {
                this.queue = response.playback_state.queue || [];
                this.render_queue();
            }
            // Probe for duration after queue is updated
            if (needs_probe) {
                var update_duration = function (duration) {
                    if (duration) {
                        var item = _.find(self.queue, function (q) {
                            return q.media_url === data.media_url && q.story_hash === data.story_hash;
                        });
                        if (item && !item.duration) {
                            item.duration = duration;
                            self.render_queue();
                        }
                    }
                };
                if (data.media_type === 'youtube') {
                    var yt_id = data.youtube_id || NEWSBLUR.Views.MediaPlayerView.extract_youtube_id(data.media_url);
                    if (yt_id) this.probe_youtube_duration(yt_id, update_duration);
                } else {
                    this.probe_media_duration(data.media_url, update_duration);
                }
            }
        }, this));
    },

    probe_media_duration: function (url, callback) {
        var probe = new Audio();
        probe.preload = 'metadata';
        probe.addEventListener('loadedmetadata', function () {
            var duration = (probe.duration && isFinite(probe.duration)) ? probe.duration : 0;
            callback(duration);
            probe.src = '';
            probe = null;
        });
        probe.addEventListener('error', function () {
            callback(0);
            probe = null;
        });
        probe.src = url;
    },

    probe_youtube_duration: function (video_id, callback) {
        if (!window.YT || !window.YT.Player) {
            // YouTube API not loaded yet, try after it loads
            var self = this;
            this._load_youtube_api();
            var check = setInterval(function () {
                if (window.YT && window.YT.Player) {
                    clearInterval(check);
                    self._do_probe_youtube(video_id, callback);
                }
            }, 500);
            setTimeout(function () { clearInterval(check); callback(0); }, 5000);
            return;
        }
        this._do_probe_youtube(video_id, callback);
    },

    _do_probe_youtube: function (video_id, callback) {
        var container = document.createElement('div');
        container.style.display = 'none';
        document.body.appendChild(container);
        var probe_el = document.createElement('div');
        container.appendChild(probe_el);

        var probe_player = new YT.Player(probe_el, {
            height: '1',
            width: '1',
            videoId: video_id,
            playerVars: { autoplay: 0, controls: 0 },
            events: {
                onReady: function (event) {
                    var duration = event.target.getDuration() || 0;
                    callback(duration);
                    probe_player.destroy();
                    container.parentNode.removeChild(container);
                },
                onError: function () {
                    callback(0);
                    try { probe_player.destroy(); } catch (e) {}
                    if (container.parentNode) container.parentNode.removeChild(container);
                }
            }
        });
    },

    probe_queue_durations: function () {
        var self = this;
        _.each(this.queue, function (item) {
            if (item.duration || item.media_type === 'listen') return;
            if (item.media_type === 'youtube') {
                var yt_id = item.youtube_id || NEWSBLUR.Views.MediaPlayerView.extract_youtube_id(item.media_url);
                if (yt_id) {
                    self.probe_youtube_duration(yt_id, function (duration) {
                        if (duration) {
                            item.duration = duration;
                            self.render_queue();
                        }
                    });
                }
            } else {
                self.probe_media_duration(item.media_url, function (duration) {
                    if (duration) {
                        item.duration = duration;
                        self.render_queue();
                    }
                });
            }
        });
    },

    remove_queue_item: function (e) {
        e.stopPropagation();
        var index = parseInt($(e.currentTarget).data('index'), 10);
        var item = this.queue[index];
        if (!item) return;

        NEWSBLUR.assets.remove_from_media_queue(item.story_hash, item.media_url, _.bind(function (response) {
            if (response.playback_state) {
                this.queue = response.playback_state.queue || [];
                this.render_queue();
            }
        }, this));
    },

    play_queue_item: function (e) {
        var index = parseInt($(e.currentTarget).data('index'), 10);
        var item = this.queue[index];
        if (!item) return;

        // Remove from queue and play
        NEWSBLUR.assets.remove_from_media_queue(item.story_hash, item.media_url, _.bind(function (response) {
            if (response.playback_state) {
                this.queue = response.playback_state.queue || [];
            }
            this.play_media(item);
        }, this));
    },

    play_next: function () {
        if (this.auto_play_next && this.queue.length > 0) {
            var next_item = this.queue[0];
            NEWSBLUR.assets.remove_from_media_queue(next_item.story_hash, next_item.media_url, _.bind(function (response) {
                if (response.playback_state) {
                    this.queue = response.playback_state.queue || [];
                }
                this.play_media(next_item);
            }, this));
        } else {
            // Queue exhausted or auto-play disabled - stay on last item, paused
            this.is_playing = false;
            this.$('.NB-media-player-play-pause').html(this.SVG_PLAY);
            this.save_durable_state();
        }
    },

    render_queue: function () {
        // media_player_view.js: Never re-render under a queue item being dragged.
        if (this.$('.NB-queue-dragging').length) return;
        this.$('.NB-media-player-queue-area').html(this.render_queue_html());
        this.update_listen_buttons();
        var self = this;
        _.defer(function () {
            self._resize_south_pane(self._calculate_player_height() + 37);
        });
    },

    clear_queue: function (e) {
        if (e) e.stopPropagation();
        if (this.showing_history) {
            NEWSBLUR.assets.clear_media_history(_.bind(function (response) {
                if (response.playback_state) {
                    this.history = response.playback_state.history || [];
                } else {
                    this.history = [];
                }
                this.render_queue();
            }, this));
        } else {
            NEWSBLUR.assets.clear_media_queue(_.bind(function (response) {
                if (response.playback_state) {
                    this.queue = response.playback_state.queue || [];
                } else {
                    this.queue = [];
                }
                this.render_queue();
            }, this));
        }
    },

    // =================
    // = History        =
    // =================

    show_queue_tab: function (e) {
        if (e) e.stopPropagation();
        this.showing_history = false;
        this.render_queue();
    },

    show_history_tab: function (e) {
        if (e) e.stopPropagation();
        this.showing_history = true;
        this.render_queue();
    },

    add_to_history_from_current: function () {
        if (!this.current_media) return;

        var history_item = {
            story_hash: this.current_media.story_hash,
            media_url: this.current_media.media_url,
            media_type: this.current_media.media_type,
            media_title: this.current_media.media_title,
            feed_id: this.current_media.feed_id,
            image_url: this.current_media.image_url || '',
            position: this.get_current_time(),
            duration: this.get_duration()
        };

        NEWSBLUR.assets.add_to_media_history(history_item, _.bind(function (response) {
            if (response.playback_state) {
                this.history = response.playback_state.history || [];
                this.render_queue();
            }
        }, this));
    },

    play_history_item: function (e) {
        if ($(e.target).closest('.NB-media-player-history-remove').length) return;
        e.stopPropagation();

        var index = parseInt($(e.currentTarget).data('index'), 10);
        var item = this.history[index];
        if (!item) return;

        // If something is currently playing, save to history and push to front of queue
        if (this.current_media) {
            this.add_to_history_from_current();
            this.add_to_queue(_.extend({}, this.current_media, {duration: this.get_duration()}), 0);
        }

        // Play the history item (respect remember_position setting)
        var resume_position = this.remember_position ? (item.position || 0) : 0;
        this.current_media = {
            story_hash: item.story_hash,
            media_url: item.media_url,
            media_type: item.media_type,
            media_title: item.media_title,
            feed_id: item.feed_id,
            image_url: item.image_url || ''
        };
        if (item.youtube_id) {
            this.current_media.youtube_id = item.youtube_id;
        }
        this.current_position = resume_position;
        this.current_duration = item.duration || 0;
        this.is_playing = false;

        // Render first so the video container exists in the DOM before
        // creating the YouTube/video player element inside it
        this.render();
        this.show_player();

        this.create_media_element(this.current_media);
        this.play();

        // Seek to saved position after media loads
        var self = this;
        if (resume_position > 0) {
            _.delay(function () {
                self.seek_to(resume_position);
            }, 500);
        }

        this.save_durable_state();
    },

    remove_history_item: function (e) {
        e.stopPropagation();
        var index = parseInt($(e.currentTarget).data('index'), 10);
        var item = this.history[index];
        if (!item) return;

        NEWSBLUR.assets.remove_from_media_history(item.story_hash, item.media_url, _.bind(function (response) {
            if (response.playback_state) {
                this.history = response.playback_state.history || [];
            }
            this.render_queue();
        }, this));
    },

    start_drag: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var self = this;
        var $item = $(e.currentTarget).closest('.NB-media-player-queue-item');
        var start_index = parseInt($item.data('index'), 10);
        var $queue = this.$('.NB-media-player-queue');
        var items = $queue.children('.NB-media-player-queue-item');
        var item_height = $item.outerHeight();
        var start_y = e.pageY;
        var current_index = start_index;

        $item.addClass('NB-queue-dragging');

        var on_mousemove = function (move_e) {
            var delta_y = move_e.pageY - start_y;
            $item.css('transform', 'translateY(' + delta_y + 'px)');

            var new_index = Math.max(0, Math.min(items.length - 1,
                start_index + Math.round(delta_y / item_height)));

            if (new_index !== current_index) {
                items.each(function (i) {
                    if (i === start_index) return;
                    var offset = 0;
                    if (start_index < new_index && i > start_index && i <= new_index) {
                        offset = -item_height;
                    } else if (start_index > new_index && i < start_index && i >= new_index) {
                        offset = item_height;
                    }
                    $(this).css('transform', offset ? 'translateY(' + offset + 'px)' : '');
                });
                current_index = new_index;
            }
        };

        var on_mouseup = function () {
            $(document).off('mousemove.queue_drag mouseup.queue_drag');
            $item.removeClass('NB-queue-dragging');
            items.css('transform', '');

            if (current_index !== start_index) {
                // Reorder the local queue
                var moved = self.queue.splice(start_index, 1)[0];
                self.queue.splice(current_index, 0, moved);
                self.render_queue();

                // Persist to server
                var queue_order = _.map(self.queue, function (q) {
                    return { story_hash: q.story_hash, media_url: q.media_url };
                });
                NEWSBLUR.assets.reorder_media_queue(queue_order, function (response) {
                    if (response.playback_state) {
                        self.queue = response.playback_state.queue || [];
                        self.render_queue();
                    }
                });
            }
        };

        $(document).on('mousemove.queue_drag', on_mousemove);
        $(document).on('mouseup.queue_drag', on_mouseup);
    },

    // ====================
    // = UI Updates       =
    // ====================

    start_ui_updates: function () {
        this.stop_ui_updates();
        var self = this;
        this.ui_update_timer = setInterval(function () {
            self.current_position = self.get_current_time();
            self.current_duration = self.get_duration();
            self.update_progress_display();
        }, 250);
    },

    stop_ui_updates: function () {
        if (this.ui_update_timer) {
            clearInterval(this.ui_update_timer);
            this.ui_update_timer = null;
        }
    },

    update_progress_display: function () {
        var duration = this.current_duration || 0;
        var position = this.current_position || 0;
        var progress = duration > 0 ? (position / duration) * 1000 : 0;

        this.$('.NB-media-player-progress').val(Math.round(progress));
        this.$('.NB-media-player-time-current').text(this.format_time(position));
        this.$('.NB-media-player-time-duration').text(this.format_time(duration));
        this.update_listen_countdown();

        if ('mediaSession' in navigator && duration > 0) {
            navigator.mediaSession.setPositionState({
                duration: duration,
                playbackRate: this.playback_rate,
                position: Math.min(position, duration)
            });
        }
    },

    // ====================
    // = Position Sync    =
    // ====================

    start_position_sync: function () {
        this.stop_position_sync();
        var self = this;
        this.position_sync_timer = setInterval(function () {
            if (self.is_playing && self.current_media) {
                self.sync_position_via_websocket();
            }
        }, this.POSITION_SYNC_INTERVAL);
    },

    stop_position_sync: function () {
        if (this.position_sync_timer) {
            clearInterval(this.position_sync_timer);
            this.position_sync_timer = null;
        }
    },

    sync_position_via_websocket: function () {
        if (!NEWSBLUR.reader || !NEWSBLUR.reader.socket) return;

        NEWSBLUR.reader.socket.emit('media:sync', {
            user_id: NEWSBLUR.Globals.user_id,
            tab_id: this.tab_id,
            story_hash: this.current_media ? this.current_media.story_hash : null,
            media_url: this.current_media ? this.current_media.media_url : null,
            position: this.get_current_time(),
            duration: this.get_duration(),
            is_playing: this.is_playing,
            playback_rate: this.playback_rate,
            volume: this.volume
        });
    },

    save_durable_state: function () {
        if (!this.current_media) return;

        NEWSBLUR.assets.save_playback_state({
            current_story_hash: this.current_media.story_hash,
            current_media_url: this.current_media.media_url,
            current_media_type: this.current_media.media_type,
            current_media_title: this.current_media.media_title,
            current_feed_id: this.current_media.feed_id,
            current_image_url: this.current_media.image_url || '',
            current_position: this.get_current_time(),
            current_duration: this.get_duration(),
            current_playback_rate: this.saved_playback_rate(),
            current_volume: this.volume,
            is_playing: this.is_playing,
            skip_back_seconds: this.skip_back_seconds,
            skip_forward_seconds: this.skip_forward_seconds,
            auto_play_next: this.auto_play_next,
            remember_position: this.remember_position,
            resume_on_load: this.resume_on_load
        });
    },

    // =====================
    // = Multi-tab Sync    =
    // =====================

    handle_media_update: function (data) {
        // Ignore our own echo from the websocket relay
        if (data.tab_id === this.tab_id) return;

        // Another instance closed the player - close here too
        if (data.closed) {
            this.close_player(null, { from_remote: true });
            return;
        }

        // Another tab is playing - pause this one
        if (data.is_playing && this.is_playing) {
            this.pause();
        }
        // Only apply position/duration from the same media item
        if (this.current_media &&
            data.story_hash === this.current_media.story_hash &&
            data.media_url === this.current_media.media_url) {
            if (data.position != null) {
                this.current_position = data.position;
            }
            if (data.duration != null) {
                this.current_duration = data.duration;
            }
            this.update_progress_display();
        }
    },

    // ====================
    // = Layout / Sizing  =
    // ====================

    show_player: function () {
        this.$el.removeClass('NB-hidden');
        var self = this;
        // Defer to measure after flex-wrap layout settles
        _.defer(function () {
            self._resize_south_pane(self._calculate_player_height() + 37);
        });
    },

    hide_player: function () {
        this.$el.addClass('NB-hidden');
        this._resize_south_pane(37);
    },

    _calculate_player_height: function () {
        // Measure actual rendered height to account for flex-wrap
        var el = this.$el[0];
        if (el && el.scrollHeight > 0) {
            return el.scrollHeight;
        }
        // Fallback to estimate
        var height = this.MINI_PLAYER_HEIGHT;
        if (this.queue.length > 0 || this.history.length > 0) {
            height += this.QUEUE_HEADER_HEIGHT;
            var active_list = this.showing_history ? this.history : this.queue;
            if (active_list.length > 0) {
                var visible_items = Math.min(active_list.length, this.MAX_VISIBLE_QUEUE_ITEMS);
                height += visible_items * this.QUEUE_ITEM_HEIGHT;
            }
        }
        return height;
    },

    close_player: function (e, options) {
        options = options || {};
        if (e) e.stopPropagation();
        this.pause();
        this.destroy_media_element();
        this.stop_position_sync();
        this.stop_ui_updates();
        this.current_media = null;
        this.listen_manifest = null;
        this.listen_status = null;
        this.listen_text_view_story_hash = null;
        this.$el.removeClass('NB-media-player-listening');
        this.update_listen_buttons();
        if ('mediaSession' in navigator) {
            navigator.mediaSession.metadata = null;
            navigator.mediaSession.setActionHandler('play', null);
            navigator.mediaSession.setActionHandler('pause', null);
            navigator.mediaSession.setActionHandler('seekbackward', null);
            navigator.mediaSession.setActionHandler('seekforward', null);
            navigator.mediaSession.setActionHandler('previoustrack', null);
            navigator.mediaSession.setActionHandler('nexttrack', null);
            navigator.mediaSession.setActionHandler('stop', null);
            try {
                navigator.mediaSession.setActionHandler('seekto', null);
            } catch (e) { }
        }
        this.hide_player();

        if (!options.from_remote) {
            NEWSBLUR.assets.clear_playback_state();
            // Broadcast close to other tabs/instances via WebSocket
            if (NEWSBLUR.reader && NEWSBLUR.reader.socket) {
                NEWSBLUR.reader.socket.emit('media:sync', {
                    user_id: NEWSBLUR.Globals.user_id,
                    tab_id: this.tab_id,
                    closed: true
                });
            }
        }
    },

    _resize_south_pane: function (height) {
        if (NEWSBLUR.reader && NEWSBLUR.reader.layout && NEWSBLUR.reader.layout.leftLayout) {
            NEWSBLUR.reader.layout.leftLayout.sizePane('south', height);
        }
    },

    scroll_to_story: function (e) {
        if (e) e.stopPropagation();
        if (!this.current_media || !this.current_media.story_hash) return;

        var story_hash = this.current_media.story_hash;
        var feed_id = this.current_media.feed_id;

        // If the story is already in the current story list, scroll to it
        var story = NEWSBLUR.assets.stories.get(story_hash);
        if (story) {
            story.set('selected', true);
            NEWSBLUR.app.story_list.scroll_to_selected_story(story);
            return;
        }

        // Otherwise, open the feed and select the story once it loads
        if (feed_id && NEWSBLUR.reader) {
            NEWSBLUR.reader.open_feed(feed_id, { story_id: story_hash });
        }
    },

    // ===========
    // = Helpers =
    // ===========

    format_time: function (seconds) {
        if (!seconds || isNaN(seconds)) return '0:00';
        seconds = Math.floor(seconds);
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        var s = seconds % 60;
        if (h > 0) {
            return h + ':' + (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
        }
        return m + ':' + (s < 10 ? '0' : '') + s;
    },

    // media_player_view.js: Listen speeds can be fine-grained, like 1.05×.
    format_speed: function (rate) {
        var value = Math.round(rate * 100) / 100;
        return value + (this.is_listen() ? '×' : 'x');
    },

    get_volume_svg: function () {
        if (this.is_muted || this.volume === 0) return this.SVG_VOLUME_MUTE;
        if (this.volume < 0.34) return this.SVG_VOLUME_LOW;
        if (this.volume < 0.67) return this.SVG_VOLUME_MED;
        return this.SVG_VOLUME_HIGH;
    },

    skip_back_title: function () {
        return interpolate(ngettext("Back %(seconds)s second", "Back %(seconds)s seconds", this.skip_back_seconds), {seconds: this.skip_back_seconds}, true);
    },

    skip_forward_title: function () {
        return interpolate(ngettext("Forward %(seconds)s second", "Forward %(seconds)s seconds", this.skip_forward_seconds), {seconds: this.skip_forward_seconds}, true);
    },

    // media_player_view.js: Display label for a queue item's media_type, which stays untranslated
    // because it is stored in the playback state.
    media_type_label: function (media_type) {
        if (media_type === 'audio') return gettext('audio');
        if (media_type === 'video' || media_type === 'youtube') return gettext('video');
        if (media_type === 'listen') return pgettext('media player item read aloud', 'listen');
        return media_type;
    },

    format_relative_date: function (iso_string) {
        if (!iso_string) return '';
        var date = new Date(iso_string);
        var now = new Date();
        var diff_ms = now - date;
        var diff_mins = Math.floor(diff_ms / 60000);
        var diff_hours = Math.floor(diff_ms / 3600000);
        var diff_days = Math.floor(diff_ms / 86400000);

        if (diff_mins < 1) return gettext('just now');
        if (diff_mins < 60) return interpolate(ngettext("%(count)sm ago", "%(count)sm ago", diff_mins), {count: diff_mins}, true);
        if (diff_hours < 24) return interpolate(ngettext("%(count)sh ago", "%(count)sh ago", diff_hours), {count: diff_hours}, true);
        if (diff_days < 7) return interpolate(ngettext("%(count)sd ago", "%(count)sd ago", diff_days), {count: diff_days}, true);
        return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    },

    // ==========
    // = Listen =
    // ==========

    // media_player_view.js: Listen items are stories read aloud by apps/listen. They play through
    // NEWSBLUR.ListenEngine (common/listen_engine.js), which behaves like an <audio> element, and
    // use the stable pseudo URL /listen/story/<story_hash> so the queue, history and restore all
    // work as they do for podcasts.

    is_listen: function () {
        return !!(this.current_media && this.current_media.media_type === 'listen');
    },

    is_listening_to: function (story_hash) {
        return this.is_listen() && this.current_media.story_hash === story_hash;
    },

    listen_engine: function () {
        if (!this.is_listen() || !(this.media_element instanceof NEWSBLUR.ListenEngine)) return null;
        return this.media_element;
    },

    listen_speed: function () {
        var speed = parseFloat(NEWSBLUR.assets.preference('listen_speed'));
        if (!speed || isNaN(speed)) speed = 1.0;
        return Math.max(0.5, Math.min(3, speed));
    },

    listen_pref_enabled: function (preference) {
        var value = NEWSBLUR.assets.preference(preference);
        if (_.isUndefined(value) || value === null) return true;
        return !(value === false || value === 'false' || value === 0 || value === '0');
    },

    listen_selected_voice: function (language) {
        var voices = {};
        try {
            voices = JSON.parse(NEWSBLUR.assets.preference('listen_voices') || '{}') || {};
        } catch (e) {
            voices = {};
        }
        return language ? voices[language] || null : null;
    },

    make_listen_item: function (story) {
        // media_player_view.js: Story titles can carry markup and entities. DOMParser decodes them
        // without loading images or running scripts.
        var raw_title = story.get('story_title') || '';
        var title = new DOMParser().parseFromString(raw_title, 'text/html').body.textContent || raw_title;
        return {
            story_hash: story.get('story_hash'),
            media_url: '/listen/story/' + story.get('story_hash'),
            media_type: 'listen',
            media_title: title,
            feed_id: story.get('story_feed_id'),
            // media_player_view.js: The feed's favicon, absolute so other devices can load it.
            image_url: story.get('story_feed_id') ?
                window.location.origin + NEWSBLUR.URLs.favicon.replace('{id}', story.get('story_feed_id')) : ''
        };
    },

    // media_player_view.js: Plays the story aloud, or pauses/resumes it if it's the current item.
    listen_to_story: function (story) {
        if (!story) return;
        this.play_media(this.make_listen_item(story));
    },

    _bind_listen_events: function (engine) {
        var self = this;

        engine.addEventListener('listen:manifest', function (e) {
            if (engine !== self.media_element) return;
            self.listen_manifest = e.detail;
            if (self.listen_status && self.listen_status.type === 'failure') self.listen_status = null;
            if (e.detail.usage) self.listen_usage = e.detail.usage;
            if (!self.current_media.media_title && e.detail.story_title) {
                self.current_media.media_title = e.detail.story_title;
                self.$('.NB-media-player-title').text(e.detail.story_title);
            }
            self.update_listen_voice_label();
            self.render_listen_banner();
            self.listen_open_text_view(e.detail);
            self.render_queue();
            NEWSBLUR.ListenFollowAlong.start(self.current_media.story_hash, e.detail);
            NEWSBLUR.ListenFollowAlong.set_playing(self.is_playing);
            self.trigger('listen:manifest', e.detail);
        });
        engine.addEventListener('listen:segment', function (e) {
            if (engine !== self.media_element) return;
            NEWSBLUR.ListenFollowAlong.highlight(e.detail.paragraphs);
        });
        engine.addEventListener('listen:usage', function (e) {
            self.listen_usage = e.detail;
            self.trigger('listen:usage', e.detail);
        });
        engine.addEventListener('listen:preview_ended', function () {
            self.listen_status = { type: 'preview_ended' };
            self.stop_listen_loading();
            self.render_listen_banner();
            self.update_listen_buttons();
        });
        engine.addEventListener('listen:limit', function (e) {
            self.listen_status = _.extend({ type: 'limit' }, e.detail);
            self.stop_listen_loading();
            self.render_listen_banner();
        });
        engine.addEventListener('listen:failure', function (e) {
            self.listen_status = _.extend({ type: 'failure' }, e.detail);
            self.stop_listen_loading();
            self.render_listen_banner();
        });
        engine.addEventListener('waiting', function () {
            self.start_listen_loading();
        });
        engine.addEventListener('pause', function () {
            self.stop_listen_loading();
        });
        engine.addEventListener('playing', function () {
            self.stop_listen_loading();
            if (self.listen_status && self.listen_status.type === 'failure') {
                self.listen_status = null;
                self.render_listen_banner();
            }
        });
    },

    listen_voice_label: function () {
        var voice = this.listen_manifest && this.listen_manifest.voice;
        if (voice && voice.name) {
            return interpolate(gettext('Read by %(voice)s'), { voice: voice.name }, true);
        }
        return gettext('Read aloud');
    },

    update_listen_voice_label: function () {
        this.$('.NB-media-player-listen-voice').text(this.listen_voice_label());
    },

    // media_player_view.js: Only shows "Preparing audio" when a segment takes a moment, so the
    // short gap between paragraphs doesn't flash it.
    start_listen_loading: function () {
        if (this.listen_loading_timer || this.listen_loading) return;
        this.listen_loading_timer = setTimeout(_.bind(function () {
            this.listen_loading_timer = null;
            var engine = this.listen_engine();
            if (!engine || engine.paused) return;
            this.listen_loading = true;
            this.update_listen_loading_display();
        }, this), this.LISTEN_LOADING_DELAY);
    },

    stop_listen_loading: function () {
        if (this.listen_loading_timer) {
            clearTimeout(this.listen_loading_timer);
            this.listen_loading_timer = null;
        }
        this.listen_loading = false;
        this.update_listen_loading_display();
    },

    // media_player_view.js: "Preparing audio..." takes the place of the times in the time display
    // (NB-listen-loading in reader.css) rather than a banner row of its own, so pressing Next Story
    // while listening never grows and shrinks the player. Only a Listen story can be loading.
    update_listen_loading_display: function () {
        var loading = !!(this.listen_loading && this.listen_engine());
        this.$('.NB-media-player-time').toggleClass('NB-listen-loading', loading);
    },

    listen_is_archive_tier: function () {
        var usage = this.listen_usage || (this.listen_manifest && this.listen_manifest.usage);
        if (usage && !_.isUndefined(usage.is_archive_tier)) return !!usage.is_archive_tier;
        return !!(NEWSBLUR.Globals.is_archive || NEWSBLUR.Globals.is_pro);
    },

    listen_upgrade_label: function (status) {
        if (!this.listen_is_archive_tier()) return gettext('Upgrade to Premium Archive');
        var usage = this.listen_usage || {};
        var is_pro = usage.tier ? usage.tier === 'pro' : !!NEWSBLUR.Globals.is_pro;
        if (status && status.reason === 'cap_reached' && !is_pro) return gettext('Upgrade to Premium Pro');
        return null;
    },

    render_listen_banner: function (options) {
        options = options || {};
        var $banner = this.$('.NB-media-player-listen-banner');
        if (!$banner.length) return;
        var engine = this.listen_engine();
        var status = this.listen_status;
        var previous_height = $banner.outerHeight();
        var html = '';
        var kind = '';

        if (status && status.type === 'failure') {
            kind = 'error';
            html += '<div class="NB-media-player-listen-message">' + _.escape(status.message) + '</div>';
            html += '<div class="NB-media-player-listen-retry" role="button">' + _.escape(gettext('Retry')) + '</div>';
        } else if (status && (status.type === 'limit' || status.type === 'preview_ended')) {
            kind = 'upgrade';
            var message = status.message;
            if (status.type === 'preview_ended') {
                message = (this.listen_usage && this.listen_usage.upgrade_message) ||
                    gettext('Premium Archive reads whole stories aloud.');
            }
            html += '<div class="NB-media-player-listen-message">' + _.escape(message) + '</div>';
            var upgrade_label = this.listen_upgrade_label(status);
            if (upgrade_label) {
                html += '<div class="NB-media-player-listen-upgrade" role="button">' + _.escape(upgrade_label) + '</div>';
            }
        } else if (engine && engine.is_preview()) {
            kind = 'preview';
            var seconds = Math.round(engine.preview_seconds());
            html += '<div class="NB-media-player-listen-message">' + _.escape(interpolate(ngettext(
                'Previewing %(seconds)s second. Premium Archive unlocks full stories',
                'Previewing %(seconds)s seconds. Premium Archive unlocks full stories', seconds),
                { seconds: seconds }, true)) + '</div>';
            html += '<div class="NB-media-player-listen-countdown"></div>';
        }

        $banner.html(html)
            .attr('class', 'NB-media-player-listen-banner' + (kind ? ' NB-listen-banner-' + kind : ' NB-empty'));
        this.update_listen_countdown();
        if (!options.skip_resize && $banner.outerHeight() !== previous_height) {
            this.resize_player();
        }
    },

    update_listen_countdown: function () {
        var engine = this.listen_engine();
        var $countdown = this.$('.NB-media-player-listen-countdown');
        if (!engine || !$countdown.length) return;
        var remaining = engine.remaining_preview_seconds();
        if (remaining === null) return;
        $countdown.text(interpolate(gettext('%(time)s left'), {
            time: this.format_time(Math.ceil(remaining))
        }, true));
    },

    resize_player: function () {
        var self = this;
        _.defer(function () {
            if (self.$el.hasClass('NB-hidden')) return;
            self._resize_south_pane(self._calculate_player_height() + 37);
        });
    },

    // media_player_view.js: When Listen reads the extracted article because the feed only carries a
    // summary (text_source "original"), show that story in the Text view so follow-along can
    // highlight the full article. It's the temporary Text view of shift+enter, so the saved view
    // setting stays as it is, and it only happens once, when the story starts playing, so it never
    // fights a reader who switches back.
    listen_open_text_view: function (manifest) {
        var story_hash = this.current_media && this.current_media.story_hash;
        if (!story_hash || this.listen_text_view_story_hash === story_hash) return;
        this.listen_text_view_story_hash = story_hash;
        if (!manifest || manifest.text_source !== 'original') return;
        // media_player_view.js: Free accounts only get a premium-only notice in the Text view
        // (text_tab_view.js), so they stay in their view and the highlight matches what it can.
        if (!NEWSBLUR.Globals.is_premium) return;

        var reader = NEWSBLUR.reader;
        var story = reader && reader.active_story;
        if (!story || story.get('story_hash') !== story_hash || reader.story_view == 'text') return;

        var layout = NEWSBLUR.assets.view_setting(reader.active_feed, 'layout');
        if (_.contains(['list', 'grid', 'magazine'], layout)) {
            var title_view = story.story_title_view;
            if (!title_view || !title_view.$('.NB-story-detail').children().length) return;
            if (title_view.text_view && title_view.text_view.story === story) return;
            title_view.render_inline_story_detail(true);
        } else if (!reader.flags['temporary_story_view'] && NEWSBLUR.app.text_tab_view) {
            NEWSBLUR.app.text_tab_view.fetch_and_render(story, true);
        }
    },

    listen_jump_to_paragraph: function (paragraph_index) {
        var engine = this.listen_engine();
        if (!engine || !_.isNumber(paragraph_index) || isNaN(paragraph_index)) return;
        engine.seek_to_paragraph(paragraph_index);
        if (!this.is_playing) this.play();
        this.current_position = this.get_current_time();
        this.update_progress_display();
    },

    // media_player_view.js: After a voice or delivery change, start the story again from the
    // paragraph being read, with the new settings.
    listen_restart: function (options) {
        options = options || {};
        var engine = this.listen_engine();
        // media_player_view.js: A finished free preview has nothing left to replay; keep its prompt.
        if (!engine || engine.preview_finished) return;
        var was_playing = this.is_playing;
        var manifest = engine.manifest;
        var language = (manifest && manifest.language) || engine.language;
        // media_player_view.js: An engine that never loaded still knows where it was asked to start.
        var paragraph = manifest ? engine.current_paragraph() : engine.start_paragraph;
        var listen_options = {
            language: language,
            voice_id: options.voice_id || this.listen_selected_voice(language)
        };
        if (_.isNumber(paragraph)) {
            listen_options.start_paragraph = paragraph;
        } else {
            listen_options.start_time = engine.currentTime;
        }
        this.create_media_element(this.current_media, listen_options);
        this.render();
        if (was_playing) this.play();
    },

    on_listen_ended: function () {
        var finished = this.current_media;
        this.listen_mark_read(finished);

        // media_player_view.js: The first Listen story in Up Next plays next (play_media takes it
        // out of the queue as it starts). Podcasts and videos queued here wait for the player's
        // own Up Next, as before.
        var queued = this.auto_play_next && _.find(this.queue, function (item) {
            return item.media_type === 'listen';
        });
        if (queued) {
            this.listen_follow_into(finished, queued.story_hash);
            this.play_media(queued);
            return;
        }
        if (this.listen_pref_enabled('listen_auto_continue') && this.listen_play_next_story(finished)) {
            return;
        }

        this.is_playing = false;
        this.$('.NB-media-player-play-pause').html(this.SVG_PLAY);
        this.save_durable_state();
        this.update_listen_buttons();
    },

    listen_mark_read: function (item) {
        if (!item) return;
        var story = NEWSBLUR.assets.stories.get_by_story_hash(item.story_hash);
        if (story) {
            if (!story.get('read_status')) {
                NEWSBLUR.assets.stories.mark_read(story, { skip_delay: true });
            }
            return;
        }
        // media_player_view.js: The story list moved on since this story started playing.
        NEWSBLUR.assets.mark_story_hash_as_read(new NEWSBLUR.Models.Story({
            id: item.story_hash,
            story_hash: item.story_hash,
            story_feed_id: item.feed_id
        }));
    },

    // media_player_view.js: Auto-continue plays the next unread story in the current story list,
    // and opens it when the reader was following along with the story that just finished.
    listen_play_next_story: function (finished) {
        if (!finished) return false;
        var next = _.first(this.listen_next_stories(finished.story_hash, 1));
        if (!next) return false;
        this.listen_follow_into(finished, next.get('story_hash'));
        this.play_media(this.make_listen_item(next));
        return true;
    },

    // media_player_view.js: The stories after the one being read, in visible list order and never
    // the ones above it. Only unread stories count, except in Saved Stories and Read Stories,
    // where everything is read and the list order stands as is. Stories already in Up Next are
    // left out, since they play from there. The iOS and Android players follow the same order.
    listen_next_stories: function (story_hash, limit) {
        var stories = NEWSBLUR.assets.stories;
        if (!stories || !story_hash) return [];
        var visible = stories.visible();
        var current_story = stories.get_by_story_hash(story_hash);
        var anchor_story = current_story || stories.active_story;
        var anchor = anchor_story ? _.indexOf(visible, anchor_story) : -1;
        var queued = _.pluck(_.filter(this.queue, function (item) {
            return item.media_type === 'listen';
        }), 'story_hash');
        var ignore_read_status = this.listen_list_is_all_read();
        var candidates = _.filter(visible.slice(anchor + 1), function (story) {
            var hash = story.get('story_hash');
            if (hash === story_hash || _.contains(queued, hash)) return false;
            return ignore_read_status || !story.get('read_status');
        });
        return candidates.slice(0, limit);
    },

    // media_player_view.js: Saved Stories and Read Stories hold nothing but read stories, so the
    // unread filter would leave auto-continue nothing to play from them.
    listen_list_is_all_read: function () {
        var reader = NEWSBLUR.reader;
        if (!reader) return false;
        return !!(reader.flags && reader.flags['starred_view']) || reader.active_feed === 'read';
    },

    listen_upcoming_stories: function (limit) {
        if (!this.is_listen() || !this.listen_pref_enabled('listen_auto_continue')) return [];
        return this.listen_next_stories(this.current_media.story_hash, limit);
    },

    // media_player_view.js: What the Next story button and the system's next-track control play:
    // the first Listen item in Up Next, else the story auto-continue would pick from the list.
    listen_next_story_item: function () {
        if (!this.is_listen()) return null;
        var current_hash = this.current_media.story_hash;
        var queued = _.find(this.queue, function (item) {
            return item.media_type === 'listen' && item.story_hash !== current_hash;
        });
        if (queued) return queued;
        var next = _.first(this.listen_next_stories(current_hash, 1));
        return next ? this.make_listen_item(next) : null;
    },

    listen_play_next: function (e) {
        if (e) e.stopPropagation();
        var next = this.listen_next_story_item();
        if (!next) return false;
        this.listen_follow_into(this.current_media, next.story_hash);
        this.play_media(next);
        return true;
    },

    refresh_listen_upcoming: function () {
        if (!this.is_listen() || this.$el.hasClass('NB-hidden')) return;
        this.render_queue();
    },

    // media_player_view.js: When the reader was following along with the story that finished, the
    // next one opens in the reader too.
    listen_follow_into: function (finished, story_hash) {
        var stories = NEWSBLUR.assets.stories;
        if (!stories || !finished) return;
        var finished_story = stories.get_by_story_hash(finished.story_hash);
        var next_story = stories.get_by_story_hash(story_hash);
        if (finished_story && next_story && stories.active_story === finished_story) {
            next_story.set('selected', true);
        }
    },

    listen_source_title: function () {
        var reader = NEWSBLUR.reader;
        if (reader && reader.flags && reader.flags['starred_view']) return gettext('Saved Stories');
        if (reader && reader.active_feed === 'read') return gettext('Read Stories');
        if (reader && reader.flags && reader.flags.river_view && !reader.flags.social_view) {
            var folder = reader.active_folder;
            var folder_title = folder && folder.get && folder.get('folder_title');
            return folder_title || gettext('All Site Stories');
        }
        var feed = reader && NEWSBLUR.assets.get_feed(reader.active_feed);
        return (feed && feed.get('feed_title')) || gettext('this list');
    },

    play_upcoming_item: function (e) {
        if (e) e.stopPropagation();
        var story = NEWSBLUR.assets.stories.get_by_story_hash($(e.currentTarget).attr('data-story-hash'));
        if (story) this.listen_to_story(story);
    },

    // ===============
    // = Listen Queue =
    // ===============

    listen_queue_item_for: function (story_hash) {
        var media_url = '/listen/story/' + story_hash;
        return _.find(this.queue, function (item) {
            return item.story_hash === story_hash && item.media_url === media_url;
        });
    },

    // media_player_view.js: "queued", "can_queue" (something else is loaded, so the story can join
    // Up Next) or null, for the + beside a story's Listen button.
    listen_queue_state: function (story_hash) {
        if (!this.current_media || this.is_listening_to(story_hash)) return null;
        return this.listen_queue_item_for(story_hash) ? 'queued' : 'can_queue';
    },

    toggle_listen_queue: function (story) {
        if (!story) return;
        var item = this.make_listen_item(story);
        if (this.is_listening_to(item.story_hash)) return;
        if (!this.current_media) {
            this.listen_to_story(story);
            return;
        }
        if (this.listen_queue_item_for(item.story_hash)) {
            NEWSBLUR.assets.remove_from_media_queue(item.story_hash, item.media_url, _.bind(function (response) {
                this.queue = (response.playback_state && response.playback_state.queue) || [];
                this.render_queue();
                this.show_toast(gettext('Removed from Up Next'));
            }, this));
            return;
        }
        NEWSBLUR.assets.add_to_media_queue(item, _.bind(function (response) {
            this.queue = (response.playback_state && response.playback_state.queue) || [];
            this.showing_history = false;
            this.render_queue();
            var position = _.indexOf(this.queue, this.listen_queue_item_for(item.story_hash)) + 1;
            this.show_toast(interpolate(gettext('Added to Up Next · %(position)s'), {
                position: this.ordinal(position || this.queue.length)
            }, true));
        }, this));
    },

    // media_player_view.js: English ordinals ("2nd"); other languages show the number with a
    // translatable marker, since ordinal suffixes don't translate word by word.
    ordinal: function (number) {
        var language = (document.documentElement.lang || 'en').toLowerCase();
        if (language.indexOf('en') === 0 && window.Intl && Intl.PluralRules) {
            var rule = new Intl.PluralRules('en', { type: 'ordinal' }).select(number);
            return number + ({ one: 'st', two: 'nd', few: 'rd' }[rule] || 'th');
        }
        return interpolate(pgettext('position in the Up Next queue', '#%(position)s'), { position: number }, true);
    },

    show_toast: function (message) {
        var $toast = this.$('.NB-media-player-toast');
        if (!$toast.length) {
            $toast = $('<div class="NB-media-player-toast" role="status"></div>');
            this.$el.append($toast);
        }
        $toast.text(message).addClass('NB-visible');
        clearTimeout(this.toast_timer);
        this.toast_timer = setTimeout(function () {
            $toast.removeClass('NB-visible');
        }, 2400);
    },

    // media_player_view.js: Re-reads the shared player state when the window regains focus, so a
    // story queued from a phone shows up in Up Next here.
    bind_playback_state_refresh: function () {
        $(window).off('focus.media_player_queue').on('focus.media_player_queue', _.bind(this.refresh_playback_state, this));
    },

    refresh_playback_state: function () {
        var now = Date.now();
        if (this.refreshing_playback_state || now - (this.refreshed_playback_state_at || 0) < this.PLAYBACK_STATE_REFRESH_MS) return;
        this.refreshing_playback_state = true;
        this.refreshed_playback_state_at = now;
        NEWSBLUR.assets.fetch_playback_state(_.bind(function (response) {
            this.refreshing_playback_state = false;
            var state = response && response.playback_state;
            if (!state) return;
            this.queue = state.queue || [];
            this.history = state.history || [];
            if (this.current_media) this.render_queue();
        }, this), _.bind(function () {
            this.refreshing_playback_state = false;
        }, this));
    },

    update_listen_buttons: function () {
        var story_hash = this.is_listen() ? this.current_media.story_hash : null;
        var is_playing = !!(story_hash && this.is_playing);
        var self = this;
        $('.NB-feed-story-listen').each(function () {
            var $button = $(this);
            var hash = $button.attr('data-story-hash');
            var is_current = !!story_hash && hash === story_hash;
            var queue_state = self.listen_queue_state(hash);
            $button.toggleClass('NB-listen-current', is_current);
            $button.toggleClass('NB-listen-playing', is_current && is_playing);
            $button.toggleClass('NB-listen-can-queue', queue_state === 'can_queue');
            $button.toggleClass('NB-listen-queued', queue_state === 'queued');
            $button.find('.NB-sideoption-title').text(is_current && is_playing ? gettext('Pause') : gettext('Listen'));
            $button.find('.NB-sideoption-listen-queue').attr('title', queue_state === 'queued' ?
                gettext('Queued. Click to remove from Up Next') : gettext('Add to Up Next'));
        });
        if (NEWSBLUR.ListenFollowAlong) {
            NEWSBLUR.ListenFollowAlong.set_playing(is_playing);
        }
        this.update_listen_next_button();
    },

    // media_player_view.js: The Next story button dims when neither Up Next nor the list has
    // another story to read aloud.
    update_listen_next_button: function () {
        var $next = this.$('.NB-media-player-next');
        if (!$next.length) return;
        $next.toggleClass('NB-disabled', !this.listen_next_story_item());
    },

    open_listen_settings: function (e) {
        if (e) e.stopPropagation();
        if (!this.is_listen()) return;
        NEWSBLUR.ListenSettingsPopover.create({
            anchor: this.$('.NB-media-player-listen-voice-settings')
        });
    },

    open_listen_upgrade: function (e) {
        if (e) e.stopPropagation();
        NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: 'listen' });
    },

    retry_listen: function (e) {
        if (e) e.stopPropagation();
        var engine = this.listen_engine();
        if (!engine) return;
        this.listen_status = null;
        this.render_listen_banner();
        engine.retry();
        this.is_playing = true;
        this.$('.NB-media-player-play-pause').html(this.SVG_PAUSE);
        this.update_listen_buttons();
    },

    // ========================
    // = beforeunload handler =
    // ========================

    setup_beforeunload: function () {
        var self = this;
        $(window).off('beforeunload.media_player');
        $(window).on('beforeunload.media_player', function () {
            // media_player_view.js: The last stretch of listening goes out with sendBeacon.
            if (self.media_element && self.media_element.flush_progress) {
                self.media_element.flush_progress({ beacon: true });
            }
            if (self.current_media) {
                // Use sendBeacon for reliable delivery during page unload
                var data = new FormData();
                data.append('current_story_hash', self.current_media.story_hash);
                data.append('current_media_url', self.current_media.media_url);
                data.append('current_media_type', self.current_media.media_type);
                data.append('current_media_title', self.current_media.media_title);
                data.append('current_feed_id', self.current_media.feed_id);
                data.append('current_image_url', self.current_media.image_url || '');
                data.append('current_position', self.get_current_time());
                data.append('current_duration', self.get_duration());
                // media_player_view.js: Same rule as saved_playback_rate; the podcast speed is kept.
                data.append('current_playback_rate', self.current_media.media_type === 'listen' ?
                    self.media_playback_rate : self.playback_rate);
                data.append('current_volume', self.volume);
                data.append('is_playing', 'false');
                data.append('skip_back_seconds', self.skip_back_seconds);
                data.append('skip_forward_seconds', self.skip_forward_seconds);
                data.append('auto_play_next', self.auto_play_next);
                data.append('remember_position', self.remember_position);
                data.append('resume_on_load', self.resume_on_load);
                navigator.sendBeacon('/media_player/save_playback_state', data);
            }
        });
    }

}, {
    // Static methods

    extract_youtube_id: function (url) {
        if (!url) return null;
        var match = url.match(/(?:youtube\.com\/embed\/|youtube-nocookie\.com\/embed\/|youtube\.com\/v\/|youtu\.be\/|youtube\.com\/watch\?v=)([A-Za-z0-9_-]+)/);
        return match ? match[1] : null;
    }
});
