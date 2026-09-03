// Sticky banner that appears above .NB-story-titles when the user enters
// the classifier filter view. It keeps the active value prominent while
// grouping scope, training, and notification actions into a quiet toolbar.

NEWSBLUR.Views.ClassifierFilterBannerView = Backbone.View.extend({

    className: "NB-classifier-filter-banner",

    events: {
        "click .NB-classifier-filter-banner-clear": "close",
        "click .NB-classifier-filter-banner-back-trainer": "back_to_trainer",
        "click .NB-classifier-filter-scope-button": "change_scope",
        "click .NB-classifier-filter-training-button": "apply_training",
        "click .NB-classifier-filter-notification-button": "toggle_notification",
        "click .NB-classifier-filter-notification-upgrade": "open_notification_upgrade"
    },

    type_label_map: {
        'tag': 'Tag',
        'author': 'Author',
        'title': 'Title',
        'url': 'URL',
        'text': 'Text'
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

        // Load the current notification channels for the inline controls.
        // Re-render if the response lands after the initial paint.
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
        var type_label = this.type_label_map[type] || Inflector.capitalize(type);

        var $icon = $.make('div', { className: 'NB-classifier-filter-banner-icon' });
        $icon.html(this.type_icons[type] || '');

        var $heading = $.make('div', { className: 'NB-classifier-filter-banner-heading' }, [
            $.make('span', { className: 'NB-classifier-filter-banner-type' }, type_label),
            $.make('span', { className: 'NB-classifier-filter-banner-separator' }, '\u00b7'),
            $.make('span', { className: 'NB-classifier-filter-banner-value' }, this.filter.value)
        ]);
        var $narrow_hint = $.make('div', {
            className: 'NB-classifier-filter-narrow-hint',
            'aria-label': 'Widen the story titles pane to use filter controls'
        }, [
            $.make('span', {
                className: 'NB-classifier-filter-narrow-hint-label'
            }, 'Widen pane for controls'),
            $.make('span', {
                className: 'NB-classifier-filter-narrow-hint-compact',
                'aria-hidden': 'true'
            }, '\u2194')
        ]);
        var $view_section = $.make('section', {
            className: 'NB-classifier-filter-view-section',
            'aria-label': 'Filter stories'
        }, this._make_scope_controls());
        var $account_controls = $.make('div', {
            className: 'NB-classifier-filter-account-controls'
        }, [
            this._make_training_controls(),
            this._make_notification_controls(
                type,
                this.filter.value,
                this.filter.classifier_scope || 'feed',
                this.filter.classifier_folder_name || ''
            )
        ]);
        var $account_section = $.make('section', {
            className: 'NB-classifier-filter-account-section',
            'aria-label': 'Train and notification settings'
        }, $account_controls);
        var $tools = $.make('div', { className: 'NB-classifier-filter-banner-tools' }, [
            $view_section,
            $account_section
        ]);

        var $content = $.make('div', { className: 'NB-classifier-filter-banner-content' }, [
            $heading,
            $narrow_hint,
            $tools
        ]);

        var $actions = $.make('div', { className: 'NB-classifier-filter-banner-actions' });
        if (origin === 'trainer') {
            $actions.append($.make('button', {
                type: 'button',
                className: 'NB-classifier-filter-banner-back-trainer',
                'aria-label': 'Back to classifier trainer'
            }, 'Back to trainer'));
        }
        $actions.append($.make('button', {
            type: 'button',
            className: 'NB-classifier-filter-banner-clear',
            'aria-label': 'Clear classifier filter'
        }, $.make(
            'span',
            { className: 'NB-classifier-filter-banner-clear-icon', 'aria-hidden': 'true' },
            '\u2715'
        )));

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

    _make_scope_controls: function () {
        var scope = this.filter.scope || 'feed';
        var scope_labels = {
            feed: 'Site',
            folder: 'Folder',
            global: 'All'
        };
        var $buttons = $.make('span', {
            className: 'NB-classifier-filter-segmented',
            role: 'group',
            'aria-label': 'Classifier filter scope'
        });

        _.each(NEWSBLUR.ClassifierConstants.SCOPE_ICON_DATA, function (icon) {
            var $button = $.make('button', {
                type: 'button',
                className: 'NB-classifier-filter-scope-button' +
                    (icon.key === scope ? ' NB-active' : ''),
                title: icon.title,
                'aria-label': icon.title,
                'aria-pressed': icon.key === scope ? 'true' : 'false',
                'data-scope': icon.key
            });
            $button.html(icon.svg);
            $button.append($.make(
                'span',
                { className: 'NB-classifier-filter-button-label' },
                scope_labels[icon.key]
            ));
            $buttons.append($button);
        });

        return $.make('span', { className: 'NB-classifier-filter-tool-group' }, [
            $.make('span', { className: 'NB-classifier-filter-tool-label' }, 'Filter stories'),
            $buttons
        ]);
    },

    _make_training_controls: function () {
        var score = this._lookup_current_score();
        var controls = [
            {
                key: 'like',
                label: 'Like matching stories',
                short_label: 'Like',
                active: score > 0,
                icon: '<span class="NB-classifier-filter-training-icon NB-training-icon-like" aria-hidden="true"></span>'
            },
            {
                key: 'dislike',
                label: 'Dislike matching stories',
                short_label: 'Dislike',
                active: score < 0 && score > -2,
                icon: '<span class="NB-classifier-filter-training-icon NB-training-icon-dislike" aria-hidden="true"></span>'
            },
            {
                key: 'super_dislike',
                label: 'Hide matching stories',
                short_label: 'Hide',
                active: score <= -2,
                icon: '<span class="NB-classifier-filter-super-dislike-icon" aria-hidden="true">' +
                    '<span class="NB-classifier-filter-training-icon NB-training-icon-dislike NB-super-dislike-icon-back"></span>' +
                    '<span class="NB-classifier-filter-training-icon NB-training-icon-dislike NB-super-dislike-icon-front"></span>' +
                    '</span>'
            }
        ];

        var $buttons = $.make('span', {
            className: 'NB-classifier-filter-segmented NB-classifier-filter-training-segmented',
            role: 'group',
            'aria-label': 'Train this classifier'
        });
        _.each(controls, function (control) {
            var $button = $.make('button', {
                type: 'button',
                className: 'NB-classifier-filter-training-button NB-training-' + control.key +
                    (control.active ? ' NB-active' : ''),
                title: control.label,
                'aria-label': control.label,
                'aria-pressed': control.active ? 'true' : 'false',
                'data-opinion': control.key
            });
            $button.html(control.icon);
            $button.append($.make(
                'span',
                { className: 'NB-classifier-filter-button-label' },
                control.short_label
            ));
            $buttons.append($button);
        });

        return $.make('span', { className: 'NB-classifier-filter-tool-group' }, [
            $.make('span', { className: 'NB-classifier-filter-tool-label' }, 'Train'),
            $buttons
        ]);
    },

    _notification_state: function (type, value, scope, folder_name) {
        var feed_id = this.filter.feed_id || NEWSBLUR.reader.active_feed;
        var notif_key = type + ':' + value + '::' + scope + ':' +
            (scope === 'feed' ? feed_id : 0) + ':' + (folder_name || '');
        var notif = this._classifier_notifications && this._classifier_notifications[notif_key];
        return {
            feed_id: scope === 'feed' ? feed_id : 0,
            key: notif_key,
            notification: notif || {},
            notification_types: ((notif && notif.notification_types) || []).slice()
        };
    },

    _make_notification_controls: function (type, value, scope, folder_name) {
        var state = this._notification_state(type, value, scope, folder_name);
        var is_archive = NEWSBLUR.Globals.is_archive;
        var channel_icons = NEWSBLUR.Views.ClassifierNotificationPopover &&
            NEWSBLUR.Views.ClassifierNotificationPopover.CHANNEL_ICONS || {};
        var channels = [
            { key: 'email', short_label: 'Email' },
            { key: 'web', short_label: 'Web' },
            { key: 'ios', short_label: 'iOS' },
            { key: 'android', short_label: 'Android' }
        ];
        var $buttons = $.make('span', {
            className: 'NB-classifier-filter-segmented NB-classifier-filter-notification-segmented' +
                (!is_archive ? ' NB-disabled' : ''),
            role: 'group',
            'aria-label': is_archive ? 'Notify on match' :
                'Notify on match. Premium Archive required'
        });
        _.each(channels, function (channel) {
            var is_active = _.contains(state.notification_types, channel.key);
            var label = channel.short_label + ' notifications';
            var $button = $.make('button', {
                type: 'button',
                className: 'NB-classifier-filter-notification-button NB-notification-' + channel.key +
                    (is_active ? ' NB-active' : ''),
                title: is_archive ? label : label + ' require Premium Archive',
                'aria-label': label,
                'aria-pressed': is_active ? 'true' : 'false',
                'aria-disabled': !is_archive ? 'true' : 'false',
                'data-channel': channel.key
            });
            if (!is_archive) $button.prop('disabled', true);
            if (channel_icons[channel.key]) {
                var $icon = $.make('span', {
                    className: 'NB-classifier-filter-notification-icon',
                    'aria-hidden': 'true'
                });
                $icon.html(channel_icons[channel.key]);
                $button.append($icon);
            }
            $button.append($.make(
                'span',
                { className: 'NB-classifier-filter-button-label' },
                channel.short_label
            ));
            $buttons.append($button);
        });

        var $notification_content = $.make('span', {
            className: 'NB-classifier-filter-notification-content'
        }, $buttons);
        if (!is_archive) {
            $notification_content.append($.make('button', {
                type: 'button',
                className: 'NB-classifier-filter-notification-upgrade',
                'aria-label': 'Upgrade to Premium Archive for classifier notifications'
            }, 'Upgrade to Premium Archive'));
        }

        return $.make('span', {
            className: 'NB-classifier-filter-tool-group NB-classifier-filter-notification-group'
        }, [
            $.make('span', { className: 'NB-classifier-filter-tool-label' }, 'Notify on'),
            $notification_content
        ]);
    },

    // Only checks feed-scoped classifiers on the active feed; folder/global
    // scopes start at neutral in the pill and flip to their trained state
    // after the user clicks.
    _lookup_current_score: function () {
        var feed_id = this.filter.feed_id || NEWSBLUR.reader.active_feed;
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
        this.stopListening();
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

    change_scope: function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        this._change_scope($(e.currentTarget).data('scope'));
    },

    apply_training: function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        this._apply_training($(e.currentTarget).data('opinion'));
    },

    toggle_notification: function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        if (!NEWSBLUR.Globals.is_archive) {
            this.open_notification_upgrade();
            return;
        }

        var channel = $(e.currentTarget).data('channel');
        var type = this.filter.type;
        var value = this.filter.value;
        var scope = this.filter.classifier_scope || 'feed';
        var folder_name = this.filter.classifier_folder_name || '';
        var state = this._notification_state(type, value, scope, folder_name);
        var notification_types = state.notification_types;
        if (_.contains(notification_types, channel)) {
            notification_types = _.without(notification_types, channel);
        } else {
            notification_types.push(channel);
        }

        this._classifier_notifications[state.key] = $.extend({}, state.notification, {
            classifier_type: type,
            classifier_value: value,
            is_regex: false,
            scope: scope,
            feed_id: state.feed_id,
            folder_name: folder_name,
            notification_types: notification_types
        });
        this.render();

        var self = this;
        NEWSBLUR.assets.set_classifier_notification({
            classifier_type: type,
            classifier_value: value,
            is_regex: false,
            scope: scope,
            feed_id: state.feed_id,
            folder_name: folder_name,
            notification_types: notification_types
        }, function (resp) {
            if (resp && resp.classifier_notifications) {
                self._classifier_notifications = resp.classifier_notifications;
                self.render();
            }
        });
    },

    open_notification_upgrade: function (e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: 'notifications' });
    },

    // Filter scope changes story-list context only. Classifier training and
    // notification scope stay on the separate classifier_scope fields.
    _change_scope: function (new_scope) {
        if (!new_scope || new_scope === (this.filter.scope || 'feed')) return;
        var folder_name = new_scope === 'folder' ?
            (this.filter.river_folder_name || 'Everything') : null;
        NEWSBLUR.reader.open_classifier_filter(this.filter.type, this.filter.value, {
            scope: new_scope,
            folder_name: folder_name,
            feed_id: this.filter.feed_id,
            river_folder_name: this.filter.river_folder_name,
            river_feed_id: this.filter.river_feed_id,
            story_hash: this.filter.story_hash,
            classifier_scope: this.filter.classifier_scope,
            classifier_folder_name: this.filter.classifier_folder_name,
            origin: this.filter.origin,
            navigate_to_scope: true
        });
    },

    // Toggle the classifier opinion — clicking the already-active opinion
    // untrains back to neutral. Writes through save_classifier and fires
    // recalculate_story_scores so every visible row flips immediately.
    _apply_training: function (opinion) {
        var feed_id = this.filter.feed_id || NEWSBLUR.reader.active_feed;
        if (!feed_id || !_.isFinite(feed_id)) return;

        var type = this.filter.type;
        var value = this.filter.value;
        var current_score = this._lookup_current_score();

        var opinion_to_score = { like: 1, dislike: -1, super_dislike: -2 };
        var target_score = opinion_to_score[opinion];
        if (target_score === undefined) return;

        var save_data = { feed_id: feed_id };
        var classifier_scope = this.filter.classifier_scope || 'feed';
        if (classifier_scope !== 'feed') {
            save_data.scope = classifier_scope;
            save_data.folder_name = this.filter.classifier_folder_name || '';
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
