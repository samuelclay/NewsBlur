NEWSBLUR.Views.BriefingOnboardingView = Backbone.View.extend({

    className: "NB-briefing-onboarding-view",

    events: {
        "click .NB-briefing-setting-option": "change_setting",
        "change .NB-modal-feed-chooser": "change_folder",
        "click .NB-briefing-onboarding-generate": "generate"
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
                    'Get an AI-generated summary of your top stories, delivered on your schedule.')
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
        var selected_folder = sources.indexOf('folder:') === 0 ? sources.replace('folder:', 'river:') : null;

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
                        ['morning', 'Morning + Afternoon'],
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
                    ['10', '10'],
                    ['20', '20'],
                    ['30', '30'],
                    ['50', '50']
                ]),
                this.make_control('summary_length', [
                    ['short', 'Short'],
                    ['medium', 'Medium'],
                    ['detailed', 'Long']
                ])
            ]),
            this.make_section('Writing style', null, [
                this.make_control('summary_style', [
                    ['editorial', 'Editorial'],
                    ['bullets', 'Bullets'],
                    ['headlines', 'Headlines']
                ]),
                $.make('div', { className: 'NB-briefing-style-description' })
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
            ])
        ]));

        // briefing_onboarding_view.js: Highlight active options based on loaded prefs
        var preferred_time = prefs.preferred_time || 'morning';
        this.set_active($settings, 'frequency', prefs.frequency || 'daily');
        this.set_active($settings, 'preferred_time', preferred_time);
        var twice_value = (preferred_time === 'evening') ? 'evening' : 'morning';
        this.set_active($settings, 'twice_daily_time', twice_value);
        this.set_active($settings, 'preferred_day', prefs.preferred_day || 'sun');
        this.set_active($settings, 'story_count', String(prefs.story_count || 20));
        this.set_active($settings, 'summary_length', prefs.summary_length || 'medium');
        this.set_active($settings, 'summary_style', prefs.summary_style || 'editorial');
        this.set_active($settings, 'read_filter', prefs.read_filter || 'unread');
        this.set_active($settings, 'include_read', String(prefs.include_read));

        this.update_schedule_controls($settings);
        this.update_style_description($settings);
        this.update_generate_button_text($settings);
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

    set_active: function ($container, setting_name, value) {
        var $control = $container.find('.NB-briefing-control-' + setting_name);
        $control.find('.NB-briefing-setting-option').removeClass('NB-active');
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

    update_generate_button_text: function ($settings) {
        var frequency = $settings.find('.NB-briefing-control-frequency .NB-active').data('value') || 'daily';
        var labels = {
            'twice_daily': 'Generate Twice-Daily Briefing',
            'daily': 'Generate Daily Briefing',
            'weekly': 'Generate Weekly Briefing'
        };
        this.$('.NB-briefing-onboarding-generate').text(labels[frequency] || labels['daily']);
    },

    update_style_description: function ($settings) {
        var descriptions = {
            'editorial': 'Flowing narrative that connects stories into a readable digest',
            'bullets': 'Concise bullet points highlighting key takeaways from each story',
            'headlines': 'Just the headlines with minimal commentary'
        };
        var active_style = $settings.find('.NB-briefing-control-summary_style .NB-active').data('value') || 'editorial';
        $settings.find('.NB-briefing-style-description').text(descriptions[active_style] || '');
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

        if (setting_name === 'summary_style') {
            this.update_style_description($settings);
        }

        if (setting_name === 'frequency') {
            this.update_schedule_controls($settings);
            this.update_generate_button_text($settings);
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

    generate: function (e) {
        e.preventDefault();
        var data = _.extend({}, this.pending || {});

        // briefing_onboarding_view.js: Save all pending preferences, then generate briefing
        $.ajax({
            url: '/briefing/preferences',
            type: 'POST',
            data: data,
            success: function () {
                NEWSBLUR.reader.generate_daily_briefing();
            }
        });
    }

});
