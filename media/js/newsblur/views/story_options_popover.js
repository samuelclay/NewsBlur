NEWSBLUR.StoryOptionsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-style-popover",
    
    options: {
        'width': 264,
        'anchor': '.NB-taskbar-options',
        'placement': 'top right',
        'offset': {
            top: 12,
            left: -64
        },
        'overlay_bottom': true,
        'popover_class': 'NB-style-popover-container'
    },
    
    events: {
        "click .NB-font-family-option": "change_font_family",
        "click .NB-font-size-option": "change_font_size",
        "click .NB-line-spacing-option": "change_line_spacing",
        "click .NB-story-titles-pane-option": "change_story_titles_pane"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;
        this.render();
        this.show_correct_options();
    },
    
    close: function() {
        NEWSBLUR.reader.$s.$taskbar_options.removeClass('NB-active');
        NEWSBLUR.ReaderPopover.prototype.close.apply(this, arguments);
    },

    render: function() {
        var self = this;
        var feed = NEWSBLUR.assets.active_feed;
        
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        
        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Story Titles Pane'),
                $.make('ul', { className: 'segmented-control NB-options-story-titles-pane' }, [
                    $.make('li', { className: 'NB-story-titles-pane-option NB-options-story-titles-pane-north' }, [
                        $.make('div', { className: 'NB-icon' }),
                        'Top'
                    ]),
                    $.make('li', { className: 'NB-story-titles-pane-option NB-options-story-titles-pane-west' }, [
                        $.make('div', { className: 'NB-icon' }),
                        'Left'
                    ]),
                    $.make('li', { className: 'NB-story-titles-pane-option NB-options-story-titles-pane-south NB-active' }, [
                        $.make('div', { className: 'NB-icon' }),
                        'Bottom'
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Font Family'),
                $.make('ul', { className: 'segmented-control-vertical NB-options-font-family' }, [
                    $.make('li', { className: 'NB-font-family-option NB-options-font-family-sans-serif NB-active' }, 'Helvetica'),
                    $.make('li', { className: 'NB-font-family-option NB-options-font-family-serif' }, 'Palatino / Georgia'),
                    $.make('li', { className: 'NB-font-family-option NB-premium-only NB-options-font-family-gotham' }, 'Gotham Narrow'),
                    $.make('li', { className: 'NB-font-family-option NB-premium-only NB-options-font-family-sentinel' }, 'Sentinel'),
                    $.make('li', { className: 'NB-font-family-option NB-premium-only NB-options-font-family-whitney' }, 'Whitney'),
                    $.make('li', { className: 'NB-font-family-option NB-premium-only NB-options-font-family-chronicle' }, 'Chronicle')
                ])
            ]),
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Font Size'),
                $.make('ul', { className: 'segmented-control NB-options-font-size' }, [
                    $.make('li', { className: 'NB-font-size-option NB-options-font-size-xs' }, 'XS'),
                    $.make('li', { className: 'NB-font-size-option NB-options-font-size-s' }, 'S'),
                    $.make('li', { className: 'NB-font-size-option NB-options-font-size-m NB-active' }, 'M'),
                    $.make('li', { className: 'NB-font-size-option NB-options-font-size-l' }, 'L'),
                    $.make('li', { className: 'NB-font-size-option NB-options-font-size-xl' }, 'XL')
                ]),
                $.make('ul', { className: 'segmented-control NB-options-line-spacing' }, [
                    $.make('li', { className: 'NB-line-spacing-option NB-options-line-spacing-xs' }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-line-spacing-option NB-options-line-spacing-s' }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-line-spacing-option NB-options-line-spacing-m NB-active' }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-line-spacing-option NB-options-line-spacing-l' }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-line-spacing-option NB-options-line-spacing-xl' }, $.make('div', { className: 'NB-icon' }))
                ])
            ])
        ]));
        
        return this;
    },
    
    show_correct_options: function() {
        var font_family = NEWSBLUR.assets.preference('story_styling');
        var font_size = NEWSBLUR.assets.preference('story_size');
        var line_spacing = NEWSBLUR.assets.preference('story_line_spacing');
        var titles_layout_pane = NEWSBLUR.assets.preference('story_pane_anchor');
        
        this.$('.NB-font-family-option').removeClass('NB-active');
        this.$('.NB-options-font-family-'+font_family).addClass('NB-active');

        this.$('.NB-font-size-option').removeClass('NB-active');
        this.$('.NB-options-font-size-'+font_size).addClass('NB-active');
        this.$('.NB-line-spacing-option').removeClass('NB-active');
        this.$('.NB-options-line-spacing-'+line_spacing).addClass('NB-active');

        this.$('.NB-story-titles-pane-option').removeClass('NB-active');
        this.$('.NB-options-story-titles-pane-'+titles_layout_pane).addClass('NB-active');

        NEWSBLUR.reader.$s.$taskbar_options.addClass('NB-active');
        
        if (!NEWSBLUR.Globals.is_premium) {
            this.$(". NB-premium-only").addClass('NB-disabled').attr('disabled', 'disabled');
        }
    },

    
    // ==========
    // = Events =
    // ==========
    
    change_font_family: function(e) {
        var $target = $(e.target);
        
        if ($target.hasClass("NB-options-font-family-serif")) {
            this.update_font_family('serif');
        } else if ($target.hasClass("NB-options-font-family-sans-serif")) {
            this.update_font_family('sans-serif');
        } else if ($target.hasClass("NB-options-font-family-gotham")) {
            this.update_font_family('gotham');
        } else if ($target.hasClass("NB-options-font-family-sentinel")) {
            this.update_font_family('sentinel');
        } else if ($target.hasClass("NB-options-font-family-whitney")) {
            this.update_font_family('whitney');
        } else if ($target.hasClass("NB-options-font-family-chronicle")) {
            this.update_font_family('chronicle');
        }
        
        this.show_correct_options();
    },
    
    update_font_family: function(setting) {
        NEWSBLUR.assets.preference('story_styling', setting);
        NEWSBLUR.reader.apply_story_styling();
    },
    
    change_font_size: function(e) {
        var $target = $(e.target);
        
        if ($target.hasClass("NB-options-font-size-xs")) {
            this.update_font_size('xs');
        } else if ($target.hasClass("NB-options-font-size-s")) {
            this.update_font_size('s');
        } else if ($target.hasClass("NB-options-font-size-m")) {
            this.update_font_size('m');
        } else if ($target.hasClass("NB-options-font-size-l")) {
            this.update_font_size('l');
        } else if ($target.hasClass("NB-options-font-size-xl")) {
            this.update_font_size('xl');
        }
        
        this.show_correct_options();
    },
    
    update_font_size: function(setting) {
        NEWSBLUR.assets.preference('story_size', setting);
        NEWSBLUR.reader.apply_story_styling();
    },
    
    change_line_spacing: function(e) {
        var $target = $(e.currentTarget);
        
        if ($target.hasClass("NB-options-line-spacing-xs")) {
            this.update_line_spacing('xs');
        } else if ($target.hasClass("NB-options-line-spacing-s")) {
            this.update_line_spacing('s');
        } else if ($target.hasClass("NB-options-line-spacing-m")) {
            this.update_line_spacing('m');
        } else if ($target.hasClass("NB-options-line-spacing-l")) {
            this.update_line_spacing('l');
        } else if ($target.hasClass("NB-options-line-spacing-xl")) {
            this.update_line_spacing('xl');
        }
        
        this.show_correct_options();
    },
    
    update_line_spacing: function(setting) {
        NEWSBLUR.assets.preference('story_line_spacing', setting);
        NEWSBLUR.reader.apply_story_styling();
    },
    
    change_story_titles_pane: function(e) {
        var $target = $(e.currentTarget);
        
        if ($target.hasClass("NB-options-story-titles-pane-north")) {
            this.update_story_titles_pane('north');
        } else if ($target.hasClass("NB-options-story-titles-pane-west")) {
            this.update_story_titles_pane('west');
        } else if ($target.hasClass("NB-options-story-titles-pane-south")) {
            this.update_story_titles_pane('south');
        }
        
        this.show_correct_options();
    },
    
    update_story_titles_pane: function(setting) {
        var old_anchor = NEWSBLUR.assets.preference('story_pane_anchor');
        var pane_size = NEWSBLUR.assets.preference('story_titles_pane_size');
        
        if (setting == 'west' && _.contains(['north', 'south'], old_anchor)) {
            // Moving from top to side
            pane_size *= 2;
        } else if (_.contains(['north', 'south'], setting) && old_anchor == 'west') {
            // Moving from side to top
            pane_size /= 2;
        }
        NEWSBLUR.assets.preference('story_pane_anchor', setting);
        NEWSBLUR.assets.preference('story_titles_pane_size', pane_size);
        NEWSBLUR.reader.apply_resizable_layout(true);
    }
    
    
});