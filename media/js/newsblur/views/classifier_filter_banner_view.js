// Sticky banner that appears above .NB-story-titles when the user enters
// the classifier filter view. The inline pill mirrors the trainer's
// .NB-classifier DOM exactly so training from the banner feels identical
// to training from the trainer modal.

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

    type_icons: {
        'tag': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/></svg>',
        'author': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
        'title': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7V4h16v3"/><path d="M9 20h6"/><path d="M12 4v16"/></svg>',
        'url': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>',
        'text': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 6.1H3"/><path d="M21 12.1H3"/><path d="M15.1 18H3"/></svg>'
    },

    initialize: function (options) {
        options = options || {};
        this.filter = options.filter || NEWSBLUR.reader.flags['classifier_filter'];
        this._classifier_notifications = {};

        // Kick off a notifications load so the bell can render with current
        // channels. Re-render if the response lands after the initial paint.
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

    render: function () {
        if (!this.filter) return this;

        var type = this.filter.type;
        var origin = this.filter.origin;

        var $icon = $.make('div', { className: 'NB-classifier-filter-banner-icon' });
        $icon.html(this.type_icons[type] || '');

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
        var self = this;
        _.each(NEWSBLUR.ClassifierConstants.FILTER_TYPES, function (t) {
            if (t !== type) self.$el.removeClass('NB-filter-' + t);
        });
        this.$el.append($icon);
        this.$el.append($content);
        this.$el.append($actions);

        return this;
    },

    // Build a pill that matches the trainer's .NB-classifier DOM so it
    // inherits all the trainer stylesheet rules (padding, icon positioning,
    // hover/active colors). The `.NB-classifiers` wrapper at the bottom is
    // mandatory — those rules are all scoped under it.
    _make_trainer_style_pill: function () {
        var type = this.filter.type;
        var value = this.filter.value;
        var scope = this.filter.scope || 'feed';
        var folder_name = this.filter.folder_name || '';
        var score = this._lookup_current_score();

        var display_type = type === 'url' ? 'URL' : Inflector.capitalize(type);

        var $scope_toggles = $.make('span', { className: 'NB-classifier-scope-toggles' });
        _.each(NEWSBLUR.ClassifierConstants.SCOPE_ICON_DATA, function (icon) {
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

        // Super-dislike is bound first so its click doesn't bubble up to
        // the dislike or whole-pill handlers.
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

        // The .NB-classifier stylesheet rules are scoped under .NB-classifiers;
        // the host wrapper here gets the trainer styles while the -host class
        // in reader.css neutralizes the trainer's float so the pill sits
        // inline inside the banner's flex row.
        return $.make('span', { className: 'NB-classifiers NB-classifier-filter-banner-classifier-host' }, [
            $classifier
        ]);
    },

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

    // Only checks feed-scoped classifiers on the active feed; folder/global
    // scopes start at neutral in the pill and flip to their trained state
    // after the user clicks.
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
        // Drop any stale DOM element first so we never get two stacked.
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
        // Re-attach if a prior hide_banner animated the element out of the
        // DOM but the caller is reusing the view instance.
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

    // For non-archive users scope toggles are still rendered, but clicking
    // a non-feed scope shakes the badge instead of actually switching.
    _change_scope: function (new_scope) {
        if (!new_scope || new_scope === this.filter.scope) return;
        if (new_scope !== 'feed' && !NEWSBLUR.Globals.is_archive) {
            var $badge = this.$el.find('.NB-classifier-scope-badge');
            var $toggle = this.$el.find('.NB-scope-toggle-' + new_scope);
            $badge.removeClass('NB-shake');
            if ($badge.length) $badge[0].offsetWidth;
            $badge.addClass('NB-shake');
            setTimeout(function () { $badge.removeClass('NB-shake'); }, 500);

            $toggle.addClass('NB-scope-toggle-denied');
            setTimeout(function () { $toggle.removeClass('NB-scope-toggle-denied'); }, 800);

            $('.NB-scope-tooltip').remove();
            var $tip = $('<div class="NB-scope-tooltip NB-scope-tooltip-denied">Requires Premium Archive</div>');
            $('body').append($tip);
            if ($toggle.length) {
                var rect = $toggle[0].getBoundingClientRect();
                $tip.css({
                    top: rect.top - $tip.outerHeight() - 6,
                    left: rect.left + rect.width / 2 - $tip.outerWidth() / 2
                });
            }
            setTimeout(function () { $tip.fadeOut(300, function () { $tip.remove(); }); }, 1500);
            return;
        }
        NEWSBLUR.reader.open_classifier_filter(this.filter.type, this.filter.value, {
            scope: new_scope,
            folder_name: this.filter.folder_name,
            origin: this.filter.origin
        });
    },

    // Toggle the classifier opinion — clicking the already-active opinion
    // untrains back to neutral. Writes through save_classifier and fires
    // recalculate_story_scores so every visible row flips immediately.
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

        NEWSBLUR.assets.update_cached_classifier_score(feed_id, type, value, new_score);
        this._refresh_story_scores(feed_id);
        this.render();

        NEWSBLUR.assets.save_classifier(save_data, function () {
            NEWSBLUR.assets.stories.trigger('render:intelligence');
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
