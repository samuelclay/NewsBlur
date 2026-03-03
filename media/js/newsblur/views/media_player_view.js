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

    events: {
        'click .NB-media-player-play-pause': 'toggle_play_pause',
        'click .NB-media-player-skip-back': 'skip_back',
        'click .NB-media-player-skip-forward': 'skip_forward',
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
        'click .NB-media-player-history-remove': 'remove_history_item'
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
    },

    // ================
    // = State Restore =
    // ================

    restore_state: function () {
        this.state_restored = true;

        var state = NEWSBLUR.assets.playback_state;
        if (!state || !state.current_media_url) return;

        // Always restore settings from state, even if we don't show the player
        this.skip_back_seconds = state.skip_back_seconds || 15;
        this.skip_forward_seconds = state.skip_forward_seconds || 30;
        if (state.auto_play_next !== undefined) this.auto_play_next = state.auto_play_next;
        if (state.remember_position !== undefined) this.remember_position = state.remember_position;
        if (state.resume_on_load !== undefined) this.resume_on_load = state.resume_on_load;

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
        this.volume = state.current_volume || 1.0;
        this.queue = state.queue || [];
        this.history = state.history || [];
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
        html += '</div>';

        // Settings + close on info row
        html += '<div class="NB-media-player-settings" title="Player settings">' + this.SVG_SETTINGS + '</div>';
        html += '<div class="NB-media-player-close" title="Close player">' + this.SVG_CLOSE + '</div>';

        html += '</div>'; // end row-info

        // Row 2: Full-width scrubber
        html += '<div class="NB-media-player-row-scrubber">';
        html += '<input type="range" class="NB-media-player-progress" min="0" max="1000" value="0" />';
        html += '</div>';

        // Row 3: Controls + centered time + speed + volume
        html += '<div class="NB-media-player-row-controls">';
        html += '<div class="NB-media-player-controls">';
        html += '<div class="NB-media-player-skip-back" title="Back ' + this.skip_back_seconds + ' seconds">' + this.SVG_SKIP_BACK + '</div>';
        html += '<div class="NB-media-player-play-pause" title="Play/Pause">' + (this.is_playing ? this.SVG_PAUSE : this.SVG_PLAY) + '</div>';
        html += '<div class="NB-media-player-skip-forward" title="Forward ' + this.skip_forward_seconds + ' seconds">' + this.SVG_SKIP_FORWARD + '</div>';
        html += '</div>';
        html += '<div class="NB-media-player-time">';
        html += '<span class="NB-media-player-time-current">' + this.format_time(this.current_position) + '</span>';
        html += '<span class="NB-media-player-time-separator">/</span>';
        html += '<span class="NB-media-player-time-duration">' + this.format_time(this.current_duration) + '</span>';
        html += '</div>';
        html += '<div class="NB-media-player-right-controls">';
        html += '<div class="NB-media-player-speed" title="Playback speed">' + this.format_speed(this.playback_rate) + '</div>';
        html += '<div class="NB-media-player-volume-container">';
        html += '<div class="NB-media-player-volume-icon" title="Mute">' + this.get_volume_svg() + '</div>';
        html += '<div class="NB-media-player-volume-popover">';
        html += '<input type="range" class="NB-media-player-volume" min="0" max="100" value="' + Math.round(this.volume * 100) + '" />';
        html += '</div>';
        html += '</div>';
        html += '</div>';
        html += '</div>'; // end row-controls

        html += '</div>'; // end mini

        // Queue area (always visible)
        html += '<div class="NB-media-player-queue-area">';
        html += this.render_queue_html();
        html += '</div>';

        this.$el.html(html);
        this.update_progress_display();

        return this;
    },

    render_queue_html: function () {
        if (!this.queue.length && !this.history.length) return '';

        var html = '<div class="NB-media-player-queue-header">';

        // Segmented control tabs
        html += '<ul class="segmented-control">';
        html += '<li class="NB-media-player-tab-queue' + (!this.showing_history ? ' NB-active' : '') + '">';
        html += 'Up Next';
        if (this.queue.length > 0) {
            html += '<span class="NB-media-player-queue-count">' + this.queue.length + '</span>';
        }
        html += '</li>';
        html += '<li class="NB-media-player-tab-history' + (this.showing_history ? ' NB-active' : '') + '">';
        html += 'History';
        if (this.history.length > 0) {
            html += '<span class="NB-media-player-history-count">' + this.history.length + '</span>';
        }
        html += '</li>';
        html += '</ul>';

        // Clear button (clears whichever tab is active)
        var active_list = this.showing_history ? this.history : this.queue;
        if (active_list.length > 0) {
            html += '<div class="NB-media-player-queue-clear" title="Clear">' + this.SVG_CLEAR + ' Clear</div>';
        }

        html += '</div>'; // end header

        // Render active list
        if (this.showing_history) {
            html += this.render_history_list_html();
        } else {
            html += this.render_queue_list_html();
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
            var type_label = item.media_type === 'youtube' ? 'video' : item.media_type;
            var added_label = item.added_at ? this.format_relative_date(item.added_at) : '';
            var duration_label = item.duration ? this.format_time(item.duration) : '';
            html += '<li class="NB-media-player-queue-item" data-index="' + i + '">';
            html += '<div class="NB-queue-drag-handle" title="Drag to reorder">' + this.SVG_DRAG_HANDLE + '</div>';
            html += '<div class="NB-queue-favicon">' + favicon_html + '</div>';
            html += '<div class="NB-queue-info">';
            html += '<div class="NB-queue-title">' + _.escape(item.media_title) + '</div>';
            if (added_label || duration_label) {
                html += '<div class="NB-queue-date">';
                if (added_label) html += 'Added ' + added_label;
                if (added_label && duration_label) html += ' &middot; ';
                if (duration_label) html += duration_label;
                html += '</div>';
            }
            html += '</div>';
            html += '<div class="NB-queue-type">' + type_label + '</div>';
            html += '<div class="NB-media-player-queue-remove" data-index="' + i + '" title="Remove">' + this.SVG_CLOSE + '</div>';
            html += '</li>';
        }
        html += '</ul>';
        return html;
    },

    render_history_list_html: function () {
        if (!this.history.length) return '';

        var html = '<ul class="NB-media-player-queue NB-media-player-history-list">';
        for (var i = 0; i < this.history.length; i++) {
            var item = this.history[i];
            var feed = NEWSBLUR.assets.get_feed(item.feed_id);
            var favicon_html = feed ? $.favicon_html(feed) : '';
            var type_label = item.media_type === 'youtube' ? 'video' : item.media_type;
            var position_label = this.format_time(item.position || 0);
            var duration_label = this.format_time(item.duration || 0);
            html += '<li class="NB-media-player-history-item" data-index="' + i + '">';
            html += '<div class="NB-queue-favicon">' + favicon_html + '</div>';
            html += '<div class="NB-queue-info">';
            html += '<div class="NB-queue-title">' + _.escape(item.media_title) + '</div>';
            html += '<div class="NB-queue-date">' + position_label + ' / ' + duration_label + '</div>';
            html += '</div>';
            html += '<div class="NB-queue-type">' + type_label + '</div>';
            html += '<div class="NB-media-player-history-remove" data-index="' + i + '" title="Remove">' + this.SVG_CLOSE + '</div>';
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

    play_media: function (media_item) {
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
        this.current_position = 0;
        this.current_duration = 0;
        this.is_playing = false;

        // Render first so the video container exists in the DOM,
        // then create element and play (still within user gesture context)
        this.render();
        this.show_player();

        this.create_media_element(media_item);
        this.play();

        // Save durable state
        this.save_durable_state();
    },

    create_media_element: function (media_item) {
        this.destroy_media_element();

        if (media_item.media_type === 'audio') {
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
        if (this.media_element) {
            try {
                this.media_element.pause();
            } catch (e) { }
            this.media_element = null;
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
        });

        el.addEventListener('pause', function () {
            self.is_playing = false;
            self.$('.NB-media-player-play-pause').html(self.SVG_PLAY);
            self.stop_ui_updates();
            self.stop_position_sync();
            self.save_durable_state();
        });

        el.addEventListener('ended', function () {
            self.is_playing = false;
            self.$('.NB-media-player-play-pause').html(self.SVG_PLAY);
            self.stop_ui_updates();
            self.stop_position_sync();
            self.play_next();
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
    },

    pause: function () {
        if (this.youtube_player && typeof this.youtube_player.pauseVideo === 'function') {
            this.youtube_player.pauseVideo();
        } else if (this.media_element) {
            this.media_element.pause();
        }
        this.is_playing = false;
        this.$('.NB-media-player-play-pause').html(this.SVG_PLAY);
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

    update_skip_labels: function () {
        this.$('.NB-media-player-skip-back').attr('title', 'Back ' + this.skip_back_seconds + ' seconds');
        this.$('.NB-media-player-skip-forward').attr('title', 'Forward ' + this.skip_forward_seconds + ' seconds');
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
        var current_index = this.SPEED_OPTIONS.indexOf(this.playback_rate);
        var next_index = (current_index + 1) % this.SPEED_OPTIONS.length;
        this.playback_rate = this.SPEED_OPTIONS[next_index];

        if (this.youtube_player && typeof this.youtube_player.setPlaybackRate === 'function') {
            this.youtube_player.setPlaybackRate(this.playback_rate);
        } else if (this.media_element) {
            this.media_element.playbackRate = this.playback_rate;
        }

        this.$('.NB-media-player-speed').text(this.format_speed(this.playback_rate));
        this.save_durable_state();
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

        var needs_probe = !data.duration;

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
            if (item.duration) return;
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
        this.$('.NB-media-player-queue-area').html(this.render_queue_html());
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
            current_playback_rate: this.playback_rate,
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

    close_player: function (e) {
        if (e) e.stopPropagation();
        this.pause();
        this.destroy_media_element();
        this.stop_position_sync();
        this.stop_ui_updates();
        this.current_media = null;
        this.hide_player();

        NEWSBLUR.assets.clear_playback_state();
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

    format_speed: function (rate) {
        return rate + 'x';
    },

    get_volume_svg: function () {
        if (this.is_muted || this.volume === 0) return this.SVG_VOLUME_MUTE;
        if (this.volume < 0.34) return this.SVG_VOLUME_LOW;
        if (this.volume < 0.67) return this.SVG_VOLUME_MED;
        return this.SVG_VOLUME_HIGH;
    },

    format_relative_date: function (iso_string) {
        if (!iso_string) return '';
        var date = new Date(iso_string);
        var now = new Date();
        var diff_ms = now - date;
        var diff_mins = Math.floor(diff_ms / 60000);
        var diff_hours = Math.floor(diff_ms / 3600000);
        var diff_days = Math.floor(diff_ms / 86400000);

        if (diff_mins < 1) return 'just now';
        if (diff_mins < 60) return diff_mins + 'm ago';
        if (diff_hours < 24) return diff_hours + 'h ago';
        if (diff_days < 7) return diff_days + 'd ago';
        return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
    },

    // ========================
    // = beforeunload handler =
    // ========================

    setup_beforeunload: function () {
        var self = this;
        $(window).off('beforeunload.media_player');
        $(window).on('beforeunload.media_player', function () {
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
                data.append('current_playback_rate', self.playback_rate);
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
