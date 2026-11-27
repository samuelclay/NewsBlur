// settings_dialog.js: the pieces the settings dialogs are built from, mixed into the prototypes of
// Preferences (reader/reader_preferences.js) and the team dialog (reader/reader_team.js), after
// NEWSBLUR.Modal. A tab is a list of groups, a group is a titled panel of rows, and a row is one
// setting: its name and a line of explanation on the left, its control on the right. Each dialog
// saves its own way and reports it in the same pill (set_status).

NEWSBLUR.SettingsDialog = {

    // settings_dialog.js: nothing to press to save or close. The pill ahead of the tabs says when
    // a change has been saved (set_status). tabs is a list of [name, title].
    make_tabs: function (tabs, active) {
        return $.make('div', { className: 'NB-modal-tabs' }, [
            this.make_status()
        ].concat(_.map(tabs, function (tab) {
            return $.make('div', { className: 'NB-modal-tab NB-modal-tab-' + tab[0] + (tab[0] == active ? ' NB-active' : '') }, tab[1]);
        })));
    },

    make_status: function () {
        return $.make('div', { className: 'NB-preferences-status', role: 'status' });
    },

    make_tab: function (name, groups, active) {
        return $.make('div', { className: 'NB-tab NB-tab-' + name + (active ? ' NB-active' : '') }, _.compact(groups));
    },

    make_group: function (title, rows) {
        return $.make('div', { className: 'NB-preference-group' }, [
            $.make('div', { className: 'NB-preference-group-title' }, title),
            $.make('div', { className: 'NB-preference-group-rows' }, _.compact(rows))
        ]);
    },

    make_row: function (class_name, title, hint, controls, label_extras) {
        return $.make('div', { className: 'NB-preference ' + class_name }, [
            $.make('div', { className: 'NB-preference-label' }, _.compact([
                $.make('div', { className: 'NB-preference-title' }, title),
                hint && $.make('div', { className: 'NB-preference-sublabel' }, hint)
            ].concat(label_extras || []))),
            $.make('div', { className: 'NB-preference-options' }, _.compact(_.flatten([controls])))
        ]);
    },

    make_art: function (name) {
        return $.make('span', { className: 'NB-pref-art' }).html(NEWSBLUR.PreferencesArt.draw(name));
    },

    // settings_dialog.js: radio buttons drawn as cards, each a small picture of what the choice
    // does over a short name. The inputs keep their names and values, so a card is only a
    // different face on the same field.
    make_cards: function (name, options, disabled) {
        return $.make('div', { className: 'NB-pref-cards', role: 'radiogroup' }, _.map(options, function (option, i) {
            var id = 'NB-preference-' + name + '-' + i;
            var attrs = { className: 'NB-pref-card', 'for': id };
            if (option.tip) attrs['data-tip'] = option.tip;
            return $.make('label', attrs, [
                $.make('input', { type: 'radio', id: id, name: name, value: option.value, disabled: !!disabled }),
                this.make_art(option.art),
                $.make('span', { className: 'NB-pref-caption' }, option.caption)
            ]);
        }, this));
    },

    // settings_dialog.js: cards for a choice that is not a plain radio group. Each card carries
    // data- attributes saying what picking it means, and the dialog's click handler applies that
    // and marks the chosen card NB-active.
    make_field_cards: function (options, class_name) {
        return $.make('div', { className: 'NB-pref-cards ' + (class_name || ''), role: 'radiogroup' }, _.map(options, function (option) {
            var attrs = _.extend({ className: 'NB-pref-card NB-pref-field-card ' + (option.class_name || ''), role: 'radio', tabindex: '0' }, option.data);
            if (option.tip) attrs['data-tip'] = option.tip;
            return $.make('div', attrs, [
                this.make_art(option.art),
                $.make('span', { className: 'NB-pref-caption' }, option.caption)
            ]);
        }, this));
    },

    // settings_dialog.js: an on or off setting stored as a checkbox, shown as two cards.
    make_toggle_cards: function (name, on, off) {
        return [
            $.make('input', { type: 'checkbox', name: name, className: 'NB-pref-hidden', tabindex: '-1' }),
            this.make_field_cards([
                _.extend({ data: { 'data-field': name, 'data-checked': 'true' } }, on),
                _.extend({ data: { 'data-field': name, 'data-checked': 'false' } }, off)
            ])
        ];
    },

    // settings_dialog.js: checkboxes drawn as chips, for lists where any number can be on.
    make_chips: function (items) {
        return $.make('div', { className: 'NB-pref-chips' }, _.map(items, function (item) {
            return $.make('div', { className: 'NB-pref-chip' }, [
                $.make('input', { type: 'checkbox', id: item.id, name: item.name }),
                $.make('label', { 'for': item.id }, item.label)
            ]);
        }));
    },

    // settings_dialog.js: message replaces the pill's usual words for a change that is not a
    // save, such as a link copied or invites sent.
    set_status: function (status, message) {
        var messages = {
            'saving': gettext('Saving...'),
            'saved': gettext('Saved'),
            'error': gettext('That change could not be saved')
        };
        $('.NB-preferences-status', this.$modal).text(message || messages[status]).addClass('NB-visible')
            .toggleClass('NB-saved', status == 'saved').toggleClass('NB-error', status == 'error');
    },

    // settings_dialog.js: shortens the open tab until the dialog fits the window.
    resize_modal: function (old_height) {
        var $scroll = $('.NB-tab.NB-active', this.$modal);
        var $modal = this.$modal;
        var $modal_container = $modal.closest('.simplemodal-container');

        if ($modal.height() == old_height) {
            console.log(['Modal resize doing nothing, escaping']);
            return;
        }
        if ($modal.height() > $modal_container.height() - 24) {
            $scroll.height($scroll.height() - 5);
            if (!$scroll.height()) return;
            this.resize_modal($modal.height());
        }
    }

};
