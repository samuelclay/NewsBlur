// reader_language.js: The one-time language chooser. When the interface was switched into a detected
// language, it shows that language beside English as parallel text, so someone who can't read the
// detected language can still switch back in one click. Everyone else gets a grid of every language.
// Hosted by NEWSBLUR.ReaderLanguage (a standalone modal after the feed list loads) and by the first
// page of the intro (reader_intro.js). Showing it in either place marks it seen.
NEWSBLUR.LanguageChooser = function (options) {
    this.options = _.extend({
        // Called when the current language stays, so the host can close or advance.
        on_keep: function () { },
        // Called after the chooser changes height so the host modal can re-measure.
        on_resize: function () { },
        // Extra preferences saved alongside a new language, e.g. where the intro resumes after reload.
        preferences: {}
    }, options);

    this.language = NEWSBLUR.LanguageChooser.ui_language();
    this.selected = this.language;
    this.$el = $.make('div', { className: 'NB-language-chooser' });
    this.$el.on('click', '.NB-language-keep', _.bind(this.keep, this));
    this.$el.on('click', '.NB-language-use-english', _.bind(this.choose, this, 'en'));
    this.$el.on('click', '.NB-language-more', _.bind(this.show_grid, this));
    this.$el.on('click', '.NB-language-back', _.bind(this.show_bilingual, this));
    this.$el.on('change', 'input[name=language_choice]', _.bind(this.select_option, this));
    this.$el.on('click', '.NB-language-use-selected', _.bind(function () {
        this.choose(this.selected);
    }, this));
    this.$el.on('keydown', _.bind(this.handle_keydown, this));

    if (this.language == 'en') {
        this.render_grid({ from_bilingual: false });
    } else {
        this.render_bilingual();
    }
};

_.extend(NEWSBLUR.LanguageChooser, {

    RTL_LANGUAGES: ['ar', 'he'],

    // The resolved interface language that gettext is rendering, set on <html> by base.html.
    ui_language: function () {
        var code = document.documentElement.getAttribute('lang') || 'en';
        return _.find(NEWSBLUR.languages, function (language) { return language[0] == code; }) ? code : 'en';
    },

    native_name: function (code) {
        var language = _.find(NEWSBLUR.languages, function (language) { return language[0] == code; });
        return language ? language[1] : code;
    },

    // English display names come from the browser, not the catalog. Older browsers fall back to the
    // native name, which still identifies the language.
    english_name: function (code) {
        try {
            return new Intl.DisplayNames(['en'], { type: 'language' }).of(code) || this.native_name(code);
        } catch (e) {
            return this.native_name(code);
        }
    },

    direction: function (code) {
        return _.contains(this.RTL_LANGUAGES, code) ? 'rtl' : 'ltr';
    },

    is_seen: function () {
        return !!NEWSBLUR.assets.preference('language_dialog_seen');
    },

    mark_seen: function () {
        NEWSBLUR.assets.preference('language_dialog_seen', true);
    },

    // The chooser is only offered while the account follows the detected language. Someone who
    // already picked a language explicitly is marked seen silently and never asked.
    should_offer: function () {
        if (!NEWSBLUR.Globals.is_authenticated || this.is_seen()) return false;
        if (NEWSBLUR.language_preference && NEWSBLUR.language_preference != 'auto') {
            this.mark_seen();
            return false;
        }
        return true;
    },

    // Reload without the ?test=language knob so the reloaded page shows the applied language
    // instead of forcing the dialog open again.
    reload: function () {
        var url = new URL(window.location.href);
        _.each(['test', 'next'], function (param) {
            if (/^language/.test(url.searchParams.get(param) || '')) {
                url.searchParams.delete(param);
            }
        });
        if (url.href == window.location.href) {
            window.location.reload();
        } else {
            window.location.replace(url.href);
        }
    }

});

_.extend(NEWSBLUR.LanguageChooser.prototype, {

    // =============
    // = Bilingual =
    // =============

    render_bilingual: function () {
        var language = this.language;
        var native_name = NEWSBLUR.LanguageChooser.native_name(language);
        var english_native_name = NEWSBLUR.LanguageChooser.native_name('en');

        this.mode = 'bilingual';
        this.$el.attr('class', 'NB-language-chooser NB-language-mode-bilingual').empty().append(
            $.make('div', { className: 'NB-language-columns', dir: NEWSBLUR.LanguageChooser.direction(language) }, [
                this.make_column(language, {
                    tag: native_name,
                    heading: gettext("Choose your language"),
                    body: interpolate(gettext("NewsBlur detected %(language)s from your browser."), { language: native_name }, true),
                    note: gettext("You can change this anytime in Preferences."),
                    button: interpolate(gettext("Use %(language)s"), { language: native_name }, true),
                    button_class: 'NB-language-keep',
                    link: gettext("Choose another language")
                }),
                $.make('div', { className: 'NB-language-rule', 'aria-hidden': 'true' }),
                // reader_language.js: The English column repeats the untranslated source text of the
                // messages above, so it reads correctly whatever language the catalog is in.
                this.make_column('en', {
                    tag: english_native_name,
                    heading: "Choose your language",
                    body: interpolate("NewsBlur detected %(language)s from your browser.", { language: NEWSBLUR.LanguageChooser.english_name(language) }, true),
                    note: "You can change this anytime in Preferences.",
                    button: interpolate("Use %(language)s", { language: english_native_name }, true),
                    button_class: 'NB-language-use-english',
                    link: "Choose another language"
                })
            ])
        );
    },

    make_column: function (code, copy) {
        return $.make('div', {
            className: 'NB-language-column',
            lang: code,
            dir: NEWSBLUR.LanguageChooser.direction(code)
        }, [
            $.make('div', { className: 'NB-language-tag' }).text(copy.tag),
            $.make('h2', { className: 'NB-language-title' }).text(copy.heading),
            $.make('p', { className: 'NB-language-body' }).text(copy.body),
            $.make('p', { className: 'NB-language-note' }).text(copy.note),
            $.make('button', {
                type: 'button',
                className: 'NB-modal-submit-button NB-modal-submit-green NB-language-button ' + copy.button_class
            }).text(copy.button),
            $.make('button', { type: 'button', className: 'NB-language-link NB-language-more' }).text(copy.link)
        ]);
    },

    show_bilingual: function () {
        this.render_bilingual();
        this.options.on_resize();
        $('.NB-language-column', this.$el).first().find('.NB-language-more').focus();
    },

    // ========
    // = Grid =
    // ========

    render_grid: function (options) {
        var language = this.language;
        var headings = [
            this.make_heading(language, gettext("Choose your language"),
                gettext("Pick the language you'd like NewsBlur to use. You can change this anytime in Preferences."))
        ];
        if (language != 'en') {
            // reader_language.js: The untranslated source keeps the grid readable for English speakers.
            headings.push(this.make_heading('en', "Choose your language",
                "Pick the language you'd like NewsBlur to use. You can change this anytime in Preferences.")
                .addClass('NB-language-source'));
        }

        this.mode = 'grid';
        this.$el.attr('class', 'NB-language-chooser NB-language-mode-grid').empty().append([
            $.make('div', { className: 'NB-language-headings' }, headings),
            $.make('div', {
                className: 'NB-language-options',
                role: 'radiogroup',
                'aria-label': gettext('Language')
            }, _.map(NEWSBLUR.languages, _.bind(function (option) {
                return this.make_option(option[0], option[1]);
            }, this))),
            $.make('div', { className: 'NB-language-footer' }, [
                $.make('button', {
                    type: 'button',
                    className: 'NB-modal-submit-button NB-modal-submit-green NB-language-button NB-language-use-selected'
                }),
                options.from_bilingual && $.make('button', {
                    type: 'button',
                    className: 'NB-language-link NB-language-back'
                }).text(gettext("Back"))
            ])
        ]);
        this.update_selection();
    },

    make_heading: function (code, title, body) {
        return $.make('div', {
            className: 'NB-language-heading',
            lang: code,
            dir: NEWSBLUR.LanguageChooser.direction(code)
        }, [
            $.make('h2', { className: 'NB-language-title' }).text(title),
            $.make('p', { className: 'NB-language-body' }).text(body)
        ]);
    },

    // Each name is set in its own language and direction, while the cells keep the interface's
    // alignment so Arabic and Hebrew line up with their neighbors.
    make_option: function (code, native_name) {
        return $.make('label', { className: 'NB-language-option', lang: code }, [
            $.make('input', {
                type: 'radio',
                name: 'language_choice',
                value: code,
                checked: code == this.selected ? 'checked' : null
            }),
            $.make('span', { className: 'NB-language-option-name' }, [
                $.make('span', { dir: NEWSBLUR.LanguageChooser.direction(code) }).text(native_name)
            ]),
            $.make('span', { className: 'NB-language-option-check', 'aria-hidden': 'true' })
        ]);
    },

    show_grid: function () {
        this.render_grid({ from_bilingual: true });
        this.options.on_resize();
        $('input[name=language_choice]:checked', this.$el).focus();
    },

    select_option: function (e) {
        this.selected = $(e.currentTarget).val();
        this.update_selection();
    },

    update_selection: function () {
        var selected = this.selected;
        $('.NB-language-option', this.$el).each(function () {
            var $option = $(this);
            $option.toggleClass('NB-active', $('input', $option).val() == selected);
        });
        $('.NB-language-use-selected', this.$el).text(interpolate(gettext("Use %(language)s"), {
            language: NEWSBLUR.LanguageChooser.native_name(selected)
        }, true));
    },

    // ===========
    // = Actions =
    // ===========

    // The reader's document-level shortcuts cancel arrows, space and enter, which the radios and
    // buttons need. Escape and Tab still reach simplemodal to close the dialog and trap focus.
    handle_keydown: function (e) {
        if (e.key == 'Escape' || e.key == 'Tab') return;
        e.stopPropagation();
        if (e.key == 'Enter' && $(e.target).is('input[name=language_choice]')) {
            e.preventDefault();
            this.choose(this.selected);
        }
    },

    keep: function () {
        NEWSBLUR.LanguageChooser.mark_seen();
        this.options.on_keep();
    },

    // Saves through the same preference endpoint as the Preferences language control, together with
    // the seen flag, then reloads so every server-rendered string switches over.
    choose: function (code) {
        if (code == this.language) return this.keep();
        if (this.saving) return;

        var $buttons = $('button, input', this.$el);
        this.saving = true;
        this.$el.attr('aria-busy', 'true');
        $buttons.attr('disabled', true).filter('.NB-language-button').addClass('NB-disabled');

        var preferences = _.extend({ language: code, language_dialog_seen: true }, this.options.preferences);
        NEWSBLUR.assets.save_preferences(preferences, _.bind(function (data) {
            if (!data || data.code < 0 || data.status_code) {
                // reader_language.js: Let the person retry instead of leaving every button disabled.
                this.saving = false;
                this.$el.removeAttr('aria-busy');
                $buttons.attr('disabled', false).removeClass('NB-disabled');
                return;
            }
            NEWSBLUR.LanguageChooser.reload();
        }, this));
    }

});

// ====================
// = Standalone Modal =
// ====================

NEWSBLUR.ReaderLanguage = function (options) {
    var defaults = {
        width: NEWSBLUR.ReaderLanguage.WIDTH,
        // Called once the dialog has fully closed without a reload, so other first-load dialogs can follow.
        on_close: null
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.flags = {};
    this.runner();
};

NEWSBLUR.ReaderLanguage.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderLanguage.prototype.constructor = NEWSBLUR.ReaderLanguage;

_.extend(NEWSBLUR.ReaderLanguage, {

    // Shared with the intro's language page so both hosts give the two columns the same width.
    WIDTH: 680,

    // The standalone dialog waits for any other modal, including the intro, which hosts the chooser itself.
    should_show_dialog: function () {
        return NEWSBLUR.LanguageChooser.should_offer() && !$('#simplemodal-container').length;
    }

});

_.extend(NEWSBLUR.ReaderLanguage.prototype, {

    runner: function () {
        // reader_language.js: Never stack on top of another dialog that opened first.
        if ($('#simplemodal-container').length) return;

        this.chooser = new NEWSBLUR.LanguageChooser({
            on_keep: _.bind(function () { this.close(); }, this),
            on_resize: _.bind(this.resize, this)
        });
        this.$modal = $.make('div', { className: 'NB-modal NB-modal-language' }, [this.chooser.$el]);

        NEWSBLUR.LanguageChooser.mark_seen();
        this.open_modal();
    },

    open_modal: function () {
        var self = this;
        var duration = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 200;

        this.$modal.modal({
            'minWidth': this.options.width,
            'maxWidth': this.options.width,
            'overlayClose': true,
            // reader_language.js focuses the dialog itself below so the first Tab lands on a button.
            'focus': false,
            'onOpen': function (dialog) {
                self.flags.open = true;
                dialog.container.addClass('NB-full-container NB-language-container').attr({
                    'aria-modal': 'true',
                    'aria-label': gettext('Language')
                });
                dialog.overlay.fadeIn(duration, function () {
                    dialog.container.fadeIn(duration);
                    dialog.data.fadeIn(duration, function () {
                        dialog.wrap.focus();
                    });
                    setTimeout(function () {
                        self.resize();
                    }, 0);
                });
            },
            'onClose': function (dialog) {
                self.flags.open = false;
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(duration, function () {
                    dialog.overlay.empty().remove();
                    $.modal.close(function () {
                        if (self.options.on_close) {
                            self.options.on_close();
                        }
                    });
                });
            }
        });
    }

});
