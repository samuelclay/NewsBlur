// media/js/newsblur/views/media_player_view.js
NEWSBLUR.Views.MediaPlayerView = Backbone.View.extend({

    el: '.NB-media-player',

    POSITION_SYNC_INTERVAL: 10000,
    MINI_PLAYER_HEIGHT: 56,
    EXPANDED_PLAYER_HEIGHT: 260,
    SPEED_OPTIONS: [0.5, 0.75, 1, 1.25, 1.5, 2, 3],

    SVG_PLAY: '<svg viewBox="0 0 24 24"><polygon points="5,3 19,12 5,21"/></svg>',
    SVG_PAUSE: '<svg viewBox="0 0 24 24"><rect x="5" y="3" width="4" height="18"/><rect x="15" y="3" width="4" height="18"/></svg>',
    SVG_SKIP_BACK: '<svg viewBox="0 0 24 24"><path d="M11.99 5V1l-5 5 5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6h-2c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg>',
    SVG_SKIP_FORWARD: '<svg viewBox="0 0 24 24"><path d="M12.01 5V1l5 5-5 5V7c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6h2c0 4.42-3.58 8-8 8s-8-3.58-8-8 3.58-8 8-8z"/></svg>',
    SVG_VOLUME: '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/></svg>',
    SVG_VOLUME_MUTE: '<svg viewBox="0 0 24 24"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>',
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
        'click .NB-media-player-expand': 'toggle_expand',
        'click .NB-media-player-close': 'close_player',
        'click .NB-media-player-speed': 'cycle_speed',
        'click .NB-media-player-title': 'scroll_to_story',
        'click .NB-media-player-volume-icon': 'toggle_mute',
        'input .NB-media-player-progress': 'on_seek',
        'input .NB-media-player-volume': 'on_volume_change',
        'click .NB-media-player-queue-item': 'play_queue_item',
        'click .NB-media-player-queue-remove': 'remove_queue_item',
        'click .NB-media-player-queue-clear': 'clear_queue',
        'mousedown .NB-queue-drag-handle': 'start_drag'
    },

    initialize: function () {
        this.is_expanded = false;
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
        this.current_position = 0;
        this.current_duration = 0;
    },

    // ================
    // = State Restore =
    // ================

    restore_state: function () {
        var state = NEWSBLUR.assets.playback_state;
        if (!state || !state.current_media_url) return;

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
        this.current_position = state.current_position || 0;
        this.current_duration = state.current_duration || 0;

        this.render();
        this.show_player();
        this.create_media_element(this.current_media);

        // Seek to saved position after media loads (don't auto-play due to browser policy)
        var self = this;
        _.delay(function () {
            self.seek_to(self.current_position);
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
        var media_type_label = this.current_media.media_type === 'youtube' ? 'video' : this.current_media.media_type;
        var is_video = this.current_media.media_type === 'video' || this.current_media.media_type === 'youtube';
        var has_artwork = !is_video && this.current_media.image_url;

        var html = '<div class="NB-media-player-mini">';

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
        html += '<div class="NB-media-player-type-badge">' + media_type_label + '</div>';
        html += '</div>';
        html += '<div class="NB-media-player-title" title="' + _.escape(this.current_media.media_title) + '">' + _.escape(this.current_media.media_title) + '</div>';
        html += '</div>';

        // Transport controls
        html += '<div class="NB-media-player-controls">';
        html += '<div class="NB-media-player-skip-back" title="Back 15 seconds">' + this.SVG_SKIP_BACK + '</div>';
        html += '<div class="NB-media-player-play-pause" title="Play/Pause">' + (this.is_playing ? this.SVG_PAUSE : this.SVG_PLAY) + '</div>';
        html += '<div class="NB-media-player-skip-forward" title="Forward 30 seconds">' + this.SVG_SKIP_FORWARD + '</div>';
        html += '</div>';

        // Progress
        html += '<div class="NB-media-player-progress-container">';
        html += '<input type="range" class="NB-media-player-progress" min="0" max="1000" value="0" />';
        html += '<div class="NB-media-player-time">';
        html += '<span class="NB-media-player-time-current">' + this.format_time(this.current_position) + '</span>';
        html += '<span class="NB-media-player-time-separator">/</span>';
        html += '<span class="NB-media-player-time-duration">' + this.format_time(this.current_duration) + '</span>';
        html += '</div>';
        html += '</div>';

        // Secondary controls
        html += '<div class="NB-media-player-secondary-controls">';
        html += '<div class="NB-media-player-speed" title="Playback speed">' + this.format_speed(this.playback_rate) + '</div>';
        html += '<div class="NB-media-player-volume-container">';
        html += '<div class="NB-media-player-volume-icon" title="Mute">' + (this.is_muted ? this.SVG_VOLUME_MUTE : this.SVG_VOLUME) + '</div>';
        html += '<input type="range" class="NB-media-player-volume" min="0" max="100" value="' + Math.round(this.volume * 100) + '" />';
        html += '</div>';
        html += '<div class="NB-media-player-expand" title="Show queue">' + this.SVG_EXPAND + '</div>';
        html += '<div class="NB-media-player-close" title="Close player">' + this.SVG_CLOSE + '</div>';
        html += '</div>';

        html += '</div>'; // end mini

        // Expanded queue area
        html += '<div class="NB-media-player-expanded-area ' + (this.is_expanded ? '' : 'NB-hidden') + '">';
        html += this.render_queue_html();
        html += '</div>';

        this.$el.html(html);
        this.update_progress_display();

        return this;
    },

    render_queue_html: function () {
        var html = '<div class="NB-media-player-queue-header">';
        html += '<span>Up Next</span>';
        html += '<span class="NB-media-player-queue-count">' + (this.queue.length ? this.queue.length + ' item' + (this.queue.length !== 1 ? 's' : '') : '') + '</span>';
        if (this.queue.length) {
            html += '<div class="NB-media-player-queue-clear" title="Clear queue">' + this.SVG_CLEAR + ' Clear</div>';
        }
        html += '</div>';
        html += '<ul class="NB-media-player-queue">';

        if (!this.queue.length) {
            html += '<li class="NB-media-player-queue-empty">Queue is empty</li>';
        } else {
            for (var i = 0; i < this.queue.length; i++) {
                var item = this.queue[i];
                var feed = NEWSBLUR.assets.get_feed(item.feed_id);
                var favicon_html = feed ? $.favicon_html(feed) : '';
                var type_label = item.media_type === 'youtube' ? 'video' : item.media_type;
                var added_label = item.added_at ? this.format_relative_date(item.added_at) : '';
                html += '<li class="NB-media-player-queue-item" data-index="' + i + '">';
                html += '<div class="NB-queue-drag-handle" title="Drag to reorder">' + this.SVG_DRAG_HANDLE + '</div>';
                html += '<div class="NB-queue-favicon">' + favicon_html + '</div>';
                html += '<div class="NB-queue-info">';
                html += '<div class="NB-queue-title">' + _.escape(item.media_title) + '</div>';
                if (added_label) {
                    html += '<div class="NB-queue-date">Added ' + added_label + '</div>';
                }
                html += '</div>';
                html += '<div class="NB-queue-type">' + type_label + '</div>';
                html += '<div class="NB-media-player-queue-remove" data-index="' + i + '" title="Remove">' + this.SVG_CLOSE + '</div>';
                html += '</li>';
            }
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
                media_items.push({
                    story_hash: story_hash,
                    media_url: src,
                    media_type: 'audio',
                    media_title: story_title,
                    feed_id: feed_id,
                    image_url: image_url
                });
            }
        });

        // Detect <video> elements
        $story_el.find('video').each(function () {
            var $video = $(this);
            var src = $video.find('source').attr('src') || $video.attr('src');
            if (src) {
                media_items.push({
                    story_hash: story_hash,
                    media_url: src,
                    media_type: 'video',
                    media_title: story_title,
                    feed_id: feed_id,
                    image_url: image_url
                });
            }
        });

        // Detect YouTube iframes
        $story_el.find('iframe[src*="youtube.com"], iframe[src*="youtu.be"]').each(function () {
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
        if (this.current_media &&
            this.current_media.story_hash === media_item.story_hash &&
            this.current_media.media_url === media_item.media_url) {
            this.toggle_play_pause();
            return;
        }

        this.current_media = media_item;
        this.current_position = 0;
        this.current_duration = 0;
        this.is_playing = false;

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
        var new_pos = Math.max(0, this.get_current_time() - 15);
        this.seek_to(new_pos);
    },

    skip_forward: function (e) {
        if (e) e.stopPropagation();
        var new_pos = Math.min(this.get_duration(), this.get_current_time() + 30);
        this.seek_to(new_pos);
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

        this.$('.NB-media-player-volume-icon').html(
            this.is_muted ? this.SVG_VOLUME_MUTE : this.SVG_VOLUME
        );
    },

    toggle_mute: function (e) {
        if (e) e.stopPropagation();
        this.is_muted = !this.is_muted;

        if (this.youtube_player && typeof this.youtube_player.setVolume === 'function') {
            this.youtube_player.setVolume(this.is_muted ? 0 : this.volume * 100);
        } else if (this.media_element) {
            this.media_element.volume = this.is_muted ? 0 : this.volume;
        }

        this.$('.NB-media-player-volume-icon').html(
            this.is_muted ? this.SVG_VOLUME_MUTE : this.SVG_VOLUME
        );
        this.$('.NB-media-player-volume').val(this.is_muted ? 0 : Math.round(this.volume * 100));
    },

    // ==============
    // = Queue Mgmt =
    // ==============

    add_to_queue: function (media_item, position) {
        // If nothing is playing, play immediately instead
        if (!this.current_media) {
            this.play_media(media_item);
            return;
        }

        var data = _.extend({}, media_item);
        if (position !== undefined) {
            data.position = position;
        }

        NEWSBLUR.assets.add_to_media_queue(data, _.bind(function (response) {
            if (response.playback_state) {
                this.queue = response.playback_state.queue || [];
                this.render_queue();
            }
        }, this));
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
        if (this.queue.length > 0) {
            var next_item = this.queue[0];
            NEWSBLUR.assets.remove_from_media_queue(next_item.story_hash, next_item.media_url, _.bind(function (response) {
                if (response.playback_state) {
                    this.queue = response.playback_state.queue || [];
                }
                this.play_media(next_item);
            }, this));
        } else {
            // Queue exhausted - stay on last item, paused
            this.is_playing = false;
            this.$('.NB-media-player-play-pause').html(this.SVG_PLAY);
            this.save_durable_state();
        }
    },

    render_queue: function () {
        this.$('.NB-media-player-expanded-area').html(this.render_queue_html());
    },

    clear_queue: function (e) {
        if (e) e.stopPropagation();
        NEWSBLUR.assets.clear_media_queue(_.bind(function (response) {
            if (response.playback_state) {
                this.queue = response.playback_state.queue || [];
            } else {
                this.queue = [];
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
            is_playing: this.is_playing
        });
    },

    // =====================
    // = Multi-tab Sync    =
    // =====================

    handle_media_update: function (data) {
        // Another tab is playing - pause this one
        if (data.is_playing && this.is_playing) {
            this.pause();
        }
        // Update position display from remote
        if (data.position != null) {
            this.current_position = data.position;
        }
        if (data.duration != null) {
            this.current_duration = data.duration;
        }
        this.update_progress_display();
    },

    // ====================
    // = Layout / Sizing  =
    // ====================

    show_player: function () {
        this.$el.removeClass('NB-hidden');
        this._resize_south_pane(this.MINI_PLAYER_HEIGHT + 37);
    },

    hide_player: function () {
        this.$el.addClass('NB-hidden');
        this._resize_south_pane(37);
    },

    toggle_expand: function (e) {
        if (e) e.stopPropagation();
        this.is_expanded = !this.is_expanded;
        this.$('.NB-media-player-expanded-area').toggleClass('NB-hidden', !this.is_expanded);
        this.$('.NB-media-player-expand').html(
            this.is_expanded ? this.SVG_COLLAPSE : this.SVG_EXPAND
        );

        var height = this.is_expanded ?
            this.EXPANDED_PLAYER_HEIGHT + 37 :
            this.MINI_PLAYER_HEIGHT + 37;
        this._resize_south_pane(height);
    },

    close_player: function (e) {
        if (e) e.stopPropagation();
        this.pause();
        this.destroy_media_element();
        this.stop_position_sync();
        this.stop_ui_updates();
        this.current_media = null;
        this.is_expanded = false;
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

        var story = NEWSBLUR.assets.stories.get(this.current_media.story_hash);
        if (story) {
            story.set('selected', true);
            NEWSBLUR.app.story_list.scroll_to_selected_story(story);
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
                navigator.sendBeacon('/reader/save_playback_state', data);
            }
        });
    }

}, {
    // Static methods

    extract_youtube_id: function (url) {
        if (!url) return null;
        var match = url.match(/(?:youtube\.com\/embed\/|youtube\.com\/v\/|youtu\.be\/|youtube\.com\/watch\?v=)([A-Za-z0-9_-]+)/);
        return match ? match[1] : null;
    }
});
