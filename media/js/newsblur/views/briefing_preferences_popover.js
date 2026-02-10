NEWSBLUR.BRIEFING_SECTION_DEFINITIONS = [
    {key: "trending_unread", name: "Stories you missed", subtitle: "Popular stories you haven't read yet"},
    {key: "long_read", name: "Long reads for later", subtitle: "Longer articles worth setting time aside for"},
    {key: "classifier_match", name: "Based on your interests", subtitle: "Stories matching your trained topics and authors"},
    {key: "follow_up", name: "Follow-ups", subtitle: "New posts from feeds you recently read"},
    {key: "trending_global", name: "Trending across NewsBlur", subtitle: "Widely-read stories from across the platform"},
    {key: "duplicates", name: "Common stories", subtitle: "Stories covered by multiple feeds"},
    {key: "quick_catchup", name: "Quick catch-up", subtitle: "TL;DR of the most important stories"},
    {key: "emerging_topics", name: "Emerging topics", subtitle: "Topics getting increasing coverage"},
    {key: "contrarian_views", name: "Contrarian views", subtitle: "Different perspectives on the same topic"}
];

NEWSBLUR.MAX_CUSTOM_SECTIONS = 5;

NEWSBLUR.BriefingPreferencesPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-briefing-popover",

    options: {
        'width': 520,
        'anchor': '.NB-briefing-preferences-icon',
        'placement': 'bottom -left',
        'offset': {
            top: 4,
            left: 0
        },
        'overlay_top': true,
        'popover_class': 'NB-briefing-popover-container'
    },

    events: {
        "click .NB-briefing-setting-option": "change_setting",
        "click .NB-briefing-style-option": "change_setting",
        "change .NB-modal-feed-chooser": "change_folder",
        "click .NB-briefing-section-item": "toggle_section",
        "click .NB-briefing-section-hint-icon": "stop_propagation",
        "blur .NB-briefing-custom-prompt-input": "save_custom_prompt",
        "mouseenter .NB-briefing-section-hint-icon": "show_hint_popover",
        "mouseleave .NB-briefing-section-hint-icon": "hide_hint_popover",
        "click .NB-briefing-add-custom-section": "add_custom_section",
        "click .NB-briefing-remove-custom-section": "remove_custom_section",
        "click .NB-briefing-notification-option": "toggle_notification_type",
        "click .NB-briefing-model-option": "change_model"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.prefs = {};
        this.folders = [];
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);

        // briefing_preferences_popover.js: Hide hint popover when mouse leaves the popover itself
        $(document).on('mouseleave.briefing-hint', '.NB-briefing-section-hint-popover', function () {
            var $popover = $(this);
            setTimeout(function () {
                if (!$popover.is(':hover')) {
                    $popover.removeClass('NB-visible');
                }
            }, 100);
        });

        this.load_preferences();
    },

    load_preferences: function () {
        $.ajax({
            url: '/briefing/preferences',
            type: 'GET',
            dataType: 'json',
            success: _.bind(function (data) {
                this.prefs = data;
                this.folders = data.folders || [];
                this.render();
                this.highlight_active_options();
            }, this)
        });
    },

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        var sources = this.prefs.story_sources || 'all';
        var selected_folder = sources.indexOf('folder:') === 0 ? sources.slice(7) : null;

        // briefing_preferences_popover.js: Folder-only chooser
        var $folder_chooser = NEWSBLUR.utils.make_folders(selected_folder, "All Site Stories", 'feed', false);
        $folder_chooser.addClass('NB-modal-feed-chooser');

        this.$el.html($.make('div', [
            this.make_section('Auto-generate', 'Automatically generate briefings on schedule', [
                this.make_control('enabled', [
                    ['true', 'On'],
                    ['false', 'Off']
                ])
            ]),
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
            this.make_sections_ui(),
            this.make_model_section(),
            this.make_notification_section()
        ]));

        this.update_schedule_controls();
        this.update_story_count_labels();

        return this;
    },

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
        // briefing_preferences_popover.js: Segmented control with icons (e.g. unread/focus)
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

    update_schedule_controls: function () {
        // briefing_preferences_popover.js: Show/hide time and day controls based on frequency
        var frequency = this.$('.NB-briefing-control-frequency .NB-active').data('value') || 'daily';
        var $time_control = this.$('.NB-briefing-control-preferred_time');
        var $twice_control = this.$('.NB-briefing-control-twice_daily_time');
        var $day_control = this.$('.NB-briefing-control-preferred_day');

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

    highlight_active_options: function () {
        var prefs = this.prefs;
        var preferred_time = prefs.preferred_time || 'morning';

        this.set_active('enabled', String(prefs.enabled));
        this.set_active('frequency', prefs.frequency || 'daily');
        this.set_active('preferred_time', preferred_time);
        // briefing_preferences_popover.js: For 2x daily, map preferred_time to the combo control
        var twice_value = (preferred_time === 'evening') ? 'evening' : 'afternoon';
        this.set_active('twice_daily_time', twice_value);
        this.set_active('preferred_day', prefs.preferred_day || 'sun');
        this.set_active('story_count', String(prefs.story_count || 5));
        this.set_active('summary_style', prefs.summary_style || 'bullets');
        this.set_active('read_filter', prefs.read_filter || 'unread');
        this.set_active('include_read', String(prefs.include_read));

        this.update_schedule_controls();
        this.update_story_count_labels();
    },

    set_active: function (setting_name, value) {
        var $control = this.$('.NB-briefing-control-' + setting_name);
        $control.find('.NB-briefing-setting-option').removeClass('NB-active');
        $control.find('.NB-briefing-style-option').removeClass('NB-active');
        $control.find('[data-value="' + value + '"]').addClass('NB-active');
    },

    make_sections_ui: function () {
        var sections = this.prefs.sections || {};
        var items = _.map(NEWSBLUR.BRIEFING_SECTION_DEFINITIONS, _.bind(function (def) {
            return this.make_section_item(def, sections[def.key]);
        }, this));

        // briefing_preferences_popover.js: Add existing custom sections
        var custom_prompts = this.prefs.custom_section_prompts || [];
        for (var i = 0; i < custom_prompts.length; i++) {
            var custom_key = 'custom_' + (i + 1);
            items.push(this.make_custom_section_item(i + 1, custom_prompts[i], sections[custom_key]));
        }

        // briefing_preferences_popover.js: "Add custom section" button (up to MAX_CUSTOM_SECTIONS)
        if (custom_prompts.length < NEWSBLUR.MAX_CUSTOM_SECTIONS) {
            items.push($.make('div', { className: 'NB-briefing-add-custom-section', role: 'button' }, [
                $.make('span', { className: 'NB-briefing-add-custom-icon' }, '+'),
                'Add custom section'
            ]));
        }

        var $section = this.make_section('Sections', 'Choose which sections appear in your briefing', [
            $.make('div', { className: 'NB-briefing-sections' }, items)
        ]);
        $section.find('.NB-popover-section-label').append(
            $.make('div', { className: 'NB-briefing-notification-hint' },
                'Sections are only included when matching stories are found.')
        );
        return $section;
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

    make_custom_section_item: function (index, prompt, is_enabled) {
        var custom_key = 'custom_' + index;
        var $item = $.make('div', {
            className: 'NB-briefing-section-item NB-briefing-section-custom' + (is_enabled ? ' NB-active' : ''),
            'data-section': custom_key,
            'data-custom-index': index
        }, [
            $.make('div', { className: 'NB-briefing-section-checkbox' }),
            $.make('div', { className: 'NB-briefing-section-label' }, [
                $.make('div', { className: 'NB-briefing-section-name' }, [
                    'Custom section ' + index,
                    $.make('img', {
                        className: 'NB-briefing-remove-custom-section',
                        'data-custom-index': index,
                        title: 'Remove',
                        src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/close.svg'
                    })
                ]),
                $.make('div', { className: 'NB-briefing-section-subtitle' }, 'Custom section from your prompt')
            ])
        ]);

        var $custom_input = $.make('div', {
            className: 'NB-briefing-section-custom-input'
        }, [
            $.make('input', {
                type: 'text',
                className: 'NB-briefing-custom-prompt-input',
                'data-custom-index': index,
                placeholder: 'e.g. Summarize AI/ML news',
                value: prompt || ''
            }),
            $.make('span', { className: 'NB-briefing-section-hint-icon' }, '\u24D8')
        ]);
        $item.append($custom_input);

        // briefing_preferences_popover.js: Hint popover stored inside the item
        $item.append(this.make_hint_popover());

        return $item;
    },

    make_hint_popover: function () {
        return $.make('div', { className: 'NB-briefing-section-hint-popover' }, [
            $.make('div', { className: 'NB-briefing-section-hint-content' }, [
                $.make('div', { className: 'NB-briefing-section-hint-title' }, 'Custom Section Prompt'),
                $.make('div', { className: 'NB-briefing-section-hint-text' },
                    'Write a prompt describing what you want this section to cover. Relevant stories will be selected and an appropriate section header generated.'),
                $.make('div', { className: 'NB-briefing-section-hint-examples-title' }, 'Examples'),
                $.make('ul', { className: 'NB-briefing-section-hint-examples' }, [
                    $.make('li', 'Summarize AI and machine learning news'),
                    $.make('li', 'Focus on climate and environment stories'),
                    $.make('li', 'What\'s happening in tech policy and regulation'),
                    $.make('li', 'Stories about open source projects')
                ])
            ])
        ]);
    },

    update_story_count_labels: function () {
        // briefing_preferences_popover.js: Show "X stories" for active option, just "X" for others
        this.$('.NB-briefing-control-story_count .NB-briefing-setting-option').each(function () {
            var $opt = $(this);
            var value = $opt.data('value');
            var is_active = $opt.hasClass('NB-active');
            $opt.text(value + (is_active ? ' stories' : ''));
        });
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

        this.set_active(setting_name, String(value));

        if (setting_name === 'frequency') {
            this.update_schedule_controls();
        }

        if (setting_name === 'story_count') {
            this.update_story_count_labels();
        }

        // briefing_preferences_popover.js: Map twice_daily_time to preferred_time for storage
        if (setting_name === 'twice_daily_time') {
            this.save_preference({ preferred_time: value });
            return;
        }

        var data = {};
        data[setting_name] = value;
        this.save_preference(data);
    },

    change_folder: function (e) {
        var value = $(e.currentTarget).val();
        if (!value) return;

        // briefing_preferences_popover.js: Save folder selection as story_sources
        var story_sources = value ? value.replace('river:', 'folder:') : 'all';
        if (story_sources === 'folder:') {
            story_sources = 'all';
        }
        this.save_preference({ story_sources: story_sources });
    },

    stop_propagation: function (e) {
        e.stopPropagation();
    },

    toggle_section: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.target);
        // briefing_preferences_popover.js: Don't toggle when clicking input, remove button, or hint icon
        if ($target.is('input') || $target.closest('.NB-briefing-remove-custom-section').length) return;

        var $item = $(e.currentTarget);
        $item.toggleClass('NB-active');
        this.save_sections();
    },

    add_custom_section: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var custom_prompts = this.prefs.custom_section_prompts || [];
        if (custom_prompts.length >= NEWSBLUR.MAX_CUSTOM_SECTIONS) return;

        custom_prompts.push('');
        this.prefs.custom_section_prompts = custom_prompts;

        var new_index = custom_prompts.length;
        var custom_key = 'custom_' + new_index;

        // briefing_preferences_popover.js: Enable the new custom section by default
        if (!this.prefs.sections) this.prefs.sections = {};
        this.prefs.sections[custom_key] = true;

        // Re-render sections UI
        var $sections_container = this.$('.NB-briefing-sections');
        var $add_btn = $sections_container.find('.NB-briefing-add-custom-section');
        var $new_item = this.make_custom_section_item(new_index, '', true);
        $add_btn.before($new_item);

        if (custom_prompts.length >= NEWSBLUR.MAX_CUSTOM_SECTIONS) {
            $add_btn.remove();
        }

        this.save_sections();
        this.save_custom_prompts();

        // Focus the new input
        $new_item.find('.NB-briefing-custom-prompt-input').focus();
    },

    remove_custom_section: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var index = $(e.currentTarget).data('custom-index');
        var custom_prompts = this.prefs.custom_section_prompts || [];

        // briefing_preferences_popover.js: Remove the custom section and re-index
        custom_prompts.splice(index - 1, 1);
        this.prefs.custom_section_prompts = custom_prompts;

        // Re-index sections keys
        if (this.prefs.sections) {
            for (var i = 1; i <= NEWSBLUR.MAX_CUSTOM_SECTIONS; i++) {
                delete this.prefs.sections['custom_' + i];
            }
            for (var j = 0; j < custom_prompts.length; j++) {
                this.prefs.sections['custom_' + (j + 1)] = true;
            }
        }

        // briefing_preferences_popover.js: Remove the DOM element directly instead of re-rendering
        var $item = $(e.currentTarget).closest('.NB-briefing-section-item');
        $item.find('.NB-briefing-section-hint-icon').each(function () {
            var $pop = $(this).data('popover');
            if ($pop) $pop.remove();
        });
        $item.remove();

        // Re-index remaining custom section items
        var $sections_container = this.$('.NB-briefing-sections');
        $sections_container.find('.NB-briefing-section-custom').each(function (idx) {
            var new_index = idx + 1;
            var $el = $(this);
            $el.attr('data-section', 'custom_' + new_index);
            $el.find('.NB-briefing-section-name').contents().first().replaceWith('Custom section ' + new_index);
            $el.find('.NB-briefing-remove-custom-section').attr('data-custom-index', new_index);
            $el.find('.NB-briefing-custom-prompt-input').attr('data-custom-index', new_index);
        });

        // Re-show add button if under max
        if (custom_prompts.length < NEWSBLUR.MAX_CUSTOM_SECTIONS && !$sections_container.find('.NB-briefing-add-custom-section').length) {
            $sections_container.append($.make('div', { className: 'NB-briefing-add-custom-section' }, [
                $.make('span', { className: 'NB-briefing-add-custom-icon' }, '+'),
                'Add custom section'
            ]));
        }

        // Save to backend
        this.save_sections();
        this.save_custom_prompts();
    },

    save_sections: function () {
        var sections = {};
        this.$('.NB-briefing-section-item').each(function () {
            sections[$(this).data('section')] = $(this).hasClass('NB-active');
        });
        this.prefs.sections = sections;
        this.save_preference({ sections: JSON.stringify(sections) });
    },

    save_custom_prompts: function () {
        var prompts = [];
        this.$('.NB-briefing-custom-prompt-input').each(function () {
            prompts.push($(this).val());
        });
        this.prefs.custom_section_prompts = prompts;
        this.save_preference({ custom_section_prompts: JSON.stringify(prompts) });
    },

    save_custom_prompt: function (e) {
        this.save_custom_prompts();
    },

    show_hint_popover: function (e) {
        var $icon = $(e.currentTarget);
        // briefing_preferences_popover.js: Use cached popover if available (survives portal to body)
        var $popover = $icon.data('popover');
        if (!$popover) {
            var $item = $icon.closest('.NB-briefing-section-item');
            $popover = $item.find('.NB-briefing-section-hint-popover');
        }
        if (!$popover || !$popover.length) return;

        // briefing_preferences_popover.js: Portal to body for proper overflow handling
        var icon_rect = $icon[0].getBoundingClientRect();
        $popover.appendTo('body');

        // briefing_preferences_popover.js: Measure popover height, flip above icon if no room below
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

        // briefing_preferences_popover.js: Bind mouseleave on the portaled popover so it hides when mouse leaves
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

    make_notification_section: function () {
        var notification_types = this.prefs.notification_types || [];

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

        // briefing_preferences_popover.js: Save immediately if feed exists
        if (this.prefs.briefing_feed_id) {
            this.save_notification_types();
        }
    },

    save_notification_types: function () {
        var feed_id = this.prefs.briefing_feed_id;
        if (!feed_id) return;

        var notification_types = [];
        this.$('.NB-briefing-notification-option.NB-active').each(function () {
            notification_types.push($(this).data('type'));
        });

        // briefing_preferences_popover.js: Save notification prefs via existing notifications API
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

    make_model_section: function () {
        var current_model = this.prefs.briefing_model || 'haiku';
        var models = this.prefs.briefing_models || [];

        var items = _.map(models, function (m) {
            return $.make('div', {
                className: 'NB-briefing-style-option NB-briefing-model-option'
                    + (m.key === current_model ? ' NB-active' : ''),
                'data-setting': 'briefing_model',
                'data-value': m.key
            }, [
                $.make('div', { className: 'NB-briefing-style-radio' }),
                $.make('span', {
                    className: 'NB-provider-pill NB-provider-' + m.vendor
                }, m.vendor_display),
                $.make('div', { className: 'NB-briefing-style-option-label' }, [
                    $.make('div', { className: 'NB-briefing-style-option-name' }, m.display_name)
                ])
            ]);
        });

        var controls = [
            $.make('div', {
                className: 'NB-briefing-model-chooser NB-briefing-control-briefing_model'
            }, items)
        ];

        return this.make_section('AI Model', 'Choose which AI model writes your briefing', controls);
    },

    change_model: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var value = $target.data('value');

        this.$('.NB-briefing-model-option').removeClass('NB-active');
        $target.addClass('NB-active');

        this.save_preference({ briefing_model: value });
    },

    save_preference: function (data) {
        $.ajax({
            url: '/briefing/preferences',
            type: 'POST',
            data: data
        });
    }

});
