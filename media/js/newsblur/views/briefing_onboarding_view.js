NEWSBLUR.Views.BriefingOnboardingView = Backbone.View.extend({

    className: "NB-briefing-onboarding-view",

    events: {
        "click .NB-briefing-setting-option": "change_setting",
        "click .NB-briefing-style-option": "change_setting",
        "change .NB-modal-feed-chooser": "change_folder",
        "click .NB-briefing-onboarding-generate": "generate",
        "click .NB-briefing-section-item": "toggle_section",
        "click .NB-briefing-section-hint-icon": "stop_propagation",
        "blur .NB-briefing-custom-prompt-input": "update_custom_prompt",
        "mouseenter .NB-briefing-section-hint-icon": "show_hint_popover",
        "mouseleave .NB-briefing-section-hint-icon": "hide_hint_popover",
        "click .NB-briefing-add-keyword-section": "add_custom_section",
        "click .NB-briefing-remove-custom-section": "remove_custom_section",
        "click .NB-briefing-notification-option": "toggle_notification_type"
    },

    initialize: function (options) {
        this.options = options || {};
        this.pending = {};
        this.prefs = null;

        this.render_shell();

        // briefing_onboarding_view.js: Use preferences passed in from load_briefing_stories
        // to avoid a separate AJAX call and the race conditions that come with it.
        if (this.options.preferences) {
            this.prefs = this.options.preferences;
            this.populate_settings(this.prefs);
        } else {
            this.fetch_preferences();
        }
    },

    close: function () {
        this.remove();
    },

    render_shell: function () {
        this.$el.html($.make('div', { className: 'NB-briefing-onboarding' }, [
            $.make('div', { className: 'NB-briefing-onboarding-header' }, [
                $.make('div', { className: 'NB-briefing-onboarding-icon' }),
                $.make('div', { className: 'NB-briefing-onboarding-title' }, 'Daily Briefing'),
                $.make('div', { className: 'NB-briefing-onboarding-subtitle' },
                    'Get a summary of your top stories, delivered on your schedule.')
            ]),
            $.make('div', { className: 'NB-briefing-onboarding-settings NB-briefing-popover' }),
            $.make('div', { className: 'NB-briefing-onboarding-footer' }, [
                $.make('div', {
                    className: 'NB-briefing-generate-btn NB-briefing-generate-btn-large NB-briefing-onboarding-generate',
                    role: 'button'
                }, 'Generate Briefing')
            ])
        ]));
    },

    fetch_preferences: function () {
        var self = this;
        $.ajax({
            url: '/briefing/preferences',
            type: 'GET',
            dataType: 'json',
            success: function (data) {
                if (!self.$el.parent().length) return;
                self.prefs = data;
                self.populate_settings(data);
            },
            error: function () {
                if (!self.$el.parent().length) return;
                self.fetch_preferences();
            }
        });
    },

    populate_settings: function (prefs) {
        var sources = prefs.story_sources || 'all';
        var selected_folder = sources.indexOf('folder:') === 0 ? sources.slice(7) : null;

        var $folder_chooser = NEWSBLUR.utils.make_folders(selected_folder, "All Site Stories", 'feed', false);
        $folder_chooser.addClass('NB-modal-feed-chooser');

        var $settings = this.$('.NB-briefing-onboarding-settings');
        $settings.html($.make('div', [
            this.make_section('How often', 'Schedule when your briefing is generated', [
                this.make_control('frequency', [
                    ['twice_daily', '2x daily'],
                    ['daily', 'Daily'],
                    ['weekly', 'Weekly']
                ]),
                $.make('div', { className: 'NB-briefing-schedule-controls' }, [
                    this.make_control('preferred_time', [
                        ['morning', 'Morning'],
                        ['afternoon', 'Afternoon'],
                        ['evening', 'Evening']
                    ]),
                    this.make_control('twice_daily_time', [
                        ['afternoon', 'Morning + Afternoon'],
                        ['evening', 'Morning + Evening']
                    ]),
                    this.make_control('preferred_day', [
                        ['sun', 'Sun'],
                        ['mon', 'Mon'],
                        ['tue', 'Tue'],
                        ['wed', 'Wed'],
                        ['thu', 'Thu'],
                        ['fri', 'Fri'],
                        ['sat', 'Sat']
                    ])
                ])
            ]),
            this.make_section('Briefing length', 'Number of stories to include in each briefing', [
                this.make_control('story_count', [
                    ['5', '5'],
                    ['10', '10'],
                    ['15', '15'],
                    ['20', '20']
                ])
            ]),
            this.make_section('Writing style', null, [
                this.make_style_chooser()
            ]),
            this.make_section('Source feeds', 'Choose which feeds are used to build your briefing', [
                $.make('div', { className: 'NB-briefing-folder-chooser-container' }, [
                    $folder_chooser
                ]),
                this.make_icon_control('read_filter', [
                    ['unread', 'Unread', 'NB-unread-icon'],
                    ['focus', 'Focus', 'NB-focus-icon']
                ]),
                this.make_control('include_read', [
                    ['false', 'Unread only'],
                    ['true', 'Include read']
                ])
            ]),
            this.make_sections_ui(prefs),
            this.make_keywords_ui(prefs),
            this.make_notification_section(prefs)
        ]));

        // briefing_onboarding_view.js: Highlight active options based on loaded prefs
        var preferred_time = prefs.preferred_time || 'morning';
        this.set_active($settings, 'frequency', prefs.frequency || 'daily');
        this.set_active($settings, 'preferred_time', preferred_time);
        var twice_value = (preferred_time === 'evening') ? 'evening' : 'afternoon';
        this.set_active($settings, 'twice_daily_time', twice_value);
        this.set_active($settings, 'preferred_day', prefs.preferred_day || 'sun');
        this.set_active($settings, 'story_count', String(prefs.story_count || 5));
        this.set_active($settings, 'summary_style', prefs.summary_style || 'bullets');
        this.set_active($settings, 'read_filter', prefs.read_filter || 'unread');
        this.set_active($settings, 'include_read', String(prefs.include_read));

        this.update_schedule_controls($settings);
        this.update_generate_button_text($settings);
        this.update_story_count_labels($settings);
    },

    // ===========================
    // = Section/Control Helpers =
    // ===========================

    make_section: function (title, description, rows) {
        var label_children = [
            $.make('div', { className: 'NB-popover-section-title' }, title)
        ];
        if (description) {
            label_children.push($.make('div', { className: 'NB-popover-section-description' }, description));
        }
        return $.make('div', { className: 'NB-popover-section' }, [
            $.make('div', { className: 'NB-popover-section-label' }, label_children),
            $.make('div', { className: 'NB-popover-section-controls' }, rows)
        ]);
    },

    make_control: function (setting_name, options) {
        var items = _.map(options, function (opt) {
            return $.make('li', {
                className: 'NB-briefing-setting-option',
                'data-setting': setting_name,
                'data-value': opt[0],
                role: 'button'
            }, opt[1]);
        });
        return $.make('ul', { className: 'segmented-control NB-briefing-control-' + setting_name }, items);
    },

    make_icon_control: function (setting_name, options) {
        var items = _.map(options, function (opt) {
            return $.make('li', {
                className: 'NB-briefing-setting-option',
                'data-setting': setting_name,
                'data-value': opt[0],
                role: 'button'
            }, [
                $.make('div', { className: opt[2] }),
                opt[1]
            ]);
        });
        return $.make('ul', { className: 'segmented-control NB-briefing-control-' + setting_name }, items);
    },

    make_sections_ui: function (prefs) {
        var sections = prefs.sections || {};
        var items = _.map(NEWSBLUR.BRIEFING_SECTION_DEFINITIONS, _.bind(function (def) {
            return this.make_section_item(def, sections[def.key]);
        }, this));

        var $section = this.make_section('Sections', 'Choose which sections appear in your briefing', [
            $.make('div', { className: 'NB-briefing-sections' }, items)
        ]);
        $section.find('.NB-popover-section-label').append(
            $.make('div', { className: 'NB-briefing-notification-hint' },
                'Sections are only included when matching stories are found.')
        );
        return $section;
    },

    make_keywords_ui: function (prefs) {
        var sections = prefs.sections || {};
        var custom_prompts = prefs.custom_section_prompts || [];
        var items = [];

        for (var i = 0; i < custom_prompts.length; i++) {
            var custom_key = 'custom_' + (i + 1);
            items.push(this.make_keyword_section_item(i + 1, custom_prompts[i], sections[custom_key]));
        }

        if (custom_prompts.length < NEWSBLUR.MAX_CUSTOM_SECTIONS) {
            items.push($.make('div', { className: 'NB-briefing-add-keyword-section', role: 'button' }, [
                $.make('span', { className: 'NB-briefing-add-custom-icon' }, '+'),
                'Add keyword section'
            ]));
        }

        return this.make_section('Keyword sections', 'Add keyword filters that create their own briefing section. All keywords must match.', [
            $.make('div', { className: 'NB-briefing-sections NB-briefing-keyword-sections' }, items)
        ]);
    },

    make_style_chooser: function () {
        var STYLE_OPTIONS = [
            {
                value: 'bullets',
                name: 'Bullets',
                subtitle: 'Concise bullet points highlighting key takeaways from each story',
                icon: 'layout-magazine.svg'
            },
            {
                value: 'editorial',
                name: 'Editorial',
                subtitle: 'Flowing narrative that connects stories into a readable digest',
                icon: 'paragraph.svg'
            },
            {
                value: 'headlines',
                name: 'Headlines',
                subtitle: 'Just the headlines with minimal commentary',
                icon: 'content-preview-m.svg'
            }
        ];
        var items = _.map(STYLE_OPTIONS, function (opt) {
            var icon_url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/' + opt.icon;
            return $.make('div', {
                className: 'NB-briefing-style-option',
                'data-setting': 'summary_style',
                'data-value': opt.value
            }, [
                $.make('div', { className: 'NB-briefing-style-radio' }),
                $.make('img', { className: 'NB-briefing-style-option-icon', src: icon_url }),
                $.make('div', { className: 'NB-briefing-style-option-label' }, [
                    $.make('div', { className: 'NB-briefing-style-option-name' }, opt.name),
                    $.make('div', { className: 'NB-briefing-style-option-subtitle' }, opt.subtitle)
                ])
            ]);
        });
        return $.make('div', { className: 'NB-briefing-style-chooser NB-briefing-control-summary_style' }, items);
    },

    make_section_item: function (def, is_enabled) {
        var icon_url = $.favicon('briefing:' + def.key);
        return $.make('div', {
            className: 'NB-briefing-section-item' + (is_enabled ? ' NB-active' : ''),
            'data-section': def.key
        }, [
            $.make('div', { className: 'NB-briefing-section-checkbox' }),
            $.make('img', { className: 'NB-briefing-section-item-icon', src: icon_url }),
            $.make('div', { className: 'NB-briefing-section-label' }, [
                $.make('div', { className: 'NB-briefing-section-name' }, def.name),
                $.make('div', { className: 'NB-briefing-section-subtitle' }, def.subtitle)
            ])
        ]);
    },

    make_keyword_section_item: function (index, prompt, is_enabled) {
        var custom_key = 'custom_' + index;
        var $item = $.make('div', {
            className: 'NB-briefing-section-item NB-briefing-section-custom' + (is_enabled ? ' NB-active' : ''),
            'data-section': custom_key,
            'data-custom-index': index
        }, [
            $.make('div', { className: 'NB-briefing-section-checkbox' }),
            $.make('div', { className: 'NB-briefing-section-label' }, [
                $.make('div', { className: 'NB-briefing-section-name' }, [
                    'Keyword section ' + index,
                    $.make('img', {
                        className: 'NB-briefing-remove-custom-section',
                        'data-custom-index': index,
                        title: 'Remove',
                        src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/close.svg'
                    })
                ]),
                $.make('div', { className: 'NB-briefing-section-subtitle' }, 'Matches story titles containing all keywords')
            ])
        ]);

        var $custom_input = $.make('div', { className: 'NB-briefing-section-custom-input' }, [
            $.make('input', {
                type: 'text',
                className: 'NB-briefing-custom-prompt-input',
                'data-custom-index': index,
                placeholder: 'e.g. Claude Code',
                value: prompt || ''
            }),
            $.make('span', { className: 'NB-briefing-section-hint-icon' }, '\u24D8')
        ]);
        $item.append($custom_input);

        $item.append($.make('div', { className: 'NB-briefing-section-hint-popover' }, [
            $.make('div', { className: 'NB-briefing-section-hint-content' }, [
                $.make('div', { className: 'NB-briefing-section-hint-title' }, 'Keyword Section'),
                $.make('div', { className: 'NB-briefing-section-hint-text' },
                    'Enter keywords to create a section for matching stories. All keywords must appear in the story title.'),
                $.make('div', { className: 'NB-briefing-section-hint-examples-title' }, 'Examples'),
                $.make('ul', { className: 'NB-briefing-section-hint-examples' }, [
                    $.make('li', 'Claude Code'),
                    $.make('li', 'machine learning'),
                    $.make('li', 'open source'),
                    $.make('li', 'climate change')
                ])
            ])
        ]));

        return $item;
    },

    set_active: function ($container, setting_name, value) {
        var $control = $container.find('.NB-briefing-control-' + setting_name);
        $control.find('.NB-briefing-setting-option').removeClass('NB-active');
        $control.find('.NB-briefing-style-option').removeClass('NB-active');
        $control.find('[data-value="' + value + '"]').addClass('NB-active');
    },

    update_schedule_controls: function ($settings) {
        var frequency = $settings.find('.NB-briefing-control-frequency .NB-active').data('value') || 'daily';
        var $time_control = $settings.find('.NB-briefing-control-preferred_time');
        var $twice_control = $settings.find('.NB-briefing-control-twice_daily_time');
        var $day_control = $settings.find('.NB-briefing-control-preferred_day');

        if (frequency === 'twice_daily') {
            $time_control.hide();
            $twice_control.show();
            $day_control.hide();
        } else if (frequency === 'daily') {
            $time_control.show();
            $twice_control.hide();
            $day_control.hide();
        } else if (frequency === 'weekly') {
            $time_control.show();
            $twice_control.hide();
            $day_control.show();
        }
    },

    update_story_count_labels: function ($settings) {
        $settings.find('.NB-briefing-control-story_count .NB-briefing-setting-option').each(function () {
            var $opt = $(this);
            var value = $opt.data('value');
            var is_active = $opt.hasClass('NB-active');
            $opt.text(value + (is_active ? ' stories' : ''));
        });
    },

    update_generate_button_text: function ($settings) {
        var frequency = $settings.find('.NB-briefing-control-frequency .NB-active').data('value') || 'daily';
        var labels = {
            'twice_daily': 'Generate Twice-Daily Briefing',
            'daily': 'Generate Daily Briefing',
            'weekly': 'Generate Weekly Briefing'
        };
        this.$('.NB-briefing-onboarding-generate').text(labels[frequency] || labels['daily']);
    },

    // =====================
    // = Progress/Error UI =
    // =====================

    show_progress: function (message) {
        this.$('.NB-briefing-generate-btn').hide();
        this.$('.NB-briefing-progress').remove();
        this.$('.NB-briefing-error').remove();

        var $progress = $.make('div', { className: 'NB-briefing-progress' }, [
            $.make('div', { className: 'NB-briefing-progress-spinner' }),
            $.make('div', { className: 'NB-briefing-progress-message' }, message)
        ]);

        var $target = this.$('.NB-briefing-onboarding-footer');
        if ($target.length) {
            $target.append($progress);
        }
    },

    show_error: function (error_message) {
        this.$('.NB-briefing-progress').remove();
        this.$('.NB-briefing-error').remove();

        var $error = $.make('div', { className: 'NB-briefing-error' }, [
            $.make('div', { className: 'NB-briefing-error-message' }, error_message),
            $.make('div', { className: 'NB-briefing-generate-btn NB-briefing-generate-btn-small NB-briefing-onboarding-generate' }, 'Try Again')
        ]);

        var $target = this.$('.NB-briefing-onboarding-footer');
        if ($target.length) {
            $target.append($error);
        }
    },

    // ==========
    // = Events =
    // ==========

    change_setting: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var setting_name = $target.data('setting');
        var value = $target.data('value');
        var $settings = this.$('.NB-briefing-onboarding-settings');

        this.set_active($settings, setting_name, String(value));

        if (setting_name === 'frequency') {
            this.update_schedule_controls($settings);
            this.update_generate_button_text($settings);
        }

        if (setting_name === 'story_count') {
            this.update_story_count_labels($settings);
        }

        // briefing_onboarding_view.js: Map twice_daily_time to preferred_time for storage
        if (setting_name === 'twice_daily_time') {
            this.pending['preferred_time'] = value;
            return;
        }

        this.pending[setting_name] = value;
    },

    change_folder: function (e) {
        var value = $(e.currentTarget).val();
        if (!value) return;

        var story_sources = value ? value.replace('river:', 'folder:') : 'all';
        if (story_sources === 'folder:') {
            story_sources = 'all';
        }
        this.pending['story_sources'] = story_sources;
    },

    stop_propagation: function (e) {
        e.stopPropagation();
    },

    toggle_section: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.target);
        if ($target.is('input') || $target.closest('.NB-briefing-remove-custom-section').length) return;

        var $item = $(e.currentTarget);
        $item.toggleClass('NB-active');

        // briefing_onboarding_view.js: Accumulate sections in pending
        var sections = {};
        this.$('.NB-briefing-section-item').each(function () {
            sections[$(this).data('section')] = $(this).hasClass('NB-active');
        });
        this.pending['sections'] = JSON.stringify(sections);
    },

    add_custom_section: function (e) {
        e.preventDefault();
        e.stopPropagation();

        if (!this._custom_prompts) this._custom_prompts = [];
        if (this._custom_prompts.length >= NEWSBLUR.MAX_CUSTOM_SECTIONS) return;

        this._custom_prompts.push('');
        var new_index = this._custom_prompts.length;
        var custom_key = 'custom_' + new_index;

        var $sections_container = this.$('.NB-briefing-keyword-sections');
        var $add_btn = $sections_container.find('.NB-briefing-add-keyword-section');
        var $new_item = this.make_keyword_section_item(new_index, '', true);
        $add_btn.before($new_item);

        if (this._custom_prompts.length >= NEWSBLUR.MAX_CUSTOM_SECTIONS) {
            $add_btn.remove();
        }

        // Update pending
        var sections = {};
        this.$('.NB-briefing-section-item').each(function () {
            sections[$(this).data('section')] = $(this).hasClass('NB-active');
        });
        sections[custom_key] = true;
        this.pending['sections'] = JSON.stringify(sections);

        $new_item.find('.NB-briefing-custom-prompt-input').focus();
    },

    remove_custom_section: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var index = $(e.currentTarget).data('custom-index');
        if (this._custom_prompts) {
            this._custom_prompts.splice(index - 1, 1);
        }

        // Re-render by re-populating settings
        if (this.prefs) {
            this.prefs.custom_section_prompts = this._custom_prompts || [];
            this.populate_settings(this.prefs);
        }
    },

    update_custom_prompt: function () {
        var prompts = [];
        this.$('.NB-briefing-custom-prompt-input').each(function () {
            prompts.push($(this).val());
        });
        this._custom_prompts = prompts;
        this.pending['custom_section_prompts'] = JSON.stringify(prompts);
    },

    show_hint_popover: function (e) {
        var $icon = $(e.currentTarget);
        var $popover = $icon.data('popover');
        if (!$popover) {
            var $item = $icon.closest('.NB-briefing-section-item');
            $popover = $item.find('.NB-briefing-section-hint-popover');
        }
        if (!$popover || !$popover.length) return;

        var icon_rect = $icon[0].getBoundingClientRect();
        $popover.appendTo('body');

        // briefing_onboarding_view.js: Measure popover height, flip above icon if no room below
        $popover.css({ position: 'fixed', visibility: 'hidden', display: 'block', top: 0, left: 0, right: 'auto', bottom: 'auto' });
        var popover_height = $popover.outerHeight();
        var space_below = window.innerHeight - icon_rect.bottom - 8;
        var space_above = icon_rect.top - 8;
        var place_above = space_below < popover_height && space_above > space_below;

        $popover.css({
            visibility: '',
            display: '',
            right: window.innerWidth - icon_rect.right,
            left: 'auto'
        });
        if (place_above) {
            $popover.css({ top: 'auto', bottom: (window.innerHeight - icon_rect.top + 8) + 'px' });
        } else {
            $popover.css({ top: (icon_rect.bottom + 8) + 'px', bottom: 'auto' });
        }
        $popover.addClass('NB-visible');
        $icon.data('popover', $popover);

        // briefing_onboarding_view.js: Bind mouseleave on the portaled popover so it hides when mouse leaves
        if (!$popover.data('mouseleave-bound')) {
            $popover.on('mouseleave', function () {
                var $p = $(this);
                setTimeout(function () {
                    if (!$p.is(':hover') && !$icon.is(':hover')) {
                        $p.removeClass('NB-visible');
                    }
                }, 100);
            });
            $popover.data('mouseleave-bound', true);
        }
    },

    hide_hint_popover: function (e) {
        var $icon = $(e.currentTarget);
        var $popover = $icon.data('popover');
        if (!$popover) return;

        setTimeout(function () {
            if (!$popover.is(':hover') && !$icon.is(':hover')) {
                $popover.removeClass('NB-visible');
            }
        }, 100);
    },

    make_notification_section: function (prefs) {
        var notification_types = (prefs && prefs.notification_types) || [];

        var items = _.map([
            ['email', 'Email'],
            ['web', 'Web'],
            ['ios', 'iOS'],
            ['android', 'Android']
        ], function (opt) {
            var is_active = _.contains(notification_types, opt[0]);
            return $.make('li', {
                className: 'NB-briefing-notification-option NB-briefing-setting-option'
                    + (is_active ? ' NB-active' : ''),
                'data-type': opt[0],
                role: 'button'
            }, opt[1]);
        });

        var controls = [
            $.make('ul', {
                className: 'segmented-control NB-briefing-control-notifications'
            }, items)
        ];

        return this.make_section('Notifications', 'Get notified when a new briefing is ready', controls);
    },

    toggle_notification_type: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        $target.toggleClass('NB-active');

        // briefing_onboarding_view.js: Save immediately if feed exists, otherwise deferred to generate
        var briefing_feed_id = (this.prefs && this.prefs.briefing_feed_id) || null;
        if (briefing_feed_id) {
            this.save_notification_types();
        }
    },

    save_notification_types: function () {
        var feed_id = (this.prefs && this.prefs.briefing_feed_id) || null;
        if (!feed_id) return;

        var notification_types = [];
        this.$('.NB-briefing-notification-option.NB-active').each(function () {
            notification_types.push($(this).data('type'));
        });

        // briefing_onboarding_view.js: Save notification prefs via existing notifications API
        $.ajax({
            url: '/notifications/feed/',
            type: 'POST',
            data: {
                'feed_id': feed_id,
                'notification_types': notification_types,
                'notification_filter': 'unread'
            }
        });
    },

    generate: function (e) {
        e.preventDefault();
        var self = this;
        var data = _.extend({}, this.pending || {});

        // briefing_onboarding_view.js: Save all pending preferences, then generate briefing
        $.ajax({
            url: '/briefing/preferences',
            type: 'POST',
            data: data,
            success: function () {
                NEWSBLUR.reader.generate_daily_briefing(function (response) {
                    // briefing_onboarding_view.js: Feed created during generate,
                    // now save any notification selections the user made
                    if (response && response.briefing_feed_id) {
                        self.prefs = self.prefs || {};
                        self.prefs.briefing_feed_id = response.briefing_feed_id;
                        self.save_notification_types();
                    }
                });
            }
        });
    }

});
