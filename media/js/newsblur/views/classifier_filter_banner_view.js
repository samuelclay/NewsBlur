// media/js/newsblur/views/classifier_filter_banner_view.js
//
// Sticky banner that appears above .NB-story-titles when the user enters
// "classifier filter view" (browsing every story matching a single
// classifier value). Modeled after feed_search_view.js:212's indexing
// banner and shown via NEWSBLUR.reader.open_classifier_filter() in
// reader.js. Reads the live flag from NEWSBLUR.reader.flags.classifier_filter.
//
// Shape of the filter object:
//   { type: 'tag'|'author'|'title'|'url'|'text',
//     value: '...', scope: 'feed'|'folder'|'global',
//     folder_name, origin: 'trainer'|'pill' }
//
// The inline classifier pill matches the trainer dialog's make_classifier
// output exactly — scope toggles, notification bell, thumbs up/down/super
// dislike icons — so training from the banner feels identical to training
// from the trainer modal. Training writes through NEWSBLUR.assets.save_classifier,
// the same endpoint the trainer uses.

NEWSBLUR.Views.ClassifierFilterBannerView = Backbone.View.extend({

    className: "NB-classifier-filter-banner",

    events: {
        "click .NB-classifier-filter-banner-close": "close",
        "click .NB-classifier-filter-banner-back-trainer": "back_to_trainer"
    },

    type_label_map: {
        'tag': 'tag',
        'author': 'author',
        'title': 'title phrase',
        'url': 'URL',
        'text': 'text phrase'
    },

    // SVGs live inline so the banner works without extra asset loading.
    type_icons: {
        'tag': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/></svg>',
        'author': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        'title': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7V4h16v3"/><path d="M9 20h6"/><path d="M12 4v16"/></svg>',
        'url': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>',
        'text': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 6.1H3"/><path d="M21 12.1H3"/><path d="M15.1 18H3"/></svg>'
    },

    scope_icon_data: [
        { key: 'feed',   title: 'This site only',      svg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>' },
        { key: 'folder', title: 'All sites in folder', svg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>' },
        { key: 'global', title: 'All sites',           svg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>' }
    ],

    initialize: function (options) {
        options = options || {};
        this.filter = options.filter || NEWSBLUR.reader.flags['classifier_filter'];
        this._classifier_notifications = {};

        // Load notifications once so the bell can render with current channels.
        // Re-render if they arrive after the initial paint.
        var self = this;
        if (NEWSBLUR.assets && NEWSBLUR.assets.load_classifier_notifications) {
            NEWSBLUR.assets.load_classifier_notifications(function (data) {
                self._classifier_notifications = (data && data.classifier_notifications) || {};
                if (self.$el && self.$el.is(':visible')) {
                    self.render();
                }
            });
        }
    },

    // Build the banner content from the current filter. Re-run whenever the
    // filter changes (scope flip, value change, inline training). Keeps
    // everything declarative so we don't have to track DOM state per-pill.
    render: function () {
        if (!this.filter) return this;

        var type = this.filter.type;
        var origin = this.filter.origin;

        var $icon = $.make('div', { className: 'NB-classifier-filter-banner-icon' });
        $icon.html(this.type_icons[type] || '');

        // Classifier pill — uses the same DOM as the trainer dialog's
        // make_classifier so it inherits all of the trainer's pill styles.
        var $pill_wrapper = this._make_trainer_style_pill();

        var $text = $.make('div', { className: 'NB-classifier-filter-banner-text' }, [
            $.make('span', { className: 'NB-classifier-filter-banner-title' },
                'Browsing stories with ' + (this.type_label_map[type] || type)),
            $pill_wrapper
        ]);

        var $content = $.make('div', { className: 'NB-classifier-filter-banner-content' }, [
            $text
        ]);

        var $actions = $.make('div', { className: 'NB-classifier-filter-banner-actions' });
        if (origin === 'trainer') {
            $actions.append($.make('span', {
                className: 'NB-classifier-filter-banner-back-trainer'
            }, 'Back to trainer'));
        }
        $actions.append($.make('span', {
            className: 'NB-classifier-filter-banner-close',
            'data-tooltip': 'Close'
        }, '\u2715'));

        this.$el.empty().addClass('NB-filter-' + type);
        // Strip previous per-type class on re-render.
        var self = this;
        _.each(['tag', 'author', 'title', 'url', 'text'], function (t) {
            if (t !== type) self.$el.removeClass('NB-filter-' + t);
        });
        this.$el.append($icon);
        this.$el.append($content);
        this.$el.append($actions);

        return this;
    },

    // Build a pill that matches the trainer dialog's .NB-classifier output
    // exactly. The `.NB-classifiers` wrapper is required for the trainer
    // stylesheet rules to apply (padding, icon positioning, hover/active
    // colors). See media/js/newsblur/reader/reader_classifier.js:make_classifier
    // for the reference implementation.
    _make_trainer_style_pill: function () {
        var type = this.filter.type;
        var value = this.filter.value;
        var scope = this.filter.scope || 'feed';
        var folder_name = this.filter.folder_name || '';
        var score = this._lookup_current_score();

        var display_type = type === 'url' ? 'URL' : Inflector.capitalize(type);

        // Scope toggles — identical to make_classifier's three-icon pattern.
        var $scope_toggles = $.make('span', { className: 'NB-classifier-scope-toggles' });
        _.each(this.scope_icon_data, function (icon) {
            var $toggle = $.make('span', {
                className: 'NB-scope-toggle NB-scope-toggle-' + icon.key +
                    (icon.key === scope ? ' NB-active' : ''),
                'data-tooltip': icon.title
            });
            $toggle.html(icon.svg);
            $toggle.data('scope', icon.key);
            $scope_toggles.append($toggle);
        });
        var $scope_badge = $.make('span', { className: 'NB-classifier-scope-badge' }, [
            $scope_toggles
        ]);

        var $type_label = $.make('span', { className: 'NB-classifier-type-badge' }, [
            $.make('span', { className: 'NB-classifier-type-label' }, display_type)
        ]);

        var $bell = this._make_notification_bell(type, value, scope, folder_name, score);

        var $classifier = $.make('span', {
            className: 'NB-classifier NB-classifier-' + type
        }, [
            $.make('input', {
                type: 'checkbox',
                className: 'NB-classifier-input-like',
                name: 'like_' + type,
                value: value
            }),
            $.make('input', {
                type: 'checkbox',
                className: 'NB-classifier-input-dislike',
                name: 'dislike_' + type,
                value: value
            }),
            $.make('input', {
                type: 'checkbox',
                className: 'NB-classifier-input-super-dislike',
                name: 'super_dislike_' + type,
                value: value
            }),
            $.make('div', { className: 'NB-classifier-icon-like' }),
            $.make('div', { className: 'NB-classifier-icon-dislike' }, [
                $.make('div', { className: 'NB-classifier-icon-dislike-inner' })
            ]),
            $.make('div', { className: 'NB-classifier-icon-super-dislike' }),
            $.make('label', [
                $scope_badge,
                $bell,
                $type_label,
                $.make('span', value)
            ])
        ]);

        $classifier.data('scope', scope);
        $classifier.data('folder-name', folder_name);

        if (score > 0) {
            $classifier.addClass('NB-classifier-like');
            $('.NB-classifier-input-like', $classifier).prop('checked', true);
        } else if (score <= -2) {
            $classifier.addClass('NB-classifier-super-dislike');
            $('.NB-classifier-input-super-dislike', $classifier).prop('checked', true);
        } else if (score < 0) {
            $classifier.addClass('NB-classifier-dislike');
            $('.NB-classifier-input-dislike', $classifier).prop('checked', true);
        }

        // Hover state helpers — same behavior as the trainer pill so the
        // like/dislike icons dim/brighten consistently.
        $classifier.on('mouseenter', function (e) {
            $(e.currentTarget).addClass('NB-classifier-hover-like');
        }).on('mouseleave', function (e) {
            $(e.currentTarget).removeClass('NB-classifier-hover-like');
        });
        $('.NB-classifier-icon-dislike', $classifier).on('mouseenter', function () {
            $classifier.addClass('NB-classifier-hover-dislike');
        }).on('mouseleave', function () {
            $classifier.removeClass('NB-classifier-hover-dislike');
        });
        $('.NB-classifier-icon-super-dislike', $classifier).on('mouseenter', function () {
            $classifier.addClass('NB-classifier-hover-super-dislike');
        }).on('mouseleave', function () {
            $classifier.removeClass('NB-classifier-hover-super-dislike');
        });

        // Click handlers — match reader_classifier.js' delegated targetIs
        // chain at line 3724. Super-dislike is checked first so clicks on
        // its icon don't bubble up to the dislike or like handlers.
        var self = this;
        $('.NB-classifier-icon-super-dislike', $classifier).on('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            self._apply_training('super_dislike');
        });
        $('.NB-classifier-icon-dislike', $classifier).on('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            self._apply_training('dislike');
        });
        $classifier.on('click', function (e) {
            // Skip clicks on scope toggles, bell, or label children we don't
            // want to treat as "like".
            if ($(e.target).closest('.NB-scope-toggle, .NB-classifier-notification-bell, .NB-classifier-notif-indicators').length) {
                return;
            }
            e.preventDefault();
            self._apply_training('like');
        });

        // Scope toggle clicks — re-issue the filter at the new scope.
        $('.NB-scope-toggle', $classifier).on('click', function (e) {
            e.stopPropagation();
            e.preventDefault();
            self._change_scope($(this).data('scope'));
        });
        // Instant tooltips for scope toggles (matches trainer dialog).
        $('.NB-scope-toggle', $classifier).on('mouseenter', function () {
            var $this = $(this);
            var text = $this.attr('data-tooltip');
            if (!text) return;
            var $tip = $('<div class="NB-scope-tooltip">' + text + '</div>');
            $('body').append($tip);
            var rect = this.getBoundingClientRect();
            $tip.css({
                top: rect.top - $tip.outerHeight() - 6,
                left: rect.left + rect.width / 2 - $tip.outerWidth() / 2
            });
            $this.data('$tooltip', $tip);
        }).on('mouseleave', function () {
            var $tip = $(this).data('$tooltip');
            if ($tip) { $tip.remove(); $(this).removeData('$tooltip'); }
        });

        // The .NB-classifier CSS expects a .NB-classifiers ancestor for all
        // its rules (float, padding, colors). We still need to neutralize
        // the float so the pill sits inline inside the flex-row banner text.
        return $.make('span', { className: 'NB-classifiers NB-classifier-filter-banner-classifier-host' }, [
            $classifier
        ]);
    },

    // Build the notification bell. Reuses the ClassifierNotificationPopover
    // view on click so the banner gets the same per-channel controls as the
    // trainer. Active channels render as small indicators on the bell.
    _make_notification_bell: function (type, value, scope, folder_name, score) {
        var feed_id = NEWSBLUR.reader.active_feed;
        var is_regex = false;
        var regex_key = is_regex ? 'regex' : '';
        var notif_key = type + ':' + value + ':' + regex_key + ':' + scope + ':' +
            (scope === 'feed' ? feed_id : 0) + ':' + (folder_name || '');
        var notif = this._classifier_notifications && this._classifier_notifications[notif_key];
        var active_types = (notif && notif.notification_types) || [];
        var has_channels = active_types.length > 0;

        var bell_svg = NEWSBLUR.Views.ClassifierNotificationPopover &&
            NEWSBLUR.Views.ClassifierNotificationPopover.BELL_SVG;

        var $bell_icon = $.make('span', { className: 'NB-bell-icon' });
        if (bell_svg) $bell_icon.html(bell_svg);

        var $indicators = $.make('span', { className: 'NB-classifier-notif-indicators' });
        _.each(active_types, function (t) {
            var icon_svg = NEWSBLUR.Views.ClassifierNotificationPopover &&
                NEWSBLUR.Views.ClassifierNotificationPopover.CHANNEL_ICONS[t];
            if (icon_svg) {
                var $i = $.make('span', { className: 'NB-channel-indicator NB-channel-' + t });
                $i.html(icon_svg);
                $indicators.append($i);
            }
        });

        var $bell = $.make('span', {
            className: 'NB-classifier-notification-bell' + (has_channels ? ' NB-active' : '')
        }, [
            $bell_icon,
            $indicators
        ]);

        $bell.data('classifier-type', type);
        $bell.data('classifier-value', value);
        $bell.data('is-regex', is_regex);
        $bell.data('scope', scope);
        $bell.data('folder-name', folder_name);
        $bell.data('score', score);
        $bell.data('notification-types', active_types.slice());

        var self = this;
        $bell.on('click', function (e) {
            e.preventDefault();
            e.stopPropagation();
            self._show_notification_popover($(this));
        });

        return $bell;
    },

    // Open the shared ClassifierNotificationPopover near the bell. When the
    // user makes a change, persist via save_classifier (matches how the
    // trainer saves notification changes for scoped classifiers).
    _show_notification_popover: function ($bell) {
        this._close_notification_popover();

        var classifier_type = $bell.data('classifier-type');
        var classifier_value = $bell.data('classifier-value');
        var scope = $bell.data('scope');
        var folder_name = $bell.data('folder-name') || '';
        var feed_id = NEWSBLUR.reader.active_feed;
        var active_types = $bell.data('notification-types') || [];

        if (!NEWSBLUR.Views.ClassifierNotificationPopover) return;

        var self = this;
        var popover = new NEWSBLUR.Views.ClassifierNotificationPopover({
            classifier_type: classifier_type,
            classifier_value: classifier_value,
            is_regex: false,
            scope: scope,
            feed_id: scope === 'feed' ? feed_id : 0,
            folder_name: folder_name,
            is_email: _.contains(active_types, 'email'),
            is_web: _.contains(active_types, 'web'),
            is_ios: _.contains(active_types, 'ios'),
            is_android: _.contains(active_types, 'android'),
            $bell: $bell,
            trainer: null
        });

        var $popover = popover.render().$el;
        $('body').append($popover);

        var rect = $bell[0].getBoundingClientRect();
        var popover_height = $popover.outerHeight();
        $popover.css({
            top: rect.top - popover_height - 6,
            left: Math.max(4, rect.left - 20)
        });

        this._active_popover = $popover;

        $popover.on('mouseleave', function () {
            setTimeout(function () {
                // Refresh the bell from assets cache after the popover closes
                // so channel indicators reflect any saved changes. The popover
                // writes via save_classifier directly, so we re-load the
                // notifications from the server on close.
                if (NEWSBLUR.assets && NEWSBLUR.assets.load_classifier_notifications) {
                    NEWSBLUR.assets.load_classifier_notifications(function (data) {
                        self._classifier_notifications = (data && data.classifier_notifications) || {};
                        self.render();
                    });
                }
                self._close_notification_popover();
            }, 150);
        });
    },

    _close_notification_popover: function () {
        if (this._active_popover) {
            this._active_popover.remove();
            this._active_popover = null;
        }
    },

    // Look up the current score for this classifier in the in-memory
    // feed classifiers cache. Only checks feed-scoped classifiers on the
    // active feed; folder/global scopes start as "not trained yet" in the
    // pill and update to their trained state after the user clicks.
    _lookup_current_score: function () {
        var feed_id = NEWSBLUR.reader.active_feed;
        if (!feed_id || !_.isFinite(feed_id)) return 0;
        var classifiers = NEWSBLUR.assets.classifiers[feed_id];
        if (!classifiers) return 0;
        var type = this.filter.type;
        var bucket = classifiers[type + 's'] || classifiers[type];
        if (!bucket) return 0;
        var score = bucket[this.filter.value];
        return _.isFinite(score) ? score : 0;
    },

    show_banner: function () {
        if (!this.filter) return;
        this.render();
        var $titles = $('#story_titles').find('.NB-story-titles');
        if (!$titles.length) $titles = $('#story_titles');
        // Drop any stale instance first so we never get two banners stacked.
        $('.NB-classifier-filter-banner').remove();
        this.$el.css({ 'opacity': 0 });
        $titles.before(this.$el);
        this.$el.animate({ 'opacity': 1 }, { 'duration': 300 });
    },

    hide_banner: function () {
        this._close_notification_popover();
        var $el = this.$el;
        $el.animate({ 'opacity': 0 }, {
            'duration': 200,
            'complete': function () { $el.remove(); }
        });
    },

    update: function (filter) {
        this.filter = filter;
        this.render();
        // Re-attach to the DOM if reset_feed animated us out but the
        // surrounding code kept the view instance around. Defensive — the
        // reader now clears the banner_view reference on navigation, but
        // keeping this check means a caller can still update() after a
        // hide_banner without the banner silently going missing.
        if (!this.$el.closest(document.documentElement).length) {
            this.show_banner();
        }
    },

    close: function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        NEWSBLUR.reader.close_classifier_filter();
    },

    back_to_trainer: function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        // Close the banner first so the story list reflow happens before the
        // trainer modal mounts. open_trainer_modal reads active_feed itself.
        NEWSBLUR.reader.close_classifier_filter();
        _.defer(function () {
            NEWSBLUR.reader.open_trainer_modal();
        });
    },

    // Called from scope toggle click — re-issues the filter with the new
    // scope. For non-archive users the toggle is still rendered so the
    // trainer-style pill looks consistent, but clicks fall through to a
    // no-op + denied animation.
    _change_scope: function (new_scope) {
        if (!new_scope || new_scope === this.filter.scope) return;
        if (new_scope !== 'feed' && !NEWSBLUR.Globals.is_archive) {
            // Shake the scope badge to match the trainer's "denied" feedback.
            var $badge = this.$el.find('.NB-classifier-scope-badge');
            $badge.removeClass('NB-shake');
            if ($badge.length) $badge[0].offsetWidth;
            $badge.addClass('NB-shake');
            setTimeout(function () { $badge.removeClass('NB-shake'); }, 500);
            return;
        }
        NEWSBLUR.reader.open_classifier_filter(this.filter.type, this.filter.value, {
            scope: new_scope,
            folder_name: this.filter.folder_name,
            origin: this.filter.origin
        });
    },

    // Apply a training opinion (like/dislike/super_dislike), toggling off
    // if the opinion is already active. Writes through the same
    // save_classifier endpoint the trainer dialog uses. Keeps the banner
    // visible after save and re-renders so the active state flips.
    _apply_training: function (opinion) {
        var feed_id = NEWSBLUR.reader.active_feed;
        if (!feed_id || !_.isFinite(feed_id)) return;

        var type = this.filter.type;
        var value = this.filter.value;
        var current_score = this._lookup_current_score();

        var opinion_to_score = { like: 1, dislike: -1, super_dislike: -2 };
        var target_score = opinion_to_score[opinion];
        if (target_score === undefined) return;

        var save_data = { feed_id: feed_id };
        if (this.filter.scope && this.filter.scope !== 'feed') {
            save_data.scope = this.filter.scope;
            save_data.folder_name = this.filter.folder_name || '';
        }

        var new_score;
        if (target_score === current_score) {
            // Toggle off — untrain back to neutral.
            if (current_score > 0) {
                save_data['remove_like_' + type] = value;
            } else {
                save_data['remove_dislike_' + type] = value;
            }
            new_score = 0;
        } else {
            if (current_score > 0 && target_score < 0) {
                save_data['remove_like_' + type] = value;
            } else if (current_score < 0 && target_score > 0) {
                save_data['remove_dislike_' + type] = value;
            }
            if (target_score === 1) save_data['like_' + type] = value;
            if (target_score === -1) save_data['dislike_' + type] = value;
            if (target_score === -2) save_data['super_dislike_' + type] = value;
            new_score = target_score;
        }

        // Optimistically update the in-memory classifier cache so the
        // subsequent recalculate_story_scores call picks up the new score
        // without waiting for a full feed refetch.
        var cache = NEWSBLUR.assets.classifiers[feed_id];
        if (cache) {
            var bucket_key = type + 's';
            cache[bucket_key] = cache[bucket_key] || {};
            if (new_score === 0) {
                delete cache[bucket_key][value];
            } else {
                cache[bucket_key][value] = new_score;
            }
        }

        // Immediately recompute visible story intelligence so every matching
        // row flips to its new trained state without waiting on the server
        // round-trip. This mirrors what the trainer modal does on save
        // (reader_classifier.js: recalculate_story_scores + render:intelligence).
        this._refresh_story_scores(feed_id);

        // Re-render the banner first so the pill's active state flips
        // immediately — the save happens in the background.
        this.render();

        NEWSBLUR.assets.save_classifier(save_data, function () {
            // On server ack, refresh again in case the server applied
            // anything different (scope promotion, etc.).
            NEWSBLUR.assets.stories.trigger('render:intelligence');
            // Recompute the feed's unread counts — training a classifier
            // changes how many stories land in positive/neutral/negative
            // buckets. Matches what story_detail_view.js:save_classifier
            // does after an inline tag/author train.
            if (NEWSBLUR.reader.feed_unread_count) {
                NEWSBLUR.reader.feed_unread_count(feed_id);
            }
        });
    },

    _refresh_story_scores: function (feed_id) {
        if (NEWSBLUR.assets.recalculate_story_scores) {
            NEWSBLUR.assets.recalculate_story_scores(feed_id);
        }
        if (NEWSBLUR.assets.stories) {
            NEWSBLUR.assets.stories.trigger('render:intelligence');
        }
    }

});
