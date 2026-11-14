// media/js/newsblur/views/listen_settings_popover.js
//
// Voice settings for Listen, opened from the media player (media_player_view.js). It shares the
// look of the player settings (media_player_settings_popover.js): a title and description on the
// left of each row and a segmented control on the right.
//
// The voice picker is one fixed-height list. Recommended voices for the language
// (GET /listen/voices) come first, filtered here in the browser, then more voices from the whole
// ElevenLabs library (GET /listen/library) with the same filters, loaded as you scroll. Voices
// preview against the current story (POST /listen/preview). Voice and delivery changes restart the
// story from the paragraph being read.
NEWSBLUR.ListenSettingsPopover = NEWSBLUR.ReaderPopover.extend({

    // listen_settings_popover.js: NB-media-settings-popover brings the player settings' section,
    // title, description and segmented control styles (reader.css, darkmode.css).
    className: "NB-media-settings-popover NB-listen-settings-popover",

    options: {
        'width': 400,
        'anchor': '.NB-media-player-listen-voice-settings',
        'placement': 'top -right',
        'offset': {
            top: 8,
            left: 7
        },
        'overlay_top': true,
        'popover_class': 'NB-media-settings-popover-container NB-listen-settings-popover-container'
    },

    LIST_HEIGHT: 264,
    MIN_LIST_HEIGHT: 150,
    DELIVERY_ORDER: ['steady', 'natural', 'expressive'],
    DEFAULT_PRESETS: {
        steady: { stability: 0.75, similarity: 0.75, style: 0.0 },
        natural: { stability: 0.5, similarity: 0.75, style: 0.0 },
        expressive: { stability: 0.3, similarity: 0.75, style: 0.35 }
    },
    // listen_settings_popover.js: The speed slider moves over these stops (listen-spec.md "Speed
    // control", shared with iOS and Android): 0.05 apart from 0.5 to 0.8, 0.01 apart from 0.81 to
    // 1.2 and 0.05 apart from 1.25 to 3, so the band around 1x gets about half the track.
    SPEED_STOPS: (function () {
        var stops = [];
        var i;
        for (i = 0; i <= 6; i++) stops.push(Math.round((0.5 + i * 0.05) * 100) / 100);
        for (i = 1; i <= 40; i++) stops.push(Math.round((0.8 + i * 0.01) * 100) / 100);
        for (i = 1; i <= 36; i++) stops.push(Math.round((1.2 + i * 0.05) * 100) / 100);
        return stops;
    })(),
    SPEED_PRESETS: [0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3],
    MIN_SPEED: 0.5,
    MAX_SPEED: 3,
    SPEED_SAVE_DELAY: 400,
    // listen_settings_popover.js: One value per category, because the library API takes one each.
    FILTERS: ['gender', 'age', 'accent', 'descriptive'],
    TRAITS: ['gender', 'age', 'accent'],

    SVG_CHECK: '<svg viewBox="0 0 16 16"><path d="M6.2 11.6L2.6 8l1.1-1.1 2.5 2.5 6.1-6.1 1.1 1.1z"/></svg>',
    SVG_PLAY: '<svg viewBox="0 0 16 16"><path d="M5 3.2v9.6L12.6 8z"/></svg>',
    SVG_STOP: '<svg viewBox="0 0 16 16"><rect x="4" y="4" width="8" height="8" rx="1"/></svg>',
    SVG_CLEAR: '<svg viewBox="0 0 16 16"><path d="M11.5 5.6l-1.1-1.1L8 6.9 5.6 4.5 4.5 5.6 6.9 8l-2.4 2.4 1.1 1.1L8 9.1l2.4 2.4 1.1-1.1L9.1 8z"/></svg>',

    events: {
        "change .NB-listen-language-select": "change_language",
        "input .NB-listen-search": "change_search",
        "keydown input": "keep_keys_in_field",
        "keypress input": "keep_keys_in_field",
        "change .NB-listen-filter-select": "change_filter",
        "click .NB-listen-filter-clear": "clear_filter",
        "click .NB-listen-filters-reset": "clear_filters",
        "click .NB-listen-voice": "click_voice",
        "click .NB-listen-voice-preview": "click_voice_preview",
        "click .NB-listen-option": "change_option",
        "click .NB-listen-finetune-toggle": "toggle_finetune",
        "input .NB-listen-finetune-slider": "preview_finetune_slider",
        "change .NB-listen-finetune-slider": "save_finetune",
        "click .NB-listen-usage-upgrade": "open_upgrade",
        "input .NB-listen-speed-slider": "slide_speed",
        "focus .NB-listen-speed-input": "focus_speed_input",
        "keydown .NB-listen-speed-input": "keydown_speed_input",
        "keyup .NB-listen-speed-input": "keyup_speed_input",
        "blur .NB-listen-speed-input": "commit_speed_input"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.media_player = NEWSBLUR.app.media_player;
        this.manifest = this.media_player.listen_manifest;
        var engine = this.media_player.listen_engine();
        this.story_language = (this.manifest && this.manifest.language) || (engine && engine.language) || 'en';
        this.language = this.story_language;
        this.voices_data = null;
        this.voices_by_language = {};
        this.library = { voices: [], page: 0, has_more: false, loading: false, request_id: 0 };
        this.filters = {};
        this.search = '';
        this.finetune_open = false;
        this.list_height = this.LIST_HEIGHT;
        this.preview_audio = null;
        this.preview_voice_id = null;
        this.preview_loading = false;
        this.resume_after_preview = false;
        this.restart_debounced = _.debounce(_.bind(this.restart_playback, this), 500);
        this.speed = this.media_player.is_listen() ? this.media_player.playback_rate : this.media_player.listen_speed();
        this.save_speed_debounced = _.debounce(_.bind(this.save_speed, this), this.SPEED_SAVE_DELAY);
        this.pointer_down_at = 0;
        this.search_debounced = _.debounce(_.bind(function () {
            this.load_library({ reset: true });
        }, this), 350);

        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.listenTo(this.media_player, 'listen:manifest', function (manifest) {
            this.manifest = manifest;
            this.render_status();
        });
        this.listenTo(this.media_player, 'listen:usage', this.render_usage);
        this.listenTo(this.media_player, 'playback_rate_changed', function (rate) {
            this.speed = rate;
            this.render_options();
        });
        this.render();
        this.load_voices(this.language);
        this.load_library({ reset: true });
    },

    close: function (e, hide_callback) {
        if (e && e.type === 'click' && this.click_started_inside(e)) return false;
        this.stop_preview();
        return NEWSBLUR.ReaderPopover.prototype.close.call(this, e, hide_callback);
    },

    // listen_settings_popover.js: autohide (jquery.newsblur.js) closes the popover on a click whose
    // target isn't inside it. A control the click re-renders is detached by then, so a click that
    // started on the popover, or landed inside it, never counts as a click outside.
    click_started_inside: function (e) {
        if (!this.$popover) return false;
        if ($.contains(this.$popover[0], e.target)) return true;
        var recent = Date.now() - this.pointer_down_at < 1500;
        return recent && !$.contains(document.documentElement, e.target);
    },

    // =============
    // = Rendering =
    // =============

    render: function () {
        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.$el.html($.make('div', { className: 'NB-listen-settings' }, [
            this.make_section(gettext('Voice'), '', [
                $.make('div', { className: 'NB-listen-select NB-listen-language' }, [
                    $.make('select', { className: 'NB-listen-language-select', 'aria-label': gettext('Story language') })
                ])
            ], 'NB-listen-voice-section'),
            $.make('div', { className: 'NB-listen-voice-browser' }, [
                // listen_settings_popover.js: type "text", because jquery.hotkeys only stands down
                // for text inputs, and a search input would let s, m, y and space act on the story.
                $.make('input', {
                    type: 'text',
                    className: 'NB-listen-search',
                    placeholder: gettext('Search voices'),
                    'aria-label': gettext('Search voices')
                }),
                $.make('div', { className: 'NB-listen-filters' }),
                $.make('div', { className: 'NB-listen-voice-list', role: 'listbox' }),
                $.make('div', { className: 'NB-listen-status' })
            ]),
            this.make_section(gettext('Delivery'), gettext('How much emotion'), [
                this.make_control('delivery', _.map(this.DELIVERY_ORDER.concat(['custom']), function (preset) {
                    return [preset, this.delivery_label(preset)];
                }, this))
            ]),
            this.make_speed_section(),
            this.make_section(gettext('Auto-continue'), gettext('Play the next unread story'), [
                this.make_control('listen_auto_continue', [['true', gettext('On')], ['false', gettext('Off')]])
            ]),
            this.make_section(gettext('Follow along'), gettext('Highlight the paragraph being read'), [
                this.make_control('listen_highlight', [['true', gettext('On')], ['false', gettext('Off')]])
            ]),
            $.make('div', { className: 'NB-popover-section NB-listen-finetune-toggle', role: 'button' }, [
                $.make('div', { className: 'NB-popover-section-label' }, [
                    $.make('div', { className: 'NB-popover-section-title' }, gettext('Fine-tune voice')),
                    $.make('div', { className: 'NB-popover-section-description' }, gettext('Stability, similarity and style'))
                ]),
                $.make('div', { className: 'NB-popover-section-controls' }, [
                    $.make('div', { className: 'NB-listen-finetune-chevron' })
                ])
            ]),
            $.make('div', { className: 'NB-listen-finetune' }, [
                this.make_slider_section('stability', gettext('Stability'), gettext('Steadier or more varied')),
                this.make_slider_section('similarity', gettext('Similarity'), gettext('Closeness to the original voice')),
                this.make_slider_section('style', gettext('Style'), gettext('Exaggerates the voice\'s style')),
                this.make_section(gettext('Speaker boost'), gettext('A clearer, closer sound'), [
                    this.make_control('speaker_boost', [['true', gettext('On')], ['false', gettext('Off')]])
                ])
            ]),
            $.make('div', { className: 'NB-listen-usage' })
        ]));

        this.$('.NB-listen-voice-list').css('height', this.list_height)
            .on('scroll', _.bind(this.scroll_voice_list, this));
        this.$popover.on('mousedown', _.bind(function () {
            this.pointer_down_at = Date.now();
        }, this));
        this.render_language_select();
        this.render_filters();
        this.render_voice_list();
        this.render_options();
        this.render_finetune();
        this.render_usage();
        this.render_status();
        _.defer(_.bind(this.fit_list_height, this));
        return this;
    },

    make_section: function (title, description, controls, class_name) {
        return $.make('div', { className: 'NB-popover-section' + (class_name ? ' ' + class_name : '') }, [
            $.make('div', { className: 'NB-popover-section-label' }, [
                $.make('div', { className: 'NB-popover-section-title' }, title),
                $.make('div', { className: 'NB-popover-section-description' }, description)
            ]),
            $.make('div', { className: 'NB-popover-section-controls' }, controls)
        ]);
    },

    make_control: function (setting, options) {
        return $.make('ul', { className: 'segmented-control NB-listen-control', 'data-setting': setting },
            _.map(options, function (option) {
                return $.make('li', {
                    className: 'NB-listen-option',
                    'data-setting': setting,
                    'data-value': option[0],
                    role: 'button'
                }, option[1]);
            }));
    },

    make_slider_section: function (setting, title, description) {
        return this.make_section(title, description, [
            $.make('div', { className: 'NB-listen-slider' }, [
                $.make('input', {
                    type: 'range',
                    className: 'NB-listen-finetune-slider',
                    'data-setting': setting,
                    min: '0',
                    max: '1',
                    step: '0.05',
                    'aria-label': title
                }),
                $.make('div', { className: 'NB-listen-slider-value', 'data-setting': setting })
            ])
        ]);
    },

    // listen_settings_popover.js: The list keeps one height while you filter. It's only made
    // shorter once, at open, when the window has too little room above the player.
    fit_list_height: function () {
        var overflow = this.overflow_above();
        if (overflow > 0) {
            this.list_height = Math.max(this.MIN_LIST_HEIGHT, this.list_height - overflow);
            this.$('.NB-listen-voice-list').css('height', this.list_height);
        }
        // listen_settings_popover.js: When even the shortest list doesn't fit above a tall player
        // (a long Up Next), the popover's content scrolls instead of running off the top.
        this.contain_height();
    },

    // listen_settings_popover.js: Opening Fine-tune voice can make the popover taller than the
    // room above the player, so its content scrolls instead of running off the top.
    contain_height: function () {
        if (!this.$popover) return;
        var $content = this.$popover.find('.popover-content');
        $content.css({ 'max-height': '', 'overflow-y': '' });
        var overflow = this.overflow_above();
        if (overflow > 0) {
            $content.css({
                'max-height': Math.max(200, $content.height() - overflow),
                'overflow-y': 'auto'
            });
        }
    },

    // listen_settings_popover.js: The popover is pinned by its bottom edge above the player and
    // grows upward, so this is how far its top runs past the top of the window.
    overflow_above: function () {
        if (!this.$popover) return 0;
        return 8 - (this.$popover.offset().top - $(window).scrollTop());
    },

    delivery_label: function (preset) {
        return {
            steady: pgettext('listen delivery', 'Steady'),
            natural: pgettext('listen delivery', 'Natural'),
            expressive: pgettext('listen delivery', 'Expressive'),
            custom: pgettext('listen delivery', 'Custom')
        }[preset] || preset;
    },

    language_name: function (code) {
        var languages = (this.voices_data && this.voices_data.languages) || [];
        var language = _.find(languages, function (l) { return l.code === code; });
        return language ? language.name : code;
    },

    render_language_select: function () {
        var $select = this.$('.NB-listen-language-select');
        var languages = (this.voices_data && this.voices_data.languages) || [{ code: this.language, name: this.language }];
        $select.empty();
        _.each(languages, function (language) {
            $select.append($.make('option', { value: language.code }, _.escape(language.name)));
        });
        $select.val(this.language);
        this.$('.NB-listen-voice-section .NB-popover-section-description').text(
            interpolate(gettext('Reads your %(language)s stories'), { language: this.language_name(this.language) }, true));
    },

    filter_placeholder: function (filter) {
        return {
            gender: pgettext('voice filter', 'Gender'),
            age: pgettext('voice filter', 'Age'),
            accent: pgettext('voice filter', 'Accent'),
            descriptive: pgettext('voice filter', 'Style')
        }[filter];
    },

    // listen_settings_popover.js: Options come localized from /listen/voices, except accents, which
    // are raw ElevenLabs strings per language, shown title-cased and sent as they are.
    filter_options: function (filter) {
        var filters = (this.voices_data && this.voices_data.filters) || {};
        if (filter === 'accent') {
            return _.map((filters.accent && filters.accent[this.language]) || [], function (accent) {
                return { value: accent, label: this.title_case(accent) };
            }, this);
        }
        return filters[filter] || [];
    },

    filter_label: function (filter, value) {
        if (!value) return null;
        var option = _.find(this.filter_options(filter), function (o) { return o.value === value; });
        return (option && option.label) || this.title_case(value);
    },

    title_case: function (value) {
        return String(value).replace(/_/g, ' ').replace(/\b([a-z])/g, function (letter) {
            return letter.toUpperCase();
        });
    },

    render_filters: function () {
        var $filters = this.$('.NB-listen-filters');
        $filters.empty();
        _.each(this.FILTERS, function (filter) {
            var value = this.filters[filter] || '';
            var $select = $.make('select', {
                className: 'NB-listen-filter-select',
                'data-filter': filter,
                'aria-label': this.filter_placeholder(filter)
            }, [
                $.make('option', { value: '' }, this.filter_placeholder(filter))
            ]);
            _.each(this.filter_options(filter), function (option) {
                $select.append($.make('option', { value: option.value }, _.escape(option.label || this.title_case(option.value))));
            }, this);
            $select.val(value);
            $filters.append($.make('div', {
                className: 'NB-listen-select NB-listen-filter' + (value ? ' NB-active' : ''),
                'data-filter': filter
            }, [
                $select,
                value && $.make('div', {
                    className: 'NB-listen-filter-clear',
                    'data-filter': filter,
                    role: 'button',
                    title: gettext('Clear')
                }, this.SVG_CLEAR)
            ]));
        }, this);
    },

    has_filters: function () {
        return !_.isEmpty(this.filters) || !!this.search;
    },

    matches_filters: function (voice) {
        var filters = this.filters;
        var matches = _.all(filters, function (value, filter) { return voice[filter] === value; });
        if (!matches || !this.search) return matches;
        var haystack = _.compact([voice.name, voice.description, voice.accent, voice.descriptive,
            voice.use_case]).join(' ').toLowerCase();
        return haystack.indexOf(this.search.toLowerCase()) !== -1;
    },

    selected_voice_id: function (language) {
        language = language || this.language;
        var saved = this.media_player.listen_selected_voice(language);
        if (saved) return saved;
        var data = this.voices_data;
        if (data && data.selected && data.selected[language]) return data.selected[language];
        if (data && data.defaults && data.defaults[language]) return data.defaults[language];
        return null;
    },

    recommended_voices: function () {
        var voices = (this.voices_by_language[this.language] || []).slice();
        var selected_id = this.selected_voice_id();
        var cached = NEWSBLUR.ListenSettingsPopover.voice_cache[selected_id];
        if (selected_id && cached && cached.language === this.language &&
            !_.any(voices, function (v) { return v.voice_id === selected_id; })) {
            // listen_settings_popover.js: A voice picked from the library stays at the top.
            voices.unshift(cached);
        }
        return voices;
    },

    render_voice_list: function () {
        var $list = this.$('.NB-listen-voice-list');
        var scroll_top = $list.scrollTop();
        var all_recommended = this.recommended_voices();
        var recommended = _.filter(all_recommended, this.matches_filters, this);
        var recommended_ids = _.pluck(all_recommended, 'voice_id');
        var more = _.reject(this.library.voices, function (voice) {
            return _.contains(recommended_ids, voice.voice_id);
        });
        var curated_loaded = !!this.voices_by_language[this.language];
        var selected_voice_id = this.selected_voice_id();

        $list.empty();
        if (!recommended.length && !more.length) {
            if (!curated_loaded || this.library.loading) {
                $list.append(this.make_loading_row());
            } else {
                $list.append($.make('div', { className: 'NB-listen-voice-empty' }, [
                    $.make('div', gettext('No voices match these filters')),
                    this.has_filters() && $.make('div', { className: 'NB-listen-filters-reset', role: 'button' }, gettext('Clear filters'))
                ]));
            }
            return;
        }

        if (recommended.length) {
            var title = interpolate(gettext('Recommended for %(language)s'), { language: this.language_name(this.language) }, true);
            $list.append(this.make_list_header(title, this.has_filters() ?
                interpolate(ngettext('%(count)s match', '%(count)s matches', recommended.length), { count: recommended.length }, true) : ''));
            _.each(recommended, function (voice) {
                $list.append(this.make_voice_row(voice, voice.voice_id === selected_voice_id));
            }, this);
        }
        if (more.length || this.library.loading) {
            $list.append(this.make_list_header(gettext('More voices'), ''));
            _.each(more, function (voice) {
                $list.append(this.make_voice_row(voice, voice.voice_id === selected_voice_id));
            }, this);
            if (this.library.loading) $list.append(this.make_loading_row());
        }
        $list.scrollTop(scroll_top);
    },

    make_list_header: function (title, count) {
        return $.make('div', { className: 'NB-listen-voice-header' }, [
            $.make('span', _.escape(title)),
            count && $.make('span', { className: 'NB-listen-voice-header-count' }, _.escape(count))
        ]);
    },

    make_loading_row: function () {
        return $.make('div', { className: 'NB-listen-voice-loading' }, [
            $.make('div', { className: 'NB-listen-spinner' }),
            gettext('Loading voices...')
        ]);
    },

    make_voice_row: function (voice, is_selected) {
        NEWSBLUR.ListenSettingsPopover.voice_cache[voice.voice_id] = voice;
        var traits = _.compact(_.map(this.TRAITS, function (trait) {
            return this.filter_label(trait, voice[trait]);
        }, this)).join(' · ');
        // listen_settings_popover.js: $.make inserts text as HTML, and library voice names and
        // descriptions are written by ElevenLabs users, so everything here is escaped.
        return $.make('div', {
            className: 'NB-listen-voice' + (is_selected ? ' NB-selected' : ''),
            'data-voice-id': voice.voice_id,
            role: 'option',
            'aria-selected': is_selected ? 'true' : 'false'
        }, [
            $.make('div', { className: 'NB-listen-voice-check' }, is_selected ? this.SVG_CHECK : ''),
            $.make('div', { className: 'NB-listen-voice-text' }, [
                $.make('div', { className: 'NB-listen-voice-title' }, [
                    $.make('span', { className: 'NB-listen-voice-name' }, _.escape(voice.name)),
                    voice.description && $.make('span', { className: 'NB-listen-voice-description' }, _.escape(voice.description))
                ]),
                traits && $.make('div', { className: 'NB-listen-voice-traits' }, _.escape(traits))
            ]),
            this.make_preview_button(voice.voice_id)
        ]);
    },

    make_preview_button: function (voice_id) {
        var state = this.preview_state(voice_id);
        return $.make('div', {
            className: 'NB-listen-voice-preview' + (state ? ' NB-' + state : ''),
            title: state ? gettext('Stop preview') : gettext('Preview this voice'),
            role: 'button'
        }, state === 'loading' ? '<div class="NB-listen-spinner"></div>' :
            (state === 'playing' ? this.SVG_STOP : this.SVG_PLAY));
    },

    preview_state: function (voice_id) {
        if (this.preview_voice_id !== voice_id) return null;
        return this.preview_loading ? 'loading' : 'playing';
    },

    render_preview_state: function () {
        var self = this;
        this.$('.NB-listen-voice').each(function () {
            var $voice = $(this);
            $voice.find('.NB-listen-voice-preview').replaceWith(self.make_preview_button($voice.attr('data-voice-id')));
        });
    },

    // listen_settings_popover.js: Controls are updated in place, never rebuilt, so the option being
    // clicked stays in the document (see click_started_inside).
    render_options: function () {
        var delivery = NEWSBLUR.assets.preference('listen_delivery') || 'natural';
        this.$('.NB-listen-option[data-setting="delivery"][data-value="custom"]').toggle(delivery === 'custom');

        this.set_active('delivery', delivery);
        this.render_speed();
        this.set_active('listen_auto_continue', String(this.media_player.listen_pref_enabled('listen_auto_continue')));
        this.set_active('listen_highlight', String(this.media_player.listen_pref_enabled('listen_highlight')));
        this.set_active('speaker_boost', String(this.delivery_values().speaker_boost));
    },

    set_active: function (setting, value) {
        var $control = this.$('.NB-listen-control[data-setting="' + setting + '"]');
        $control.find('.NB-listen-option').removeClass('NB-active');
        if (value !== null) $control.find('[data-value="' + value + '"]').addClass('NB-active');
    },

    render_finetune: function (options) {
        this.$('.NB-listen-finetune-toggle').toggleClass('NB-open', this.finetune_open);
        this.$('.NB-listen-finetune').toggle(this.finetune_open);
        if (options && options.contain) this.contain_height();
        var values = this.delivery_values();
        _.each(['stability', 'similarity', 'style'], function (setting) {
            this.$('.NB-listen-finetune-slider[data-setting="' + setting + '"]').val(values[setting]);
            this.$('.NB-listen-slider-value[data-setting="' + setting + '"]').text(this.format_percent(values[setting]));
        }, this);
    },

    // listen_settings_popover.js: Presets show their own values on the sliders, so moving a slider
    // starts from what you were hearing.
    delivery_values: function () {
        var delivery = NEWSBLUR.assets.preference('listen_delivery') || 'natural';
        var speaker_boost = NEWSBLUR.assets.preference('listen_speaker_boost');
        speaker_boost = !(speaker_boost === false || speaker_boost === 'false');
        if (delivery === 'custom') {
            return {
                stability: this.pref_number('listen_stability', 0.5),
                similarity: this.pref_number('listen_similarity', 0.75),
                style: this.pref_number('listen_style', 0.0),
                speaker_boost: speaker_boost
            };
        }
        var presets = (this.voices_data && this.voices_data.delivery_presets) || [];
        var preset = _.find(presets, function (p) { return p.id === delivery; }) ||
            this.DEFAULT_PRESETS[delivery] || this.DEFAULT_PRESETS.natural;
        return {
            stability: preset.stability,
            similarity: preset.similarity,
            style: preset.style,
            speaker_boost: speaker_boost
        };
    },

    pref_number: function (preference, fallback) {
        var value = parseFloat(NEWSBLUR.assets.preference(preference));
        return isNaN(value) ? fallback : value;
    },

    format_percent: function (value) {
        return Math.round(parseFloat(value) * 100) + '%';
    },

    // listen_settings_popover.js: "9 hours 58 minutes", "45 minutes" or "1 hour". A zero part is
    // dropped, except that nothing left still reads "0 minutes".
    format_allowance: function (seconds) {
        var total_minutes = Math.floor(Math.max(0, seconds) / 60);
        var hours = Math.floor(total_minutes / 60);
        var minutes = total_minutes % 60;
        var pieces = [];
        if (hours > 0) {
            pieces.push(interpolate(ngettext('%(count)s hour', '%(count)s hours', hours), { count: hours }, true));
        }
        if (minutes > 0 || !pieces.length) {
            pieces.push(interpolate(ngettext('%(count)s minute', '%(count)s minutes', minutes), { count: minutes }, true));
        }
        return pieces.join(' ');
    },

    render_usage: function () {
        var usage = this.media_player.listen_usage || (this.voices_data && this.voices_data.usage);
        var $usage = this.$('.NB-listen-usage');
        $usage.empty();
        if (!usage) return;

        var parts = [];
        if (usage.is_archive_tier) {
            if (_.isNumber(usage.seconds_remaining)) {
                parts.push(interpolate(gettext('%(duration)s left this week'), {
                    duration: this.format_allowance(usage.seconds_remaining)
                }, true));
                // listen_settings_popover.js: The allowance comes back on Sunday (apps/listen/usage.py
                // sends resets_at), so the footer names the weekday rather than a date.
                var resets = usage.resets_at && new Date(usage.resets_at);
                if (resets && !isNaN(resets.getTime())) {
                    parts.push(interpolate(gettext('Resets %(day)s'), {
                        day: resets.toLocaleDateString(undefined, { weekday: 'long' })
                    }, true));
                }
            }
        } else {
            if (_.isNumber(usage.samples_limit)) {
                var samples_left = Math.max(0, usage.samples_limit - (usage.samples_used || 0));
                parts.push(interpolate(ngettext('%(count)s free story preview left today',
                    '%(count)s free story previews left today', samples_left), { count: samples_left }, true));
            }
            if (_.isNumber(usage.previews_limit)) {
                var previews_left = Math.max(0, usage.previews_limit - (usage.previews_used || 0));
                parts.push(interpolate(ngettext('%(count)s voice preview left',
                    '%(count)s voice previews left', previews_left), { count: previews_left }, true));
            }
        }
        if (!parts.length) return;
        $usage.append($.make('span', _.escape(parts.join(' · '))));
        if (!usage.is_archive_tier) {
            $usage.append($.make('span', { className: 'NB-listen-usage-upgrade', role: 'button' }, gettext('Upgrade')));
        }
    },

    // listen_settings_popover.js: One quiet line under the list for errors, or for a chosen voice
    // that couldn't be used for the story playing now.
    render_status: function (message) {
        var manifest = this.manifest;
        if (!message && manifest && manifest.voice_fallback && manifest.voice && this.language === manifest.language) {
            message = interpolate(gettext("Your chosen voice isn't available right now, so %(voice)s is reading this story."), {
                voice: manifest.voice.name
            }, true);
        }
        this.$('.NB-listen-status').text(message || '').toggle(!!message);
    },

    // ===========
    // = Loading =
    // ===========

    load_voices: function (language) {
        NEWSBLUR.assets.listen_voices(language, _.bind(function (data) {
            if (!this._open) return;
            this.voices_data = data;
            if (data.usage) this.media_player.listen_usage = data.usage;
            _.each(data.voices || {}, function (voices, code) {
                this.voices_by_language[code] = voices;
            }, this);
            if (!this.voices_by_language[language]) this.voices_by_language[language] = [];
            this.render_language_select();
            this.render_filters();
            this.render_voice_list();
            this.render_options();
            this.render_finetune();
            this.render_usage();
        }, this), _.bind(function (response, data, text_status) {
            if (!this._open) return;
            this.voices_by_language[language] = this.voices_by_language[language] || [];
            this.render_voice_list();
            this.render_status(NEWSBLUR.ListenEngine.normalize_error(response, text_status).message);
        }, this));
    },

    load_library: function (options) {
        options = options || {};
        if (options.reset) {
            this.library.voices = [];
            this.library.page = 0;
            this.library.has_more = false;
        } else if (!this.library.has_more || this.library.loading) {
            return;
        } else {
            this.library.page += 1;
        }
        var request_id = ++this.library.request_id;
        this.library.loading = true;
        if (options.reset) this.render_voice_list();

        var params = { language: this.language, page: this.library.page };
        _.each(this.filters, function (value, filter) {
            if (value) params[filter] = value;
        });
        if (this.search) params.search = this.search;
        NEWSBLUR.assets.listen_library(params, _.bind(function (data) {
            if (!this._open || request_id !== this.library.request_id) return;
            this.library.loading = false;
            this.library.voices = this.library.voices.concat(data.voices || []);
            this.library.has_more = !!data.has_more;
            this.render_voice_list();
        }, this), _.bind(function (response, data, text_status) {
            if (!this._open || request_id !== this.library.request_id) return;
            this.library.loading = false;
            this.render_voice_list();
            this.render_status(NEWSBLUR.ListenEngine.normalize_error(response, text_status).message);
        }, this));
    },

    // listen_settings_popover.js: Loads the next page of library voices near the bottom of the list.
    scroll_voice_list: function () {
        var list = this.$('.NB-listen-voice-list')[0];
        if (list && list.scrollTop + list.clientHeight >= list.scrollHeight - 80) {
            this.load_library();
        }
    },

    // listen_settings_popover.js: Filters and search apply to both sections, and the list returns
    // to the top so the first matches are in view.
    apply_filters: function () {
        this.render_filters();
        this.render_status(null);
        this.$('.NB-listen-voice-list').scrollTop(0);
        this.load_library({ reset: true });
    },

    // ==========
    // = Events =
    // ==========

    change_language: function (e) {
        this.language = $(e.currentTarget).val();
        // listen_settings_popover.js: Accents differ by language; the other filters carry over.
        delete this.filters.accent;
        this.stop_preview();
        this.render_language_select();
        if (!this.voices_by_language[this.language]) this.load_voices(this.language);
        this.apply_filters();
    },

    // listen_settings_popover.js: Keys typed into the popover's fields never reach the reader's
    // shortcuts. Escape still goes through, so it can close the popover.
    keep_keys_in_field: function (e) {
        if (e.which === 27) return;
        e.stopPropagation();
    },

    change_search: function (e) {
        this.search = $.trim($(e.currentTarget).val());
        this.render_voice_list();
        this.search_debounced();
    },

    change_filter: function (e) {
        var $select = $(e.currentTarget);
        var value = $select.val();
        if (value) {
            this.filters[$select.attr('data-filter')] = value;
        } else {
            delete this.filters[$select.attr('data-filter')];
        }
        this.apply_filters();
    },

    clear_filter: function (e) {
        e.preventDefault();
        e.stopPropagation();
        delete this.filters[$(e.currentTarget).attr('data-filter')];
        this.apply_filters();
    },

    clear_filters: function (e) {
        if (e) {
            e.preventDefault();
            e.stopPropagation();
        }
        this.filters = {};
        this.search = '';
        this.$('.NB-listen-search').val('');
        this.apply_filters();
    },

    click_voice: function (e) {
        if ($(e.target).closest('.NB-listen-voice-preview').length) return;
        var voice_id = $(e.currentTarget).attr('data-voice-id');
        if (!voice_id || voice_id === this.selected_voice_id()) return;
        var language = this.language;
        var voices = {};
        try {
            voices = JSON.parse(NEWSBLUR.assets.preference('listen_voices') || '{}') || {};
        } catch (err) {
            voices = {};
        }
        voices[language] = voice_id;
        var check = this.SVG_CHECK;
        this.$('.NB-listen-voice').each(function () {
            var is_selected = $(this).attr('data-voice-id') === voice_id;
            $(this).toggleClass('NB-selected', is_selected).attr('aria-selected', is_selected ? 'true' : 'false')
                .find('.NB-listen-voice-check').html(is_selected ? check : '');
        });

        NEWSBLUR.assets.preference('listen_voices', JSON.stringify(voices), _.bind(function () {
            if (this.media_player.is_listen() && language === this.story_language) {
                this.media_player.listen_restart({ voice_id: voice_id });
            }
        }, this));
    },

    click_voice_preview: function (e) {
        e.preventDefault();
        e.stopPropagation();
        var voice_id = $(e.currentTarget).closest('.NB-listen-voice').attr('data-voice-id');
        var voice = NEWSBLUR.ListenSettingsPopover.voice_cache[voice_id];
        if (!voice) return;
        if (this.preview_voice_id === voice_id) {
            this.stop_preview();
            return;
        }
        this.preview_voice(voice);
    },

    change_option: function (e) {
        var $option = $(e.currentTarget);
        var setting = $option.attr('data-setting');
        var value = $option.attr('data-value');

        if (setting === 'delivery') {
            if (value === 'custom' || value === NEWSBLUR.assets.preference('listen_delivery')) return;
            NEWSBLUR.assets.save_preferences({ listen_delivery: value }, _.bind(function () {
                this.restart_debounced();
            }, this));
            this.render_finetune();
        } else if (setting === 'speed') {
            this.set_speed(parseFloat(value));
            return;
        } else if (setting === 'speaker_boost') {
            this.save_finetune({ speaker_boost: value === 'true' });
            return;
        } else {
            NEWSBLUR.assets.preference(setting, value === 'true');
            if (setting === 'listen_highlight') {
                NEWSBLUR.ListenFollowAlong.apply({ scroll: value === 'true' });
            }
        }
        this.render_options();
    },

    // =========
    // = Speed =
    // =========

    // listen_settings_popover.js: An exact value field on the title row, a slider over SPEED_STOPS
    // with a mark at 1x, and presets, all kept in step.
    make_speed_section: function () {
        var one_index = this.nearest_stop_index(1);
        var one_position = one_index / (this.SPEED_STOPS.length - 1);
        return $.make('div', { className: 'NB-popover-section NB-listen-speed-section' }, [
            $.make('div', { className: 'NB-listen-speed-header' }, [
                $.make('div', { className: 'NB-popover-section-label' }, [
                    $.make('div', { className: 'NB-popover-section-title' }, gettext('Speed')),
                    $.make('div', { className: 'NB-popover-section-description' }, gettext('Playback speed'))
                ]),
                $.make('label', { className: 'NB-listen-speed-field' }, [
                    $.make('input', {
                        type: 'text',
                        inputmode: 'decimal',
                        className: 'NB-listen-speed-input',
                        'aria-label': gettext('Playback speed'),
                        spellcheck: 'false',
                        autocomplete: 'off'
                    }),
                    $.make('span', { className: 'NB-listen-speed-unit' }, '×')
                ])
            ]),
            $.make('div', { className: 'NB-listen-speed-track' }, [
                $.make('input', {
                    type: 'range',
                    className: 'NB-listen-speed-slider',
                    min: '0',
                    max: String(this.SPEED_STOPS.length - 1),
                    step: '1',
                    'aria-label': gettext('Playback speed')
                }),
                $.make('div', {
                    className: 'NB-listen-speed-one',
                    style: '--NB-listen-speed-one: ' + one_position
                }, '1×')
            ]),
            this.make_control('speed', _.map(this.SPEED_PRESETS, function (speed) {
                return [String(speed), this.format_speed_value(speed)];
            }, this))
        ]);
    },

    clamp_speed: function (speed) {
        speed = Math.max(this.MIN_SPEED, Math.min(this.MAX_SPEED, speed));
        return Math.round(speed * 100) / 100;
    },

    format_speed_value: function (speed) {
        return String(Math.round(speed * 100) / 100);
    },

    nearest_stop_index: function (speed) {
        var best = 0;
        _.each(this.SPEED_STOPS, function (stop, index) {
            if (Math.abs(stop - speed) < Math.abs(this.SPEED_STOPS[best] - speed)) best = index;
        }, this);
        return best;
    },

    // listen_settings_popover.js: A typed value that isn't a stop keeps its exact value; only the
    // slider thumb rounds to the nearest stop. Presets light up on an exact match.
    render_speed: function (options) {
        options = options || {};
        var speed = this.speed;
        var $input = this.$('.NB-listen-speed-input');
        if (!$input.is(':focus') || options.force_field) {
            $input.val(this.format_speed_value(speed));
        }
        if (!options.skip_slider) {
            this.$('.NB-listen-speed-slider').val(this.nearest_stop_index(speed));
        }
        var preset = _.find(this.SPEED_PRESETS, function (p) { return Math.abs(p - speed) < 0.001; });
        this.set_active('speed', preset ? String(preset) : null);
    },

    // listen_settings_popover.js: Applies right away to the audio playing (pitch is kept by
    // listen_engine.js) and saves listen_speed once the value settles.
    set_speed: function (speed, options) {
        if (isNaN(speed)) return;
        this.speed = this.clamp_speed(speed);
        if (this.media_player.is_listen()) {
            this.media_player.set_playback_rate(this.speed, { save: false });
        }
        this.render_speed(options);
        this.save_speed_debounced();
    },

    save_speed: function () {
        if (this.media_player.is_listen()) {
            this.media_player.set_playback_rate(this.speed);
        } else {
            NEWSBLUR.assets.preference('listen_speed', this.format_speed_value(this.speed));
        }
    },

    slide_speed: function (e) {
        var index = parseInt($(e.currentTarget).val(), 10);
        this.set_speed(this.SPEED_STOPS[index], { skip_slider: true, force_field: true });
    },

    focus_speed_input: function (e) {
        var input = e.currentTarget;
        _.defer(function () { input.select(); });
    },

    keydown_speed_input: function (e) {
        if (e.which === 13) {
            e.preventDefault();
            this.commit_speed_input(e);
            $(e.currentTarget).blur();
        } else if (e.which === 27) {
            // listen_settings_popover.js: Escape reverts the field instead of closing the popover.
            e.preventDefault();
            e.stopPropagation();
            this.render_speed({ force_field: true });
        }
    },

    // listen_settings_popover.js: autohide (jquery.newsblur.js) closes on the Escape keyup, so the
    // field keeps it, and only lets go of focus once the key is released.
    keyup_speed_input: function (e) {
        if (e.which !== 27) return;
        e.stopPropagation();
        $(e.currentTarget).blur();
    },

    // listen_settings_popover.js: Enter or leaving the field commits it. Out of range values clamp,
    // anything that isn't a number reverts.
    commit_speed_input: function (e) {
        var text = $.trim($(e.currentTarget).val()).replace(/[×xX]$/, '').replace(',', '.');
        var speed = parseFloat(text);
        if (!text || isNaN(speed) || !/^\d*\.?\d*$/.test(text)) {
            this.render_speed({ force_field: true });
            return;
        }
        this.set_speed(speed, { force_field: true });
    },

    toggle_finetune: function () {
        this.finetune_open = !this.finetune_open;
        this.render_finetune({ contain: true });
    },

    preview_finetune_slider: function (e) {
        var $slider = $(e.currentTarget);
        this.$('.NB-listen-slider-value[data-setting="' + $slider.attr('data-setting') + '"]')
            .text(this.format_percent($slider.val()));
    },

    // listen_settings_popover.js: Any fine-tune change makes the delivery custom.
    save_finetune: function (overrides) {
        var values = this.delivery_values();
        var slider = _.bind(function (setting) {
            return parseFloat(this.$('.NB-listen-finetune-slider[data-setting="' + setting + '"]').val());
        }, this);
        var speaker_boost = overrides && _.has(overrides, 'speaker_boost') ? overrides.speaker_boost : values.speaker_boost;
        NEWSBLUR.assets.save_preferences({
            listen_delivery: 'custom',
            listen_stability: slider('stability'),
            listen_similarity: slider('similarity'),
            listen_style: slider('style'),
            listen_speaker_boost: speaker_boost
        }, _.bind(function () {
            this.restart_debounced();
        }, this));
        this.render_options();
        this.render_finetune();
    },

    open_upgrade: function () {
        this.close();
        NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: 'listen' });
    },

    restart_playback: function () {
        if (this.media_player.is_listen()) {
            this.media_player.listen_restart();
        }
    },

    // ==================
    // = Voice Previews =
    // ==================

    preview_params: function (voice) {
        var params = {
            voice_id: voice.voice_id,
            language: this.language,
            delivery: NEWSBLUR.assets.preference('listen_delivery') || 'natural'
        };
        if (params.delivery === 'custom') {
            var values = this.delivery_values();
            params.stability = values.stability;
            params.similarity = values.similarity;
            params.style = values.style;
            params.speaker_boost = values.speaker_boost;
        }
        // listen_settings_popover.js: Previews read the start of the current story when its
        // language is the one being configured, otherwise a sample sentence.
        if (this.media_player.is_listen() && this.language === this.story_language) {
            params.story_hash = this.media_player.current_media.story_hash;
        }
        return params;
    },

    preview_voice: function (voice) {
        // listen_settings_popover.js: Switching from one preview to another keeps the story
        // paused; it resumes once the last preview stops.
        this.stop_preview({ resume: false });
        this.render_status(null);
        this.preview_voice_id = voice.voice_id;
        this.preview_loading = true;
        this.render_preview_state();
        var params = this.preview_params(voice);

        if (!params.story_hash && !this.media_player.is_listen() && voice.preview_url) {
            this.play_preview_url(voice.preview_url, voice.voice_id);
            return;
        }

        NEWSBLUR.assets.listen_voice_preview(params, _.bind(function (data) {
            if (!this._open || this.preview_voice_id !== voice.voice_id) return;
            if (data.usage) {
                this.media_player.listen_usage = data.usage;
                this.render_usage();
            }
            this.play_preview_url(data.url, voice.voice_id);
        }, this), _.bind(function (response, data, text_status) {
            if (!this._open || this.preview_voice_id !== voice.voice_id) return;
            var error = NEWSBLUR.ListenEngine.normalize_error(response, text_status);
            if (error.usage) {
                this.media_player.listen_usage = error.usage;
                this.render_usage();
            }
            this.render_status(error.message);
            if (voice.preview_url) {
                this.play_preview_url(voice.preview_url, voice.voice_id);
            } else {
                this.preview_voice_id = null;
                this.preview_loading = false;
                this.render_preview_state();
            }
        }, this));
    },

    play_preview_url: function (url, voice_id) {
        var mp = this.media_player;
        if (mp.is_playing) {
            this.resume_after_preview = true;
            mp.pause();
        }
        var audio = new Audio(url);
        this.preview_audio = audio;
        var finished = _.bind(function () {
            if (this.preview_audio !== audio) return;
            this.stop_preview();
        }, this);
        audio.addEventListener('playing', _.bind(function () {
            if (this.preview_audio !== audio) return;
            this.preview_loading = false;
            this.render_preview_state();
        }, this));
        audio.addEventListener('ended', finished);
        audio.addEventListener('error', finished);
        var promise = audio.play();
        if (promise && promise.catch) promise.catch(finished);
        this.preview_voice_id = voice_id;
    },

    stop_preview: function (options) {
        options = options || {};
        if (this.preview_audio) {
            try {
                this.preview_audio.pause();
            } catch (e) { }
            this.preview_audio = null;
        }
        this.preview_voice_id = null;
        this.preview_loading = false;
        this.render_preview_state();
        if (this.resume_after_preview && options.resume !== false) {
            this.resume_after_preview = false;
            this.media_player.play();
        }
    }

}, {

    // listen_settings_popover.js: Voice objects seen in any list, so a library voice that was picked
    // can still be shown by name after the popover is reopened.
    voice_cache: {}

});
