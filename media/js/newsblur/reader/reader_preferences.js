// Preferences:
//  - Feed sort order
//  - New window behavior

NEWSBLUR.ReaderPreferences = function (options) {
    var defaults = {
        // reader_preferences.js: half again as wide as other dialogs, or as wide as a smaller window allows.
        width: Math.min(1050, $(window).width() - 48)
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
};

NEWSBLUR.ReaderPreferences.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderPreferences.prototype.constructor = NEWSBLUR.ReaderPreferences;

_.extend(NEWSBLUR.ReaderPreferences.prototype, {

    runner: function () {
        var self = this;
        this.options.onOpen = _.bind(function () {
            this.resize_modal();
            if (self.options.scroll_to === 'briefing') {
                _.defer(function () {
                    var $target = self.$modal.find('.NB-preference-briefing-enabled');
                    if ($target.length) {
                        $target[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
                    }
                });
            }
        }, this);
        this.make_modal();
        this.select_preferences();
        this.update_field_cards();
        this.handle_change();
        this.open_modal();
        this.original_preferences = this.serialize_preferences();
        this.fetch_email_status();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },

    fetch_email_status: function () {
        // The page-load preferences can be stale if emails were unsubscribed on
        // another page (e.g. the email unsubscribe link), so fetch a fresh value.
        var self = this;
        this.model.make_request('/profile/get_preference', { 'preference': 'send_emails' }, function (data) {
            if (!data || _.isUndefined(data.payload) || _.isNull(data.payload)) return;
            NEWSBLUR.Preferences['send_emails'] = data.payload;
            $('.NB-preference-email-status', self.$modal).toggle(!data.payload);
        }, $.noop);
    },

    make_modal: function () {
        var tabs = [
            ['general', gettext('General')],
            ['feeds', gettext('Feeds')],
            ['stories', gettext('Stories')],
            ['behavior', gettext('Behavior')],
            ['keyboard', gettext('Keyboard')]
        ];

        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal' }, [
            // reader_preferences.js: nothing to press to save or close. The pill ahead of the tabs
            // says when a change has been saved (set_status).
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-preferences-status', role: 'status' })
            ].concat(_.map(tabs, function (tab, i) {
                return $.make('div', { className: 'NB-modal-tab NB-modal-tab-' + tab[0] + (i ? '' : ' NB-active') }, tab[1]);
            }))),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                gettext('Preferences'),
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('form', { className: 'NB-preferences-form' }, [
                this.make_general_tab(),
                this.make_feeds_tab(),
                this.make_stories_tab(),
                this.make_behavior_tab(),
                this.make_keyboard_tab()
            ])
        ]);
    },

    // ============
    // = Building =
    // ============

    // reader_preferences.js: a tab is a list of groups, a group is a titled panel of rows, and a row
    // is one preference: its name and a line of explanation on the left, its control on the right.
    make_tab: function (name, groups) {
        return $.make('div', { className: 'NB-tab NB-tab-' + name + (name == 'general' ? ' NB-active' : '') }, _.compact(groups));
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

    // reader_preferences.js: radio buttons drawn as cards, each a small picture of what the choice
    // does over a short name. The inputs keep the names and values that select_preferences and
    // serialize_preferences read, so a card is only a different face on the same field.
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

    // reader_preferences.js: cards for a choice that is not a plain radio group. Each card carries
    // data- attributes saying what picking it means, handle_click applies that to fields kept out of
    // sight, and update_field_cards marks the card that matches those fields.
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

    // reader_preferences.js: an on or off preference stored as a checkbox, shown as two cards.
    make_toggle_cards: function (name, on, off) {
        return [
            $.make('input', { type: 'checkbox', name: name, className: 'NB-pref-hidden', tabindex: '-1' }),
            this.make_field_cards([
                _.extend({ data: { 'data-field': name, 'data-checked': 'true' } }, on),
                _.extend({ data: { 'data-field': name, 'data-checked': 'false' } }, off)
            ])
        ];
    },

    // reader_preferences.js: checkboxes drawn as chips, for lists where any number can be on.
    make_chips: function (items) {
        return $.make('div', { className: 'NB-pref-chips' }, _.map(items, function (item) {
            return $.make('div', { className: 'NB-pref-chip' }, [
                $.make('input', { type: 'checkbox', id: item.id, name: item.name }),
                $.make('label', { 'for': item.id }, item.label)
            ]);
        }));
    },

    make_override_links: function (type, hint) {
        return [
            $.make('div', { className: 'NB-preference-sublabel' }, hint),
            $.make('div', { className: 'NB-clear-overrides-' + type + ' NB-preference-sublabel-link NB-splash-link' }, gettext('Clear all overrides'))
        ];
    },

    // ========
    // = Tabs =
    // ========

    make_general_tab: function () {
        return this.make_tab('general', [
            this.make_group(gettext('Appearance'), [
                this.make_row('NB-preference-appearance', gettext('Theme'), null, this.make_theme_chooser()),
                this.make_row('NB-preference-density', gettext('Spacing'), gettext('Rows in the sidebar and the story list'), this.make_cards('density', [
                    { value: 'compact', caption: gettext('Compact'), art: 'density-compact', tip: gettext('Compact spacing: more dense') },
                    { value: 'comfortable', caption: gettext('Comfortable'), art: 'density-comfortable', tip: gettext('Comfortable spacing: less dense') }
                ])),
                // reader_preferences.js: Motion is two stored preferences, animations and reduce_motion.
                // None turns animations off, Reduced keeps them with reduce_motion on, Full is neither.
                this.make_row('NB-preference-motion', gettext('Motion'), gettext('How panes and stories move'), [
                    $.make('input', { type: 'radio', name: 'animations', value: 'true', className: 'NB-pref-hidden', tabindex: '-1' }),
                    $.make('input', { type: 'radio', name: 'animations', value: 'false', className: 'NB-pref-hidden', tabindex: '-1' }),
                    $.make('input', { type: 'checkbox', name: 'reduce_motion', className: 'NB-pref-hidden', tabindex: '-1' }),
                    this.make_field_cards([
                        { data: { 'data-motion': 'full' }, caption: gettext('Full'), art: 'motion-full', tip: gettext('Show all animations') },
                        { data: { 'data-motion': 'reduced' }, caption: gettext('Reduced'), art: 'motion-reduced', tip: gettext('Keep fades, without movement.') },
                        { data: { 'data-motion': 'none' }, caption: gettext('None'), art: 'motion-none', tip: gettext('Jump immediately with no animations') }
                    ])
                ])
            ]),
            this.make_group(gettext('Language and time'), [
                this.make_row('NB-preference-language', gettext('Language'), null,
                    $.make('select', { id: 'NB-preference-language', name: 'language' },
                        [$.make('option', { value: 'auto', lang: NEWSBLUR.detected_language }, NEWSBLUR.language_auto_label)].concat(
                            NEWSBLUR.languages.map(function (language) {
                                return $.make('option', { value: language[0], lang: language[0] }, language[1]);
                            })
                        ))),
                this.make_row('NB-preference-timezone', gettext('Timezone'), null, this.make_timezone_select()),
                this.make_row('NB-preference-dateformat', gettext('Clock'), null, this.make_cards('dateformat', [
                    { value: '12', caption: gettext('12-hour'), art: 'clock-12', tip: gettext('Use 12-hour clock') },
                    { value: '24', caption: gettext('24-hour'), art: 'clock-24', tip: gettext('Use 24-hour clock') }
                ]))
            ]),
            this.make_group(gettext('Browser'), [
                this.make_row('NB-preference-showunreadcountsintitle', gettext('Window title'), gettext('Show unread counts in the window title'),
                    this.make_toggle_cards('title_counts',
                        { caption: gettext('Unread count'), art: 'title-count', tip: gettext('Show unread counts in the window title') },
                        { caption: gettext('Name only'), art: 'title-plain', tip: gettext('Keep unread counts out of the window title') })),
                this.make_row('NB-preference-tooltips', gettext('Tooltips'), null, this.make_cards('show_tooltips', [
                    { value: 1, caption: gettext('Show'), art: 'tooltip-on', tip: gettext('Show tooltips') },
                    { value: 0, caption: gettext('Hide'), art: 'tooltip-off', tip: gettext('Don\'t bother showing tooltips') }
                ])),
                this.make_row('NB-preference-contextmenu', gettext('Right-clicking'), gettext('Folders, feeds, and story titles'), this.make_cards('show_contextmenus', [
                    { value: 1, caption: gettext('NewsBlur menu'), art: 'menu-newsblur', tip: gettext('Open the feed and story title menu') },
                    { value: 0, caption: gettext('Browser menu'), art: 'menu-browser', tip: gettext('Use the native browser context menu') }
                ]))
            ]),
            this.make_group(gettext('Account'), [
                this.make_row('NB-preference-opml', gettext('Backup your sites'), gettext('Download this XML file as a backup'),
                    $.make('a', { className: 'NB-pref-action NB-splash-link', href: NEWSBLUR.URLs['opml-export'] }, gettext('Download OPML'))),
                this.make_row('NB-preference-email-settings', gettext('Emails'), gettext('Found in the Account dialog'), [
                    $.make('a', { className: 'NB-pref-action NB-splash-link NB-link-account-email-settings', href: '#' }, gettext('Manage email settings')),
                    $.make('div', { className: 'NB-preference-email-status' }, gettext('You are unsubscribed from all NewsBlur emails')).toggle(!NEWSBLUR.assets.preference('send_emails'))
                ])
            ])
        ]);
    },

    make_feeds_tab: function () {
        return this.make_tab('feeds', [
            this.make_group(gettext('Sidebar'), [
                this.make_row('NB-preference-feedorder', gettext('Site order'), null, this.make_cards('feed_order', [
                    { value: 'ALPHABETICAL', caption: gettext('A to Z'), art: 'order-alpha', tip: gettext('Alphabetical') },
                    { value: 'MOSTUSED', caption: gettext('Most used first'), art: 'order-used', tip: gettext('Most used at top, then alphabetical') }
                ])),
                this.make_row('NB-preference-folder-counts', gettext('Folder unread counts'), null, this.make_cards('folder_counts', [
                    { value: 'false', caption: gettext('Collapsed folders'), art: 'counts-collapsed', tip: gettext('Only show counts on collapsed folders') },
                    { value: 'true', caption: gettext('Every folder'), art: 'counts-always', tip: gettext('Always show unread counts on folders') }
                ])),
                this.make_row('NB-preference-autoopenfolder', gettext('When NewsBlur opens'), null, [
                    this.make_cards('autoopen_folder', [
                        { value: 0, caption: gettext('Dashboard'), art: 'launch-dashboard', tip: gettext('Show the dashboard when loading NewsBlur') },
                        { value: 1, caption: gettext('A folder'), art: 'launch-folder', tip: gettext('Open the folder chosen below when loading NewsBlur') }
                    ]),
                    $.make('div', { className: 'NB-pref-detail' }, this.make_autoopen_folders())
                ]),
                this.make_row('NB-preference-showglobalsharedstories', gettext('Special Folders'), gettext('Built-in story lists in the sidebar'), this.make_chips([
                    { id: 'NB-preference-showglobalsharedstories-1', name: 'show_global_shared_stories', label: gettext('Global Shared Stories') },
                    { id: 'NB-preference-showinfrequentsitestories-1', name: 'show_infrequent_site_stories', label: gettext('Infrequent Site Stories') },
                    { id: 'NB-preference-showwidelyreadstories-1', name: 'show_widely_read_stories', label: gettext('Widely Read Stories') },
                    { id: 'NB-preference-showlongreads-1', name: 'show_long_reads', label: gettext('Long Reads') },
                    { id: 'NB-preference-showgoodreads-1', name: 'show_good_reads', label: gettext('Good Reads') }
                ])),
                this.make_row('NB-preference-briefing-enabled', gettext('Daily Briefing'), gettext('AI-curated summary of your top stories'), this.make_cards('briefing_enabled', [
                    { value: 'true', caption: gettext('On'), art: 'briefing-on', tip: gettext('Enable daily briefings') },
                    { value: 'false', caption: gettext('Off'), art: 'briefing-off', tip: gettext('Turn off automatic briefing generation') }
                ]))
            ]),
            this.make_group(gettext('Story list'), [
                this.make_row('NB-preference-layout', gettext('Default layout'), null, this.make_cards('story_layout', [
                    { value: 'full', caption: gettext('Full'), art: 'layout-full', tip: gettext('Every story in full, one after another') },
                    { value: 'split', caption: gettext('Split'), art: 'layout-split', tip: gettext('Story titles beside the open story') },
                    { value: 'list', caption: gettext('List'), art: 'layout-list', tip: gettext('A short list of titles above the open story') },
                    { value: 'grid', caption: gettext('Grid'), art: 'layout-grid', tip: gettext('Stories as cards in a grid') },
                    { value: 'magazine', caption: gettext('Magazine'), art: 'layout-magazine', tip: gettext('Roomy rows with a picture and a preview') }
                ]), this.make_override_links('layout', gettext('You can override this on a per-site basis.'))),
                // reader_preferences.js: order and read filter are not form fields. change_view_setting
                // moves NB-active between these cards and serialize_preferences reads it back.
                this.make_row('NB-preference-view-setting', gettext('Default story order'), null, [
                    $.make('ul', { className: 'NB-pref-cards NB-preference-view-setting-order' }, [
                        $.make('li', { className: 'NB-pref-card NB-preference-view-setting-order-newest NB-active', role: 'radio', tabindex: '0', 'data-tip': gettext('The most recent stories come first') }, [
                            this.make_art('sort-newest'), $.make('span', { className: 'NB-pref-caption' }, gettext('Newest first'))
                        ]),
                        $.make('li', { className: 'NB-pref-card NB-preference-view-setting-order-oldest', role: 'radio', tabindex: '0', 'data-tip': gettext('The oldest stories come first') }, [
                            this.make_art('sort-oldest'), $.make('span', { className: 'NB-pref-caption' }, gettext('Oldest first'))
                        ])
                    ])
                ], this.make_override_links('order', gettext('You can override this on a per-site and per-folder basis.'))),
                this.make_row('NB-preference-view-setting NB-preference-read-filter', gettext('Stories shown'), null, [
                    $.make('ul', { className: 'NB-pref-cards NB-preference-view-setting-read-filter' }, [
                        $.make('li', { className: 'NB-pref-card NB-preference-view-setting-read-filter-all NB-active', role: 'radio', tabindex: '0', 'data-tip': gettext('Read and unread stories are both listed') }, [
                            this.make_art('filter-all'), $.make('span', { className: 'NB-pref-caption' }, gettext('All stories'))
                        ]),
                        $.make('li', { className: 'NB-pref-card NB-preference-view-setting-read-filter-unread', role: 'radio', tabindex: '0', 'data-tip': gettext('Stories you have read are left out') }, [
                            this.make_art('filter-unread'), $.make('span', { className: 'NB-pref-caption' }, gettext('Unread only'))
                        ])
                    ])
                ]),
                this.make_row('NB-preference-showcontentpreview', gettext('Story content preview'), null, this.make_cards('show_content_preview', [
                    { value: 1, caption: gettext('Title and preview'), art: 'preview-on', tip: gettext('Show a preview of the story') },
                    { value: 0, caption: gettext('Title only'), art: 'preview-off', tip: gettext('Don\'t show a preview, only show the story title') }
                ])),
                this.make_row('NB-preference-showimagepreview', gettext('Image preview'), null, this.make_cards('image_preview', [
                    { value: 'small-left', caption: gettext('Small, left'), art: 'image-small-left', tip: gettext('Small image thumbnail on the left') },
                    { value: 'small-right', caption: gettext('Small, right'), art: 'image-small-right', tip: gettext('Small image thumbnail on the right') },
                    { value: 'large-left', caption: gettext('Large, left'), art: 'image-large-left', tip: gettext('Large image thumbnail on the left') },
                    { value: 'large-right', caption: gettext('Large, right'), art: 'image-large-right', tip: gettext('Large image thumbnail on the right') },
                    { value: 'none', caption: gettext('None'), art: 'image-none', tip: gettext('Don\'t show a thumbnail') }
                ])),
                this.make_row('NB-preference-realtimenewstories', gettext('New stories'), gettext('Show new stories as they arrive'), this.make_cards('realtime_new_stories', [
                    { value: 'true', caption: gettext('In a pill'), art: 'pill-on', tip: gettext('Offer them in an "N new stories" pill') },
                    { value: 'false', caption: gettext('On reload'), art: 'pill-off', tip: gettext('Only show them when the list reloads') }
                ])),
                this.make_row('NB-preference-clustering-enabled', gettext('Story Clustering'), gettext('Groups similar stories from different feeds'), [
                    this.make_cards('story_clustering', [
                        { value: 'true', caption: gettext('Grouped'), art: 'cluster-on', tip: gettext('Group duplicate stories across your feeds') },
                        { value: 'false', caption: gettext('Separate'), art: 'cluster-off', tip: gettext('Show every story individually without grouping') }
                    ]),
                    $.make('div', { className: 'NB-pref-detail NB-clustering-mark-read-option' + (!NEWSBLUR.Globals.is_archive ? ' NB-disabled' : '') }, [
                        $.make('input', { id: 'NB-preference-cluster-mark-read', type: 'checkbox', name: 'cluster_mark_read', value: 'true', disabled: !NEWSBLUR.Globals.is_archive }),
                        $.make('label', { 'for': 'NB-preference-cluster-mark-read' }, gettext('Mark duplicates as read')),
                        (!NEWSBLUR.Globals.is_archive && $.make('a', { href: '#', className: 'NB-premium-archive-upgrade-notice NB-premium-link', 'data-feature': 'clustering' }, [
                            $.make('span', { className: 'NB-archive-badge' }, gettext('Premium Archive'))
                        ]))
                    ])
                ]),
                this.make_row('NB-preference-showdiscover', gettext('Discover sites'), gettext('Related sites above the story titles'), this.make_cards('show_discover', [
                    { value: 'true', caption: gettext('Show'), art: 'discover-on', tip: gettext('Show discover sites popover above story titles') },
                    { value: 'false', caption: gettext('Hide'), art: 'discover-off', tip: gettext('Hide discover sites popover') }
                ]))
            ])
        ]);
    },

    make_stories_tab: function () {
        var sideoptions = {
            email: gettext('Email'), save: gettext('Save'), train: gettext('Train'), share: gettext('Share'),
            related: gettext('Related'), ask_ai: gettext('Ask AI'), listen: gettext('Listen')
        };

        return this.make_tab('stories', [
            this.make_group(gettext('Reading'), [
                this.make_row('NB-preference-view', gettext('Default view'), null, this.make_cards('default_view', [
                    { value: 'page', caption: gettext('Original'), art: 'view-page', tip: gettext('The site itself, as you would see it in a browser') },
                    { value: 'feed', caption: gettext('Feed'), art: 'view-feed', tip: gettext('Every story as the site published it in its feed') },
                    { value: 'text', caption: gettext('Text'), art: 'view-text', tip: gettext('The full text of the story, fetched from the site') },
                    { value: 'story', caption: gettext('Story'), art: 'view-story', tip: gettext('The story on its own page on the site') }
                ]), this.make_override_links('view', gettext('You can override this on a per-site basis.'))),
                this.make_row('NB-preference-truncatestory', gettext('Tall stories'), gettext('Shortened stories open with a click'), this.make_cards('truncate_story', [
                    { value: 'social', caption: gettext('Shorten shared'), art: 'truncate-social', tip: gettext('Only truncate long shared stories in blurblogs') },
                    { value: 'all', caption: gettext('Shorten all'), art: 'truncate-all', tip: gettext('Force all tall stories to have a max height') },
                    { value: 'none', caption: gettext('Show in full'), art: 'truncate-none', tip: gettext('Show the entire story, even if really, really long') }
                ])),
                this.make_row('NB-preference-window', gettext('Open links'), null, this.make_cards('new_window', [
                    { value: 0, caption: gettext('In this window'), art: 'link-same', tip: gettext('Links in stories replace NewsBlur in this window') },
                    { value: 1, caption: gettext('In a new window'), art: 'link-new', tip: gettext('Links in stories open in a new window or tab') }
                ])),
                this.make_row('NB-preference-highlights', gettext('Highlighter'), gettext('Show highlighter when selecting text'), this.make_cards('highlights', [
                    { value: 'true', caption: gettext('On'), art: 'highlight-on', tip: gettext('Show highlighter when selecting text') },
                    { value: 'false', caption: gettext('Off'), art: 'highlight-off', tip: gettext('Disable the highlighter') }
                ])),
                this.make_row('NB-preference-youtube-captions', gettext('YouTube Captions'), gettext('Enable captions/subtitles for YouTube videos'),
                    this.make_toggle_cards('youtube_captions',
                        { caption: gettext('On'), art: 'captions-on', tip: gettext('Enable captions/subtitles for YouTube videos') },
                        { caption: gettext('Off'), art: 'captions-off', tip: gettext('Play YouTube videos without captions') }))
            ]),
            this.make_group(gettext('Story buttons'), [
                this.make_row('NB-preference-story-button-placement', gettext('Placement'), gettext('Train, Save, Share and the rest'), [
                    this.make_cards('story_button_placement', [
                        { value: 'bottom', caption: gettext('Below the story'), art: 'buttons-bottom', tip: gettext('Always show Train/Save/Share buttons below stories') },
                        { value: 'right', caption: gettext('Beside the story'), art: 'buttons-right', tip: gettext('Show buttons on the right (when there is room)') }
                    ]),
                    $.make('div', { className: 'NB-pref-detail NB-preference-story-sideoption-sticky' }, [
                        $.make('input', { id: 'NB-preference-story-sideoption-sticky', type: 'checkbox', name: 'sticky_story_sideoptions' }),
                        $.make('label', { 'for': 'NB-preference-story-sideoption-sticky' }, gettext('Keep right-side buttons visible while reading'))
                    ])
                ]),
                this.make_row('NB-preference-story-sideoptions', gettext('Buttons'), null, this.make_chips(_.map(sideoptions, function (label, key) {
                    return { id: 'NB-preference-story-sideoption-' + key, name: 'show_sideoption_' + key, label: label };
                })))
            ]),
            this.make_group(gettext('Sharing'), [
                this.make_row('NB-preference-disablesocial', gettext('Social features'), gettext('Blurblogs, shared stories and comments'), this.make_cards('disable_social', [
                    { value: 'false', caption: gettext('On'), art: 'social-on', tip: gettext('Enable social features') },
                    { value: 'true', caption: gettext('Off'), art: 'social-off', tip: gettext('Hide all sharing, comments, and blurblog features') }
                ])),
                this.make_row('NB-preference-public-comments', gettext('Comments'), null, this.make_cards('hide_public_comments', [
                    { value: 'false', caption: gettext('Everyone'), art: 'comments-all', tip: gettext('Show from both friends and the public') },
                    { value: 'true', caption: gettext('Friends only'), art: 'comments-friends', tip: gettext('Only show comments from friends') }
                ])),
                this.make_row('NB-preference-story-share', gettext('Sharing services'), null, this.make_chips(_.map(NEWSBLUR.assets.third_party_sharing_services, function (label, key) {
                    return { id: 'NB-preference-story-share-' + key, name: 'story_share_' + key, label: label };
                })))
            ])
        ]);
    },

    make_behavior_tab: function () {
        return this.make_tab('behavior', [
            this.make_group(gettext('Marking stories as read'), [
                this.make_row('NB-preference-readstorydelay', gettext('Mark a story as read'), gettext('Selecting a story in the story titles marks it as read.'), [
                    this.make_cards('read_story_delay', [
                        { value: '0', caption: gettext('Immediately'), art: 'read-now', tip: gettext('A story is read as soon as it is selected') },
                        { value: '1', caption: gettext('After a delay'), art: 'read-delay', tip: gettext('A story is read once it has been open for the time set below') },
                        { value: '-2', caption: gettext('When clicked'), art: 'read-click', tip: gettext('Manually or by clicking in the story') },
                        { value: '-1', caption: gettext('With the keyboard'), art: 'read-keys', tip: interpolate(gettext('Manually by hitting %(first_key)s or %(second_key)s'), { first_key: 'u', second_key: 'm' }, true) }
                    ]),
                    // reader_preferences.js: slide_read_story_delay_slider fills the
                    // text on both sides of the slider from one translated sentence.
                    $.make('label', { className: 'NB-pref-detail NB-pref-slider-line', 'for': 'NB-preference-read_story_delay-1' }, [
                        $.make('span', { className: 'NB-preference-slider-before' }),
                        $.make('span', { className: 'NB-tangle-readstorydelay', 'data-var': 'delay' }),
                        $.make('span', { className: 'NB-preference-slider-after NB-tangle-seconds' })
                    ])
                ]),
                this.make_row('NB-preference-markreadstoryscroll', gettext('While scrolling'), gettext('Stories scrolled past in the story titles'), this.make_cards('mark_read_on_scroll_titles', [
                    { value: 'true', caption: gettext('Mark as read'), art: 'scroll-read', tip: gettext('Mark stories as read when scrolled past') },
                    { value: 'false', caption: gettext('Leave unread'), art: 'scroll-keep', tip: gettext('Don\'t automatically mark stories as read') }
                ])),
                this.make_row('NB-preference-daysofunread', gettext('Days of unreads'), null, [
                    $.make('ul', { className: 'segmented-control NB-preference-daysofunread-control' + (!NEWSBLUR.Globals.is_archive ? ' NB-disabled' : '') }, [
                        $.make('li', { className: 'NB-daysofunread-option NB-daysofunread-default', 'data-value': 'default', role: 'button' }, gettext('Default')),
                        $.make('li', { className: 'NB-daysofunread-option NB-daysofunread-days', 'data-value': 'days', role: 'button' }, gettext('Days')),
                        $.make('li', { className: 'NB-daysofunread-option NB-daysofunread-never', 'data-value': 'never', role: 'button' }, gettext('Never'))
                    ]),
                    $.make('div', { className: 'NB-daysofunread-slider-container' }, [
                        $.make('input', {
                            type: 'range',
                            className: 'NB-daysofunread-slider',
                            name: 'days_of_unread',
                            min: '1',
                            max: '400',
                            value: NEWSBLUR.Globals.is_archive ? NEWSBLUR.Preferences.days_of_unread : NEWSBLUR.Globals.default_days_of_unread,
                            disabled: !NEWSBLUR.Globals.is_archive
                        }),
                        $.make('div', { className: 'NB-daysofunread-slider-value' })
                    ]),
                    (!NEWSBLUR.Globals.is_archive && $.make('a', { className: 'NB-premium-archive-upgrade-notice NB-premium-link', href: '#', 'data-feature': 'stay-unread' },
                        NEWSBLUR.utils.interpolate_nodes(gettext('%(badge)s Customize days of unreads'), {
                            badge: $.make('span', { className: 'NB-archive-badge' }, gettext('Premium Archive'))
                        })))
                ])
            ]),
            this.make_group(gettext('Marking sites as read'), [
                this.make_row('NB-preference-markreadconfirm', gettext('Ask first'), gettext('Confirming mark as read'), this.make_cards('mark_read_river_confirm', [
                    { value: 'feeds_folders', caption: gettext('Sites and folders'), art: 'confirm-all', tip: gettext('Show confirmation when marking feeds or folders as read') },
                    { value: 'folders_only', caption: gettext('Folders only'), art: 'confirm-folders', tip: gettext('Show confirmation only when marking folders as read') },
                    { value: 'never', caption: gettext('Never'), art: 'confirm-never', tip: gettext('Mark as read without confirmation') }
                ])),
                this.make_row('NB-preference-markreadnextfeed', gettext('Afterwards'), gettext('After marking feed/folder read'), this.make_cards('markread_nextfeed', [
                    { value: 'nextfeed', caption: gettext('Open the next one'), art: 'after-next', tip: gettext('Open the next site/folder') },
                    { value: 'nothing', caption: gettext('Stay put'), art: 'after-stay', tip: gettext('Stay on the same feed/folder') }
                ]))
            ]),
            this.make_group(gettext('Clicks'), [
                this.make_row('NB-preference-openfeedaction', gettext('When opening a site'), null, this.make_cards('open_feed_action', [
                    { value: 'newest', caption: gettext('Open the first story'), art: 'open-first', tip: gettext('Opening a site also opens its first story') },
                    { value: 0, caption: gettext('Show all stories'), art: 'open-list', tip: gettext('Opening a site shows its stories and waits for you to pick one') }
                ])),
                this.make_row('NB-preference-doubleclickfeed', gettext('Double-clicking a site'), null, this.make_cards('doubleclick_feed', [
                    { value: 'open', caption: gettext('New window'), art: 'dbl-open', tip: gettext('Open the site in a new window') },
                    { value: 'open_and_read', caption: gettext('New window, marked read'), art: 'dbl-open-read', tip: gettext('Open the site in a new window and mark it as read') },
                    { value: 'ignore', caption: gettext('Nothing'), art: 'dbl-nothing', tip: gettext('Don\'t do anything on double-clicks') }
                ])),
                this.make_row('NB-preference-doubleclickunread', gettext('Double-clicking an unread count'), null, this.make_cards('doubleclick_unread', [
                    { value: 'markread', caption: gettext('Mark the site as read'), art: 'dblcount-read', tip: gettext('Double-clicking a site\'s unread count marks the whole site as read') },
                    { value: 'ignore', caption: gettext('Nothing'), art: 'dbl-nothing', tip: gettext('Don\'t do anything on double-clicks') }
                ]))
            ])
        ]);
    },

    make_keyboard_tab: function () {
        var make_keys = function (keys) {
            return _.map(keys, function (key) {
                return $.make('div', { className: 'NB-keyboard-shortcut-key' }, [key]);
            });
        };

        return this.make_tab('keyboard', [
            (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-preferences-notpremium' },
                interpolate(_.escape(gettext('You must have a %(link_start)spremium account%(link_end)s to change keyboard shortcuts.')), {
                    link_start: '<span class="NB-splash-link NB-premium-link">',
                    link_end: '</span>'
                }, true))),
            this.make_group(gettext('Arrow keys'), [
                this.make_row('NB-preference-keyboard-horizontalarrows', make_keys(['&#x2190;', '&#x2192;']), null, this.make_cards('keyboard_horizontalarrows', [
                    { value: 'view', caption: gettext('Switch views'), art: 'keys-views', tip: gettext('Switch between views (original, feed, text, story)') },
                    { value: 'site', caption: gettext('Next site'), art: 'keys-sites', tip: gettext('Open the next site/folder') }
                ], !NEWSBLUR.Globals.is_premium)),
                this.make_row('NB-preference-keyboard-verticalarrows', make_keys(['&#x2193;', '&#x2191;']), null, [
                    this.make_cards('keyboard_verticalarrows', [
                        { value: 'story', caption: gettext('Next story'), art: 'keys-stories', tip: gettext('Navigate between stories') },
                        { value: 'scroll', caption: gettext('Scroll the story'), art: 'keys-scroll', tip: gettext('Scroll the story by the distance set below') }
                    ], !NEWSBLUR.Globals.is_premium),
                    // reader_preferences.js: slide_arrow_scroll_spacing_slider fills the
                    // text on both sides of the slider from one translated sentence.
                    $.make('label', { className: 'NB-pref-detail NB-pref-slider-line', 'for': 'NB-preference-keyboard_verticalarrows-1' }, [
                        $.make('span', { className: 'NB-preference-slider-before' }),
                        $.make('span', { className: 'NB-tangle-arrowscrollspacing-control NB-preference-slider', 'data-var': 'arrow' }),
                        $.make('span', { className: 'NB-preference-slider-after NB-tangle-arrowscrollspacing' }),
                        $.make('input', { name: 'arrow_scroll_spacing', value: NEWSBLUR.Preferences.arrow_scroll_spacing, type: 'hidden' })
                    ])
                ])
            ]),
            this.make_group(gettext('Space bar'), [
                this.make_row('NB-preference-keyboard-spacebar', make_keys(['space']), null, [
                    this.make_cards('space_bar_action', [
                        { value: 'next_unread', caption: gettext('Next unread at the end'), art: 'space-bottom', tip: gettext('Open next unread story when bottom of story is visible') },
                        { value: 'next_unread_50', caption: gettext('Next unread halfway'), art: 'space-half', tip: gettext('Open next unread story when story is half-way up') },
                        { value: 'scroll_only', caption: gettext('Scroll only'), art: 'space-scroll', tip: gettext('Only page down in story, do not open next unread story') }
                    ]),
                    // reader_preferences.js: slide_space_scroll_spacing_slider fills the
                    // text on both sides of the slider from one translated sentence.
                    $.make('div', { className: 'NB-pref-detail NB-pref-slider-line' }, [
                        $.make('span', { className: 'NB-preference-slider-before' }),
                        $.make('span', { className: 'NB-tangle-spacescrollspacing-control NB-preference-slider', 'data-var': 'space' }),
                        $.make('span', { className: 'NB-preference-slider-after NB-tangle-spacescrollspacing' }),
                        $.make('input', { name: 'space_scroll_spacing', value: NEWSBLUR.Preferences.space_scroll_spacing, type: 'hidden' })
                    ])
                ])
            ])
        ]);
    },

    make_timezone_select: function () {
        return $.make('select', { id: 'NB-preference-timezone-1', name: 'timezone' }, [
            $.make('option', { value: 'Pacific/Midway' }, gettext('(GMT-11:00) Midway Island, Samoa')),
            $.make('option', { value: 'America/Adak' }, gettext('(GMT-10:00) Hawaii-Aleutian')),
            $.make('option', { value: 'Etc/GMT+10' }, gettext('(GMT-10:00) Hawaii')),
            $.make('option', { value: 'Pacific/Marquesas' }, gettext('(GMT-09:30) Marquesas Islands')),
            $.make('option', { value: 'Pacific/Gambier' }, gettext('(GMT-09:00) Gambier Islands')),
            $.make('option', { value: 'America/Anchorage' }, gettext('(GMT-09:00) Alaska')),
            $.make('option', { value: 'America/Ensenada' }, gettext('(GMT-08:00) Tijuana, Baja California')),
            $.make('option', { value: 'Etc/GMT+8' }, gettext('(GMT-08:00) Pitcairn Islands')),
            $.make('option', { value: 'America/Los_Angeles' }, gettext('(GMT-08:00) Pacific Time (US & Canada)')),
            $.make('option', { value: 'America/Denver' }, gettext('(GMT-07:00) Mountain Time (US & Canada)')),
            $.make('option', { value: 'America/Chihuahua' }, gettext('(GMT-07:00) Chihuahua, La Paz, Mazatlan')),
            $.make('option', { value: 'America/Dawson_Creek' }, gettext('(GMT-07:00) Arizona')),
            $.make('option', { value: 'America/Belize' }, gettext('(GMT-06:00) Saskatchewan, Central America')),
            $.make('option', { value: 'America/Cancun' }, gettext('(GMT-06:00) Guadalajara, Mexico City')),
            $.make('option', { value: 'Chile/EasterIsland' }, gettext('(GMT-06:00) Easter Island')),
            $.make('option', { value: 'America/Chicago' }, gettext('(GMT-06:00) Central Time (US & Canada)')),
            $.make('option', { value: 'America/New_York' }, gettext('(GMT-05:00) Eastern Time (US & Canada)')),
            $.make('option', { value: 'America/Havana' }, gettext('(GMT-05:00) Cuba')),
            $.make('option', { value: 'America/Bogota' }, gettext('(GMT-05:00) Bogota, Lima, Quito, Rio Branco')),
            $.make('option', { value: 'America/Caracas' }, gettext('(GMT-04:30) Caracas')),
            $.make('option', { value: 'America/Santiago' }, gettext('(GMT-04:00) Santiago')),
            $.make('option', { value: 'America/La_Paz' }, gettext('(GMT-04:00) La Paz')),
            $.make('option', { value: 'Atlantic/Stanley' }, gettext('(GMT-04:00) Faukland Islands')),
            $.make('option', { value: 'America/Campo_Grande' }, gettext('(GMT-04:00) Brazil')),
            $.make('option', { value: 'America/Goose_Bay' }, gettext('(GMT-04:00) Atlantic Time (Goose Bay)')),
            $.make('option', { value: 'America/Glace_Bay' }, gettext('(GMT-04:00) Atlantic Time (Canada)')),
            $.make('option', { value: 'America/St_Johns' }, gettext('(GMT-03:30) Newfoundland')),
            $.make('option', { value: 'America/Araguaina' }, gettext('(GMT-03:00) UTC-3')),
            $.make('option', { value: 'America/Montevideo' }, gettext('(GMT-03:00) Montevideo')),
            $.make('option', { value: 'America/Miquelon' }, gettext('(GMT-03:00) Miquelon, St. Pierre')),
            $.make('option', { value: 'America/Godthab' }, gettext('(GMT-03:00) Greenland')),
            $.make('option', { value: 'America/Argentina/Buenos_Aires' }, gettext('(GMT-03:00) Buenos Aires')),
            $.make('option', { value: 'America/Sao_Paulo' }, gettext('(GMT-03:00) Brasilia')),
            $.make('option', { value: 'America/Noronha' }, gettext('(GMT-02:00) Mid-Atlantic')),
            $.make('option', { value: 'Atlantic/Cape_Verde' }, gettext('(GMT-01:00) Cape Verde Is.')),
            $.make('option', { value: 'Atlantic/Azores' }, gettext('(GMT-01:00) Azores')),
            $.make('option', { value: 'Europe/Belfast' }, gettext('(GMT) Greenwich Mean Time : Belfast')),
            $.make('option', { value: 'Europe/Dublin' }, gettext('(GMT) Greenwich Mean Time : Dublin')),
            $.make('option', { value: 'Europe/Lisbon' }, gettext('(GMT) Greenwich Mean Time : Lisbon')),
            $.make('option', { value: 'Europe/London' }, gettext('(GMT) Greenwich Mean Time : London')),
            $.make('option', { value: 'Africa/Abidjan' }, gettext('(GMT) Monrovia, Reykjavik')),
            $.make('option', { value: 'Europe/Amsterdam' }, gettext('(GMT+01:00) Amsterdam, Berlin, Stockholm')),
            $.make('option', { value: 'Europe/Belgrade' }, gettext('(GMT+01:00) Belgrade, Budapest, Prague')),
            $.make('option', { value: 'Europe/Brussels' }, gettext('(GMT+01:00) Brussels, Copenhagen, Paris')),
            $.make('option', { value: 'Africa/Algiers' }, gettext('(GMT+01:00) West Central Africa')),
            $.make('option', { value: 'Africa/Windhoek' }, gettext('(GMT+01:00) Windhoek')),
            $.make('option', { value: 'Asia/Beirut' }, gettext('(GMT+02:00) Beirut')),
            $.make('option', { value: 'Africa/Cairo' }, gettext('(GMT+02:00) Cairo')),
            $.make('option', { value: 'Asia/Gaza' }, gettext('(GMT+02:00) Gaza')),
            $.make('option', { value: 'Africa/Blantyre' }, gettext('(GMT+02:00) Harare, Pretoria')),
            $.make('option', { value: 'Asia/Jerusalem' }, gettext('(GMT+02:00) Jerusalem')),
            $.make('option', { value: 'Europe/Minsk' }, gettext('(GMT+02:00) Minsk, Kyiv')),
            $.make('option', { value: 'Asia/Damascus' }, gettext('(GMT+02:00) Syria')),
            $.make('option', { value: 'Europe/Moscow' }, gettext('(GMT+03:00) Moscow, St. Petersburg')),
            $.make('option', { value: 'Africa/Addis_Ababa' }, gettext('(GMT+03:00) Nairobi')),
            $.make('option', { value: 'Asia/Tehran' }, gettext('(GMT+03:30) Tehran')),
            $.make('option', { value: 'Asia/Dubai' }, gettext('(GMT+04:00) Abu Dhabi, Muscat')),
            $.make('option', { value: 'Asia/Yerevan' }, gettext('(GMT+04:00) Yerevan')),
            $.make('option', { value: 'Asia/Kabul' }, gettext('(GMT+04:30) Kabul')),
            $.make('option', { value: 'Asia/Yekaterinburg' }, gettext('(GMT+05:00) Ekaterinburg')),
            $.make('option', { value: 'Asia/Tashkent' }, gettext('(GMT+05:00) Tashkent')),
            $.make('option', { value: 'Asia/Kolkata' }, gettext('(GMT+05:30) Chennai, Mumbai, New Delhi')),
            $.make('option', { value: 'Asia/Katmandu' }, gettext('(GMT+05:45) Kathmandu')),
            $.make('option', { value: 'Asia/Dhaka' }, gettext('(GMT+06:00) Astana, Dhaka')),
            $.make('option', { value: 'Asia/Novosibirsk' }, gettext('(GMT+06:00) Novosibirsk')),
            $.make('option', { value: 'Asia/Rangoon' }, gettext('(GMT+06:30) Yangon (Rangoon)')),
            $.make('option', { value: 'Asia/Bangkok' }, gettext('(GMT+07:00) Bangkok, Hanoi, Jakarta')),
            $.make('option', { value: 'Asia/Krasnoyarsk' }, gettext('(GMT+07:00) Krasnoyarsk')),
            $.make('option', { value: 'Asia/Hong_Kong' }, gettext('(GMT+08:00) Beijing, Chongqing, Hong Kong')),
            $.make('option', { value: 'Asia/Irkutsk' }, gettext('(GMT+08:00) Irkutsk, Ulaan Bataar')),
            $.make('option', { value: 'Australia/Perth' }, gettext('(GMT+08:00) Perth')),
            $.make('option', { value: 'Australia/Eucla' }, gettext('(GMT+08:45) Eucla')),
            $.make('option', { value: 'Asia/Tokyo' }, gettext('(GMT+09:00) Osaka, Sapporo, Tokyo')),
            $.make('option', { value: 'Asia/Seoul' }, gettext('(GMT+09:00) Seoul')),
            $.make('option', { value: 'Asia/Yakutsk' }, gettext('(GMT+09:00) Yakutsk')),
            $.make('option', { value: 'Australia/Adelaide' }, gettext('(GMT+09:30) Adelaide')),
            $.make('option', { value: 'Australia/Darwin' }, gettext('(GMT+09:30) Darwin')),
            $.make('option', { value: 'Australia/Brisbane' }, gettext('(GMT+10:00) Brisbane')),
            $.make('option', { value: 'Australia/Sydney' }, gettext('(GMT+10:00) Sydney, Hobart')),
            $.make('option', { value: 'Asia/Vladivostok' }, gettext('(GMT+10:00) Vladivostok')),
            $.make('option', { value: 'Australia/Lord_Howe' }, gettext('(GMT+10:30) Lord Howe Island')),
            $.make('option', { value: 'Etc/GMT-11' }, gettext('(GMT+11:00) Solomon Is., New Caledonia')),
            $.make('option', { value: 'Asia/Magadan' }, gettext('(GMT+11:00) Magadan')),
            $.make('option', { value: 'Pacific/Norfolk' }, gettext('(GMT+11:30) Norfolk Island')),
            $.make('option', { value: 'Asia/Anadyr' }, gettext('(GMT+12:00) Anadyr, Kamchatka')),
            $.make('option', { value: 'Pacific/Auckland' }, gettext('(GMT+12:00) Auckland, Wellington')),
            $.make('option', { value: 'Etc/GMT-12' }, gettext('(GMT+12:00) Fiji, Kamchatka, Marshall Is.')),
            $.make('option', { value: 'Pacific/Chatham' }, gettext('(GMT+12:45) Chatham Islands')),
            $.make('option', { value: 'Pacific/Tongatapu' }, gettext('(GMT+13:00) Nuku\'alofa')),
            $.make('option', { value: 'Pacific/Kiritimati' }, gettext('(GMT+14:00) Kiritimati'))
        ]);
    },

    // =================
    // = Theme chooser =
    // =================

    // reader_preferences.js: every theme choice in one place. A tile picks that theme outright and
    // Auto follows the device. Below the tiles, Auto's light theme and dark theme are chosen
    // separately, and the Auto tile is drawn as one half of each. Choices take effect at once,
    // like the theme row in the manage menu (reader.js switch_theme), so there is nothing to save.
    make_theme_chooser: function () {
        var names = this.theme_names();
        var make_preview = function (theme) {
            return $.make('div', { className: 'NB-theme-preview NB-theme-preview-' + theme }, [
                $.make('div', { className: 'NB-theme-preview-feeds' }, [
                    $.make('div', { className: 'NB-theme-preview-feed' }),
                    $.make('div', { className: 'NB-theme-preview-feed NB-selected' }),
                    $.make('div', { className: 'NB-theme-preview-feed' }),
                    $.make('div', { className: 'NB-theme-preview-feed' })
                ]),
                $.make('div', { className: 'NB-theme-preview-stories' }, [
                    $.make('div', { className: 'NB-theme-preview-story' }),
                    $.make('div', { className: 'NB-theme-preview-story NB-selected' }),
                    $.make('div', { className: 'NB-theme-preview-story' }),
                    $.make('div', { className: 'NB-theme-preview-story' })
                ])
            ]);
        };
        var make_auto_side = function (side, title, themes) {
            return $.make('div', { className: 'NB-theme-auto-side NB-theme-auto-side-' + side }, [
                $.make('div', { className: 'NB-theme-auto-side-title' }, title),
                $.make('ul', { className: 'segmented-control NB-theme-auto-control', role: 'radiogroup', 'aria-label': title }, _.map(themes, function (theme) {
                    return $.make('li', { className: 'NB-theme-auto-option', role: 'radio', tabindex: '0', 'data-theme': theme }, [
                        $.make('div', { className: 'NB-theme-swatch NB-theme-swatch-' + theme }),
                        $.make('span', names[theme])
                    ]);
                }))
            ]);
        };

        return $.make('div', { className: 'NB-theme-chooser' }, [
            $.make('div', { className: 'NB-theme-choices', role: 'radiogroup', 'aria-label': gettext('Theme') }, _.map(['auto', 'light', 'sepia', 'gray', 'dark'], function (theme) {
                return $.make('div', { className: 'NB-theme-choice NB-theme-choice-' + theme, role: 'radio', tabindex: '0', 'data-theme': theme }, [
                    theme == 'auto' ? $.make('div', { className: 'NB-theme-preview-auto' }, [
                        make_preview('light').addClass('NB-theme-preview-day'),
                        make_preview('dark').addClass('NB-theme-preview-night')
                    ]) : make_preview(theme),
                    $.make('div', { className: 'NB-theme-choice-name' }, names[theme])
                ]);
            })),
            $.make('div', { className: 'NB-theme-auto' }, [
                $.make('div', { className: 'NB-theme-auto-title' }, gettext('Auto follows system appearance')),
                $.make('div', { className: 'NB-theme-auto-sides' }, [
                    make_auto_side('light', gettext('Light appearance'), ['light', 'sepia']),
                    make_auto_side('dark', gettext('Dark appearance'), ['gray', 'dark'])
                ])
            ])
        ]);
    },

    theme_names: function () {
        return {
            'auto': gettext('Auto'),
            'light': gettext('Light'),
            'sepia': pgettext('theme', 'Warm'),
            'gray': pgettext('theme', 'Gray'),
            'dark': gettext('Dark')
        };
    },

    update_theme_chooser: function () {
        var theme = NEWSBLUR.assets.preference('theme');
        var in_effect = NEWSBLUR.assets.theme();
        var auto_light = NEWSBLUR.assets.preference('theme_light') == 'sepia' ? 'sepia' : 'light';
        var auto_dark = NEWSBLUR.assets.preference('theme_dark') == 'gray' ? 'gray' : 'dark';
        var $chooser = $('.NB-theme-chooser', this.$modal);

        $('.NB-theme-choice', $chooser).each(function () {
            var active = $(this).data('theme') == theme;
            $(this).toggleClass('NB-active', active).attr('aria-checked', active ? 'true' : 'false');
        });
        $('.NB-theme-auto-option', $chooser).each(function () {
            var option = $(this).data('theme');
            var active = option == auto_light || option == auto_dark;
            $(this).toggleClass('NB-active', active).attr('aria-checked', active ? 'true' : 'false');
        });
        // reader_preferences.js: the Auto tile shows the two themes it switches between.
        $('.NB-theme-preview-day', $chooser).removeClass('NB-theme-preview-light NB-theme-preview-sepia').addClass('NB-theme-preview-' + auto_light);
        $('.NB-theme-preview-night', $chooser).removeClass('NB-theme-preview-gray NB-theme-preview-dark').addClass('NB-theme-preview-' + auto_dark);
        // reader_preferences.js: under Auto, mark the side the device has NewsBlur on right now.
        $('.NB-theme-auto', $chooser).toggleClass('NB-active', theme == 'auto');
        $('.NB-theme-auto-side-light', $chooser).toggleClass('NB-in-effect', theme == 'auto' && (in_effect == 'light' || in_effect == 'sepia'));
        $('.NB-theme-auto-side-dark', $chooser).toggleClass('NB-in-effect', theme == 'auto' && (in_effect == 'gray' || in_effect == 'dark'));
    },

    watch_system_theme: function () {
        if (!window.matchMedia) return;
        this.system_theme_query = window.matchMedia('(prefers-color-scheme: dark)');
        // reader_preferences.js: reader.js load_theme reacts to the same change. Deferring lets it
        // finish first, so the chooser marks the side that is now showing.
        this.on_system_theme_change = _.bind(function () {
            _.defer(_.bind(this.update_theme_chooser, this));
        }, this);
        this.system_theme_query.addEventListener('change', this.on_system_theme_change);
    },

    // reader_preferences.js: common/modal.js calls this as the dialog closes, while its fields can
    // still be read, so a change made a moment before closing is saved too, and one whose save
    // failed gets another try.
    handle_modal_closed: function () {
        this.save_preferences();
        NEWSBLUR.utils.hide_tip();
        if (this.system_theme_query) {
            this.system_theme_query.removeEventListener('change', this.on_system_theme_change);
        }
    },

    make_autoopen_folders: function () {
        var autoopen_folder = NEWSBLUR.Preferences.autoopen_folder;
        var $folders = NEWSBLUR.utils.make_folders(autoopen_folder, gettext("All Site Stories"), 'default_folder');
        return $folders;
    },

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
    },

    // reader_preferences.js: mark the card that matches each field kept out of sight (make_field_cards).
    update_field_cards: function () {
        var $modal = this.$modal;
        var mark = function ($card, active) {
            $card.toggleClass('NB-active', active).attr('aria-checked', active ? 'true' : 'false');
        };
        $('.NB-pref-field-card[data-field]', $modal).each(function () {
            var checked = $('input[name=' + $(this).attr('data-field') + ']', $modal).is(':checked');
            mark($(this), String(checked) == $(this).attr('data-checked'));
        });
        var animations = $('input[name=animations]:checked', $modal).val() != 'false';
        var motion = !animations ? 'none' : ($('input[name=reduce_motion]', $modal).is(':checked') ? 'reduced' : 'full');
        $('.NB-pref-field-card[data-motion]', $modal).each(function () {
            mark($(this), $(this).attr('data-motion') == motion);
        });
    },

    select_preferences: function () {
        var $modal = this.$modal;
        this.update_theme_chooser();
        $('select[name=language]', $modal).val(NEWSBLUR.language_preference || 'auto');

        if (NEWSBLUR.Preferences.timezone) {
            $('select[name=timezone] option', $modal).each(function () {
                if ($(this).val() == NEWSBLUR.Preferences.timezone) {
                    $(this).prop('selected', true);
                    return false;
                }
            });
        }

        $('select[name=default_folder] option', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.default_folder) {
                $(this).prop('selected', true);
                return false;
            }
        });
        $('input[name=story_layout]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.story_layout) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=default_view]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.default_view) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=new_window]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.new_window) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=feed_order]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.feed_order) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=ssl]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.ssl) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=autoopen_folder]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.autoopen_folder) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=title_counts]', $modal).each(function () {
            if (NEWSBLUR.Preferences.title_counts) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_global_shared_stories]', $modal).each(function () {
            if (NEWSBLUR.Preferences.show_global_shared_stories) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_infrequent_site_stories]', $modal).each(function () {
            if (NEWSBLUR.Preferences.show_infrequent_site_stories) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_widely_read_stories]', $modal).each(function () {
            if (NEWSBLUR.Preferences.show_widely_read_stories) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_long_reads]', $modal).each(function () {
            if (NEWSBLUR.Preferences.show_long_reads) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_good_reads]', $modal).each(function () {
            if (NEWSBLUR.Preferences.show_good_reads) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=youtube_captions]', $modal).each(function () {
            if (NEWSBLUR.Preferences.youtube_captions) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=open_feed_action]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.open_feed_action) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_discover]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.show_discover) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=disable_social]', $modal).each(function () {
            if ($(this).val() == "" + (NEWSBLUR.Preferences.disable_social || false)) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=mark_read_on_scroll_titles]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.mark_read_on_scroll_titles) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=realtime_new_stories]', $modal).each(function () {
            if ($(this).val() == "" + (NEWSBLUR.Preferences.realtime_new_stories !== false)) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=density]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.density) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_content_preview]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.show_content_preview) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=image_preview]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.image_preview) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=doubleclick_feed]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.doubleclick_feed) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=doubleclick_unread]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.doubleclick_unread) {
                $(this).prop('checked', true);
                return false;
            }
        });
        var mark_read_pref = NEWSBLUR.Preferences.mark_read_river_confirm;
        if (mark_read_pref === true) mark_read_pref = 'folders_only';
        else if (mark_read_pref === false) mark_read_pref = 'never';
        $('input[name=mark_read_river_confirm]', $modal).each(function () {
            if ($(this).val() == mark_read_pref) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=markread_nextfeed]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.markread_nextfeed) {
                $(this).prop('checked', true);
                return false;
            }
        });
        // Days of unread is now handled by setup_daysofunread_control
        $('input[name=read_story_delay]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.read_story_delay) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=truncate_story]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.truncate_story) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=animations]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.animations) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=reduce_motion]', $modal).prop('checked', NEWSBLUR.Preferences.reduce_motion === true || NEWSBLUR.Preferences.reduce_motion === 1);
        $('input[name=dateformat]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.dateformat) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=folder_counts]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.folder_counts) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_tooltips]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.show_tooltips) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=show_contextmenus]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.show_contextmenus) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=hide_public_comments]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.hide_public_comments) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=story_button_placement]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.story_button_placement) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=sticky_story_sideoptions]', $modal).prop('checked', !!NEWSBLUR.Preferences.sticky_story_sideoptions);
        this.update_story_sideoption_sticky_preference();
        _.each(["email", "save", "train", "share", "related", "ask_ai", "listen"], function (sideoption) {
            var sideoption_name = "show_sideoption_" + sideoption;
            $('input#NB-preference-story-sideoption-' + sideoption, $modal).prop('checked', NEWSBLUR.Preferences[sideoption_name]);
        });
        $('input[name=highlights]', $modal).each(function () {
            if ($(this).val() == "" + NEWSBLUR.Preferences.highlights) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=keyboard_verticalarrows]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.keyboard_verticalarrows) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=keyboard_horizontalarrows]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.keyboard_horizontalarrows) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=space_bar_action]', $modal).each(function () {
            if ($(this).val() == NEWSBLUR.Preferences.space_bar_action) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=arrow_scroll_spacing]', $modal).val(NEWSBLUR.Preferences.arrow_scroll_spacing);
        $('input[name=space_scroll_spacing]', $modal).val(NEWSBLUR.Preferences.space_scroll_spacing);

        var order = NEWSBLUR.Preferences['default_order'];
        var read_filter = NEWSBLUR.Preferences['default_read_filter'];
        $('.NB-preference-view-setting-order-oldest', $modal).toggleClass('NB-active', order == 'oldest');
        $('.NB-preference-view-setting-order-newest', $modal).toggleClass('NB-active', order != 'oldest');
        $('.NB-preference-view-setting-read-filter-unread', $modal).toggleClass('NB-active', read_filter == 'unread');
        $('.NB-preference-view-setting-read-filter-all', $modal).toggleClass('NB-active', read_filter != 'unread');

        var share_preferences = _.select(_.keys(NEWSBLUR.Preferences), function (p) {
            return p.indexOf('story_share') != -1;
        });
        _.each(share_preferences, function (share) {
            var share_name = share.match(/story_share_(.*)/)[1];
            $('input#NB-preference-story-share-' + share_name, $modal).prop('checked', NEWSBLUR.Preferences[share]);
        });

        this.setup_daysofunread_control();
        $(".NB-tangle-readstorydelay", $modal).slider({
            range: 'min',
            min: 1,
            max: 60,
            step: 1,
            value: NEWSBLUR.Preferences.read_story_delay > 0 ? NEWSBLUR.Preferences.read_story_delay : 1,
            slide: _.bind(this.slide_read_story_delay_slider, this)
        });
        $(".NB-tangle-arrowscrollspacing-control", $modal).slider({
            range: 'min',
            min: 20,
            max: 500,
            step: 20,
            value: NEWSBLUR.Preferences.arrow_scroll_spacing,
            slide: _.bind(this.slide_arrow_scroll_spacing_slider, this),
            disabled: !NEWSBLUR.Globals.is_premium
        });
        $(".NB-tangle-spacescrollspacing-control", $modal).slider({
            range: 'min',
            min: 10,
            max: 100,
            step: 10,
            value: NEWSBLUR.Preferences.space_scroll_spacing,
            slide: _.bind(this.slide_space_scroll_spacing_slider, this),
            disabled: !NEWSBLUR.Globals.is_premium
        });
        this.slide_read_story_delay_slider();
        this.slide_arrow_scroll_spacing_slider();
        this.slide_space_scroll_spacing_slider();

        // reader_preferences.js: Select clustering preferences
        var clustering_enabled = NEWSBLUR.Preferences.story_clustering;
        if (clustering_enabled === undefined || clustering_enabled === null) {
            clustering_enabled = true;
        }
        $('input[name=story_clustering][value=' + !!clustering_enabled + ']', $modal).prop('checked', true);

        var cluster_mark_read = NEWSBLUR.Globals.is_archive && NEWSBLUR.Preferences.cluster_mark_read;
        $('input[name=cluster_mark_read]', $modal).prop('checked', !!cluster_mark_read);

        var briefing_enabled = NEWSBLUR.Preferences.briefing_enabled;
        if (briefing_enabled === undefined || briefing_enabled === null) {
            briefing_enabled = true;
        }
        $('input[name=briefing_enabled][value=' + !!briefing_enabled + ']', $modal).prop('checked', true);
    },

    // ===================
    // = Days of Unread  =
    // ===================

    setup_daysofunread_control: function () {
        var $options = $('.NB-daysofunread-option', this.$modal);
        var $slider = $('.NB-daysofunread-slider', this.$modal);

        // Check if user is Archive tier
        if (!NEWSBLUR.Globals.is_archive) {
            $slider.prop('disabled', true);
            $('.NB-preference-daysofunread-control', this.$modal).addClass('NB-disabled');
        }

        // Get current preference and system default
        var days_of_unread = NEWSBLUR.Globals.is_archive ?
            NEWSBLUR.Preferences.days_of_unread :
            NEWSBLUR.Globals.default_days_of_unread;
        var system_default = NEWSBLUR.Globals.default_days_of_unread;

        // Determine mode: default (0), never (9999), or days
        var mode = 'days';
        var slider_value = days_of_unread;
        var display_days = days_of_unread;

        if (!days_of_unread || days_of_unread === 0) {
            // Use system default
            mode = 'default';
            slider_value = system_default >= 9999 ? 400 : system_default;
            display_days = system_default;
        } else if (days_of_unread >= 9999) {
            mode = 'never';
            slider_value = 400;
            display_days = 0;
        }

        // Update segmented control selection
        $options.removeClass('NB-active');
        $('.NB-daysofunread-' + mode, this.$modal).addClass('NB-active');

        // Update slider value and display
        $slider.val(slider_value);
        this.update_daysofunread_status_text(mode, display_days);
        this.update_daysofunread_slider_gradient($slider, slider_value);
    },

    handle_daysofunread_option_click: function ($option) {
        if (!NEWSBLUR.Globals.is_archive) {
            this.flash_daysofunread_upgrade_notice();
            return;
        }

        var value = $option.data('value');
        var $options = $('.NB-daysofunread-option', this.$modal);
        var $slider = $('.NB-daysofunread-slider', this.$modal);
        var system_default = NEWSBLUR.Globals.default_days_of_unread;

        // Update selection
        $options.removeClass('NB-active');
        $option.addClass('NB-active');

        var slider_value;
        if (value === 'default') {
            // Use system default
            slider_value = system_default >= 9999 ? 400 : system_default;
            this.update_daysofunread_status_text('default', system_default);
        } else if (value === 'never') {
            slider_value = 400;
            this.update_daysofunread_status_text('never', 0);
        } else {
            // Days mode - use current slider value, or restore from preference if in "never" zone
            var current_slider = parseInt($slider.val(), 10);
            if (current_slider > 365) {
                // Restore from original preference if it was a valid days value
                var original_pref = NEWSBLUR.Preferences.days_of_unread;
                slider_value = (original_pref && original_pref > 0 && original_pref <= 365) ? original_pref : 30;
            } else {
                slider_value = current_slider;
            }
            this.update_daysofunread_status_text('days', slider_value);
        }

        $slider.val(slider_value);
        this.update_daysofunread_slider_gradient($slider, slider_value);
        this.enable_save();
    },

    on_daysofunread_slider_input: function () {
        var $slider = $('.NB-daysofunread-slider', this.$modal);
        var slider_val = parseInt($slider.val(), 10);
        var $options = $('.NB-daysofunread-option', this.$modal);
        var system_default = NEWSBLUR.Globals.default_days_of_unread;

        var is_never = slider_val > 365;
        var is_default = !is_never && slider_val === system_default;

        this.update_daysofunread_slider_gradient($slider, slider_val);

        if (!NEWSBLUR.Globals.is_archive) {
            this.flash_daysofunread_upgrade_notice();
            return;
        }

        // Auto-select appropriate option based on slider position
        $options.removeClass('NB-active');
        if (is_never) {
            $('.NB-daysofunread-never', this.$modal).addClass('NB-active');
            this.update_daysofunread_status_text('never', 0);
        } else if (is_default) {
            // Slider matches system default - switch back to Default mode
            $('.NB-daysofunread-default', this.$modal).addClass('NB-active');
            this.update_daysofunread_status_text('default', system_default);
        } else {
            $('.NB-daysofunread-days', this.$modal).addClass('NB-active');
            this.update_daysofunread_status_text('days', slider_val);
        }
    },

    handle_daysofunread_slider_change: function () {
        this.on_daysofunread_slider_input();
        this.enable_save();
    },

    update_daysofunread_slider_gradient: function ($slider, value) {
        var min = parseInt($slider.attr('min'), 10) || 1;
        var max = parseInt($slider.attr('max'), 10) || 400;
        var percent = ((value - min) / (max - min)) * 100;

        // Create gradient: blue for filled, light gray for unfilled, darker gray for "never" zone (366-400)
        var never_zone_start = ((365 - min) / (max - min)) * 100;

        if (value > 365) {
            // In never zone - all blue up to never zone, then purple for never
            $slider.css('background', 'linear-gradient(to right, #4a90d9 0%, #4a90d9 ' + never_zone_start + '%, #8b5cf6 ' + never_zone_start + '%, #8b5cf6 100%)');
        } else {
            // Normal days zone
            $slider.css('background', 'linear-gradient(to right, #4a90d9 0%, #4a90d9 ' + percent + '%, #e0e0e0 ' + percent + '%, #e0e0e0 ' + never_zone_start + '%, #d4d0e8 ' + never_zone_start + '%, #d4d0e8 100%)');
        }
    },

    update_daysofunread_status_text: function (mode, days) {
        var $slider_value = $('.NB-daysofunread-slider-value', this.$modal);
        var html = '';
        if (mode === 'default') {
            if (days >= 9999) {
                html = gettext('Using default: stories will <b>never</b> be auto-marked as read');
            } else {
                html = interpolate(ngettext("Using default: <b>%(days)s day</b>", "Using default: <b>%(days)s days</b>", days), {days: days}, true);
            }
        } else if (mode === 'never') {
            html = gettext('Stories will <b>never</b> be auto-marked as read');
        } else {
            html = interpolate(ngettext("Stories marked as read at <b>%(days)s day</b>", "Stories marked as read at <b>%(days)s days</b>", days), {days: days}, true);
        }
        $slider_value.html(html);
    },

    flash_daysofunread_upgrade_notice: function () {
        var $notice = $('.NB-daysofunread-upgrade-notice', this.$modal);
        $notice.addClass('NB-flash');
        setTimeout(function () {
            $notice.removeClass('NB-flash');
        }, 600);
    },

    // reader_preferences.js: Fills the text on both sides of a slider from one
    // translated sentence, such as "After %(slider)s %(count)s seconds.", so a
    // translation can put the slider anywhere. The slider element itself never
    // moves, which keeps a drag in progress working while the numbers change.
    set_slider_sentence: function ($slider, message, values) {
        var parts = message.split('%(slider)s');
        $slider.siblings('.NB-preference-slider-before').text(interpolate(parts[0], values, true));
        $slider.siblings('.NB-preference-slider-after').text(interpolate(parts.slice(1).join(''), values, true));
    },

    slide_read_story_delay_slider: function (e, ui) {
        var value = (ui && ui.value) ||
            (NEWSBLUR.Preferences.read_story_delay > 0 ? NEWSBLUR.Preferences.read_story_delay : 1);
        this.set_slider_sentence($(".NB-tangle-readstorydelay", this.$modal),
            ngettext("After %(slider)s %(count)s second.", "After %(slider)s %(count)s seconds.", value), {count: value});
        if (NEWSBLUR.Preferences.read_story_delay > 0 || ui) {
            // reader_preferences.js: the "After a delay" card is the one read_story_delay choice with
            // a positive value, and the slider sets how many seconds that value is.
            $('input[name=read_story_delay]', this.$modal).filter(function () {
                return parseInt($(this).val(), 10) > 0;
            }).prop('checked', true).val(value);
            if (ui) {
                this.enable_save();
            }
        }
    },

    slide_arrow_scroll_spacing_slider: function (e, ui) {
        var value = (ui && ui.value) || NEWSBLUR.Preferences.arrow_scroll_spacing;
        if (!NEWSBLUR.Globals.is_premium) {
            value = NEWSBLUR.Preferences.arrow_scroll_spacing;
        }
        this.set_slider_sentence($(".NB-tangle-arrowscrollspacing-control", this.$modal),
            gettext("Scroll up/down in story by %(slider)s %(pixels)spx."), {pixels: value});
        $("input[name=arrow_scroll_spacing]", this.$modal).val(value);
        if (NEWSBLUR.Preferences.keyboard_verticalarrows == 'scroll' || ui) {
            $('input[name=keyboard_verticalarrows][value=scroll]', this.$modal).prop('checked', true);
            if (ui) {
                this.enable_save();
            }
        }
    },

    slide_space_scroll_spacing_slider: function (e, ui) {
        var value = (ui && ui.value) || NEWSBLUR.Preferences.space_scroll_spacing;
        if (!NEWSBLUR.Globals.is_premium) {
            value = NEWSBLUR.Preferences.space_scroll_spacing;
        }
        this.set_slider_sentence($(".NB-tangle-spacescrollspacing-control", this.$modal),
            gettext("Page down by %(slider)s %(percent)s of the screen"), {percent: value + "%"});
        $("input[name=space_scroll_spacing]", this.$modal).val(value);
        if (ui) {
            this.enable_save();
        }
    },

    serialize_preferences: function () {
        var preferences = {};

        $('input[type=radio]:checked, select', this.$modal).each(function () {
            var name = $(this).attr('name');
            var preference = preferences[name] = $(this).val();
            if (preference == 'true') preferences[name] = true;
            else if (preference == 'false') preferences[name] = false;
        });
        $('input[type=checkbox]', this.$modal).each(function () {
            preferences[$(this).attr('name')] = $(this).is(':checked');
        });
        // reader_preferences.js: Enforce archive-only restriction on cluster_mark_read
        if (!NEWSBLUR.Globals.is_archive) {
            preferences['cluster_mark_read'] = false;
        }
        $('input[type=hidden]', this.$modal).each(function () {
            preferences[$(this).attr('name')] = $(this).val();
        });
        preferences['default_order'] = $('.NB-preference-view-setting-order li.NB-active', this.$modal).hasClass('NB-preference-view-setting-order-oldest') ? 'oldest' : 'newest';
        preferences['default_read_filter'] = $('.NB-preference-view-setting-read-filter li.NB-active', this.$modal).hasClass('NB-preference-view-setting-read-filter-unread') ? 'unread' : 'all';

        // Handle days_of_unread: check which option is selected
        var $default_option = $('.NB-daysofunread-default.NB-active', this.$modal);
        var $slider = $('.NB-daysofunread-slider', this.$modal);
        if ($default_option.length) {
            // "Default" is selected - save 0 to indicate use system default
            preferences['days_of_unread'] = 0;
        } else if ($slider.length) {
            // Days or Never mode - values 366-400 map to 9999 (never)
            var slider_val = parseInt($slider.val(), 10);
            preferences['days_of_unread'] = slider_val > 365 ? 9999 : slider_val;
        }

        return preferences;
    },

    // reader_preferences.js: there is no Save button. A change is saved a moment after it is made,
    // and only the preferences that differ from the last save are sent. The form is read here,
    // while the dialog is still on the page, and waits in pending_form if a save is out.
    save_preferences: function () {
        clearTimeout(this.save_timer);
        this.save_timer = null;
        this.pending_form = this.serialize_preferences();
        this.send_pending_preferences();
    },

    // reader_preferences.js: one save is out at a time. A change made meanwhile is compared with
    // what that save stored, so a setting put back while its first change is still on the way is
    // sent after it. Compared with the form as it was before that save, it would look unchanged.
    send_pending_preferences: function () {
        var self = this;
        if (this.saving || !this.pending_form) return;
        var form = this.pending_form;
        this.pending_form = null;
        var original = this.original_preferences || {};
        var changed = {};
        _.each(form, function (value, name) {
            if (!_.isEqual(value, original[name])) changed[name] = value;
        });
        if (_.isEmpty(changed)) {
            this.finish_saving('saved');
            return;
        }
        $('.NB-preference-error', this.$modal).text('');
        this.set_status('saving');
        this.saving = true;

        this.model.save_preferences(changed, function (data) {
            self.saving = false;
            // reader_preferences.js: common/assetmodel.js make_request answers a request that failed
            // with a message and no code, so only a code that is not negative means it was saved.
            var saved = !!data && _.isNumber(data.code) && data.code >= 0;
            if (saved) {
                self.original_preferences = form;
                if ('language' in changed) {
                    self.reload_when_saved = true;
                } else {
                    self.apply_saved_preferences(changed);
                }
            }
            if (self.pending_form) {
                self.send_pending_preferences();
            } else {
                // reader_preferences.js: what failed still differs from original_preferences, so
                // the next change or closing the dialog sends it again.
                self.finish_saving(saved ? 'saved' : 'error');
            }
        });
    },

    // reader_preferences.js: a new language needs the page loaded again, once nothing is left to send.
    // A change that failed to save keeps the page, so its error shows and it can be sent again.
    finish_saving: function (status) {
        if (this.reload_when_saved && status == 'saved') {
            window.location.reload();
            return;
        }
        this.set_status(status);
    },

    apply_saved_preferences: function (changed) {
        NEWSBLUR.reader.switch_feed_view_unread_view();
        NEWSBLUR.reader.apply_story_styling(true);
        NEWSBLUR.reader.apply_tipsy_titles();
        NEWSBLUR.reader.adjust_for_narrow_window();
        NEWSBLUR.reader.add_body_classes();
        NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
        NEWSBLUR.app.sidebar_header.count();
        if ('feed_order' in changed || 'folder_counts' in changed) {
            NEWSBLUR.app.feed_list.make_feeds();
            NEWSBLUR.app.feed_list.make_social_feeds();
        }
        if (_.any(['show_global_shared_stories', 'show_infrequent_site_stories', 'show_widely_read_stories',
                   'show_long_reads', 'show_good_reads', 'briefing_enabled'], function (name) { return name in changed; })) {
            NEWSBLUR.app.feed_list.toggle_filter_feeds();
        }
        if ('ssl' in changed) {
            NEWSBLUR.reader.check_and_load_ssl();
        }
        if ('days_of_unread' in changed) {
            NEWSBLUR.reader.force_feeds_refresh();
        }
        if (changed['realtime_new_stories'] === false) {
            // reader_preferences.js: turning the pill off drops the stories it was holding.
            NEWSBLUR.reader.clear_realtime_new_stories();
        }
    },

    set_status: function (status) {
        var messages = {
            'saving': gettext('Saving...'),
            'saved': gettext('Saved'),
            'error': gettext('That change could not be saved')
        };
        $('.NB-preferences-status', this.$modal).text(messages[status]).addClass('NB-visible')
            .toggleClass('NB-saved', status == 'saved').toggleClass('NB-error', status == 'error');
    },

    close_and_load_account: function () {
        this.close(function () {
            NEWSBLUR.reader.open_account_modal();
        });
    },

    close_and_load_account_emails: function () {
        this.close(function () {
            NEWSBLUR.reader.open_account_modal({ 'animate_email': true });
        });
    },

    close_and_load_feedchooser: function () {
        this.close(function () {
            NEWSBLUR.reader.open_feedchooser_modal();
        });
    },

    close_and_load_premium: function (highlight_feature) {
        this.close(function () {
            NEWSBLUR.reader.open_premium_upgrade_modal({ highlight_feature: highlight_feature });
        });
    },

    flash_clustering_upgrade_notice: function () {
        var $notice = $('.NB-clustering-mark-read-option .NB-premium-archive-upgrade-notice', this.$modal);
        $notice.addClass('NB-flash');
        setTimeout(function () {
            $notice.removeClass('NB-flash');
        }, 600);
    },

    change_view_setting: function (view, setting) {
        if (view == 'order') {
            $('.NB-preference-view-setting-order-oldest').toggleClass('NB-active', setting == 'oldest');
            $('.NB-preference-view-setting-order-newest').toggleClass('NB-active', setting != 'oldest');
        } else if (view == 'read_filter') {
            $('.NB-preference-view-setting-read-filter-unread').toggleClass('NB-active', setting == 'unread');
            $('.NB-preference-view-setting-read-filter-all').toggleClass('NB-active', setting != 'unread');
        }

        this.enable_save();
    },

    update_story_sideoption_sticky_preference: function () {
        var placement = $('input[name=story_button_placement]:checked', this.$modal).val();
        $('.NB-preference-story-sideoption-sticky', this.$modal).toggle(placement == 'right');
    },

    clear_overrides: function (type) {
        var $sublabel = $('.NB-clear-overrides-' + type, this.$modal);
        $sublabel.text(gettext('Resetting...')).removeClass('NB-splash-link');
        NEWSBLUR.assets.clear_view_settings(type, _.bind(function (data) {
            $sublabel.text(interpolate(ngettext("Cleared %(count)s override.", "Cleared %(count)s overrides.", data.removed), {count: data.removed}, true));
        }, this));
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function ($t, $p) {
            e.preventDefault();
            var newtab = $t.attr('class').match(/NB-modal-tab-(\w+)/)[1];
            self.resize_modal();
            self.switch_tab(newtab);
        });
        $.targetIs(e, { tagSelector: '.NB-pref-field-card' }, function ($t, $p) {
            e.preventDefault();
            var motion = $t.attr('data-motion');
            if (motion) {
                $('input[name=animations][value=' + (motion == 'none' ? 'false' : 'true') + ']', self.$modal).prop('checked', true);
                $('input[name=reduce_motion]', self.$modal).prop('checked', motion == 'reduced');
            } else {
                $('input[name=' + $t.attr('data-field') + ']', self.$modal).prop('checked', $t.attr('data-checked') == 'true');
            }
            self.update_field_cards();
            self.enable_save();
        });

        $.targetIs(e, { tagSelector: '.NB-add-url-submit' }, function ($t, $p) {
            e.preventDefault();

            self.save_preferences();
        });
        $.targetIs(e, { tagSelector: '.NB-link-account-email-settings' }, function ($t, $p) {
            e.preventDefault();

            self.close_and_load_account_emails();
        });
        $.targetIs(e, { tagSelector: '.NB-link-account-preferences' }, function ($t, $p) {
            e.preventDefault();

            self.close_and_load_account();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-cancel' }, function ($t, $p) {
            e.preventDefault();

            self.close();
        });
        $.targetIs(e, { tagSelector: '.NB-premium-link' }, function ($t, $p) {
            e.preventDefault();
            // reader_preferences.js: The archive notices carry a data-feature naming
            // the tier line to highlight in the upgrade modal.
            self.close_and_load_premium($t.data('feature'));
        });
        $.targetIs(e, { tagSelector: '.NB-clustering-mark-read-option.NB-disabled' }, function ($t, $p) {
            e.preventDefault();
            self.flash_clustering_upgrade_notice();
        });
        $.targetIs(e, { tagSelector: '.NB-preference-view-setting-order li' }, function ($t, $p) {
            e.preventDefault();
            var order = $t.hasClass('NB-preference-view-setting-order-oldest') ? 'oldest' : 'newest';
            self.change_view_setting('order', order);
        });
        $.targetIs(e, { tagSelector: '.NB-preference-view-setting-read-filter li' }, function ($t, $p) {
            e.preventDefault();
            var read_filter = $t.hasClass('NB-preference-view-setting-read-filter-unread') ? 'unread' : 'all';
            self.change_view_setting('read_filter', read_filter);
        });
        $.targetIs(e, { tagSelector: '.NB-clear-overrides-view' }, function ($t, $p) {
            e.preventDefault();
            self.clear_overrides('view');
        });
        $.targetIs(e, { tagSelector: '.NB-clear-overrides-order' }, function ($t, $p) {
            e.preventDefault();
            self.clear_overrides('order');
        });
        $.targetIs(e, { tagSelector: '.NB-clear-overrides-layout' }, function ($t, $p) {
            e.preventDefault();
            self.clear_overrides('layout');
        });
        $.targetIs(e, { tagSelector: '.NB-daysofunread-option' }, function ($t, $p) {
            e.preventDefault();
            self.handle_daysofunread_option_click($t);
        });
        $.targetIs(e, { tagSelector: '.NB-theme-choice' }, function ($t, $p) {
            e.preventDefault();
            NEWSBLUR.reader.switch_theme($t.data('theme'));
            self.update_theme_chooser();
        });
        $.targetIs(e, { tagSelector: '.NB-theme-auto-option' }, function ($t, $p) {
            e.preventDefault();
            NEWSBLUR.reader.switch_auto_theme($t.data('theme'));
            self.update_theme_chooser();
        });
    },

    handle_change: function () {
        var self = this;

        $('input[type=radio],input[type=checkbox],select', this.$modal).bind('change', _.bind(this.enable_save, this));
        $('input[name=story_button_placement]', this.$modal).bind('change', function () {
            self.update_story_sideoption_sticky_preference();
            self.resize_modal();
        });

        // reader_preferences.js: these cards are not form fields, so give them the keys a radio has.
        $('.NB-theme-choice, .NB-theme-auto-option, .NB-pref-field-card, li.NB-pref-card', this.$modal).bind('keydown', function (e) {
            if (e.which == 13 || e.which == 32) {
                e.preventDefault();
                $(this).click();
            }
        });
        this.watch_system_theme();
        // reader_preferences.js: a card's tooltip (reader_utils.js show_tip) would be left behind
        // when the tab scrolls its card away.
        $('.NB-tab', this.$modal).bind('scroll', function () {
            NEWSBLUR.utils.hide_tip();
        });

        // Days of unread slider change handler
        $('.NB-daysofunread-slider', this.$modal).bind('change', function () {
            self.handle_daysofunread_slider_change();
        });

        // Days of unread slider input handler (real-time)
        $('.NB-daysofunread-slider', this.$modal).bind('input', function () {
            self.on_daysofunread_slider_input();
        });
    },

    // reader_preferences.js: every control calls this when it changes. The short wait gathers a
    // dragged slider or a quick run of clicks into one request.
    enable_save: function () {
        this.set_status('saving');
        clearTimeout(this.save_timer);
        this.save_timer = setTimeout(_.bind(this.save_preferences, this), 400);
    }

});
