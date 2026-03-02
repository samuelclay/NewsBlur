NEWSBLUR.MediaPlayerSettingsPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-media-settings-popover",

    options: {
        'width': 340,
        'anchor': '.NB-media-player-settings',
        'placement': 'top -right',
        'offset': {
            top: -8,
            left: 0
        },
        'overlay_top': true,
        'popover_class': 'NB-media-settings-popover-container'
    },

    events: {
        "click .NB-media-setting-option": "change_setting"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.media_player = NEWSBLUR.app.media_player;
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.render();
    },

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.$el.html($.make('div', [
            this.make_section('Skip Back', 'Seconds to skip backward', [
                this.make_control('skip_back', [
                    ['5', '5s'],
                    ['10', '10s'],
                    ['15', '15s'],
                    ['30', '30s'],
                    ['60', '60s']
                ])
            ]),
            this.make_section('Skip Forward', 'Seconds to skip forward', [
                this.make_control('skip_forward', [
                    ['10', '10s'],
                    ['15', '15s'],
                    ['30', '30s'],
                    ['60', '60s'],
                    ['90', '90s']
                ])
            ]),
            this.make_section('Auto-play', 'Automatically play next item in queue', [
                this.make_control('auto_play_next', [
                    ['true', 'On'],
                    ['false', 'Off']
                ])
            ]),
            this.make_section('Resume', 'Remember playback position for each episode', [
                this.make_control('remember_position', [
                    ['true', 'On'],
                    ['false', 'Off']
                ])
            ]),
            this.make_section('Show on Load', 'Restore the player when you reload NewsBlur', [
                this.make_control('resume_on_load', [
                    ['true', 'On'],
                    ['false', 'Off']
                ])
            ])
        ]));

        this.highlight_active_options();
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
                className: 'NB-media-setting-option',
                'data-setting': setting_name,
                'data-value': opt[0],
                role: 'button'
            }, opt[1]);
        });

        return $.make('ul', { className: 'segmented-control NB-media-control-' + setting_name }, items);
    },

    highlight_active_options: function () {
        var mp = this.media_player;
        this.set_active('skip_back', String(mp.skip_back_seconds || 15));
        this.set_active('skip_forward', String(mp.skip_forward_seconds || 30));
        this.set_active('auto_play_next', String(mp.auto_play_next !== false));
        this.set_active('remember_position', String(mp.remember_position !== false));
        this.set_active('resume_on_load', String(mp.resume_on_load !== false));
    },

    set_active: function (setting_name, value) {
        var $control = this.$('.NB-media-control-' + setting_name);
        $control.find('.NB-media-setting-option').removeClass('NB-active');
        $control.find('[data-value="' + value + '"]').addClass('NB-active');
    },

    change_setting: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var setting_name = $target.data('setting');
        var value = $target.data('value');

        this.set_active(setting_name, String(value));

        var mp = this.media_player;

        if (setting_name === 'skip_back') {
            mp.skip_back_seconds = parseInt(value, 10);
        } else if (setting_name === 'skip_forward') {
            mp.skip_forward_seconds = parseInt(value, 10);
        } else if (setting_name === 'auto_play_next') {
            mp.auto_play_next = value === 'true';
        } else if (setting_name === 'remember_position') {
            mp.remember_position = value === 'true';
        } else if (setting_name === 'resume_on_load') {
            mp.resume_on_load = value === 'true';
        }

        mp.update_skip_labels();
        mp.save_durable_state();
    }

});
