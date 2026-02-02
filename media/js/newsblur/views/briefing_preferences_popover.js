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
        "change .NB-modal-feed-chooser": "change_folder"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.prefs = {};
        this.folders = [];
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
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
        var selected_folder = sources.indexOf('folder:') === 0 ? sources.replace('folder:', 'river:') : null;

        // briefing_preferences_popover.js: Folder-only chooser
        var $folder_chooser = NEWSBLUR.utils.make_folders(selected_folder, "All Site Stories", 'feed', false);
        $folder_chooser.addClass('NB-modal-feed-chooser');

        this.$el.html($.make('div', [
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

        this.update_schedule_controls();
        this.update_style_description();

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

        this.set_active('frequency', prefs.frequency || 'daily');
        this.set_active('preferred_time', preferred_time);
        // briefing_preferences_popover.js: For 2x daily, map preferred_time to the combo control
        var twice_value = (preferred_time === 'evening') ? 'evening' : 'morning';
        this.set_active('twice_daily_time', twice_value);
        this.set_active('preferred_day', prefs.preferred_day || 'sun');
        this.set_active('story_count', String(prefs.story_count || 20));
        this.set_active('summary_length', prefs.summary_length || 'medium');
        this.set_active('summary_style', prefs.summary_style || 'editorial');
        this.set_active('read_filter', prefs.read_filter || 'unread');
        this.set_active('include_read', String(prefs.include_read));

        this.update_schedule_controls();
        this.update_style_description();
    },

    set_active: function (setting_name, value) {
        var $control = this.$('.NB-briefing-control-' + setting_name);
        $control.find('.NB-briefing-setting-option').removeClass('NB-active');
        $control.find('[data-value="' + value + '"]').addClass('NB-active');
    },

    update_style_description: function () {
        var descriptions = {
            'editorial': 'Flowing narrative that connects stories into a readable digest',
            'bullets': 'Concise bullet points highlighting key takeaways from each story',
            'headlines': 'Just the headlines with minimal commentary'
        };
        var active_style = this.$('.NB-briefing-control-summary_style .NB-active').data('value') || 'editorial';
        this.$('.NB-briefing-style-description').text(descriptions[active_style] || '');
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

        if (setting_name === 'summary_style') {
            this.update_style_description();
        }

        if (setting_name === 'frequency') {
            this.update_schedule_controls();
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

    save_preference: function (data) {
        $.ajax({
            url: '/briefing/preferences',
            type: 'POST',
            data: data
        });
    }

});
