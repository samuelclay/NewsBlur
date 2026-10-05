// Preferences:
//  - Feed sort order
//  - New window behavior

NEWSBLUR.ReaderPreferences = function (options) {
    var defaults = {
        width: 700
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
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-general' }, gettext('General')),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-feeds' }, gettext('Feeds')),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-stories' }, gettext('Stories')),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-keyboard' }, gettext('Keyboard'))
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                gettext('Preferences'),
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('form', { className: 'NB-preferences-form' }, [
                $.make('div', { className: 'NB-tab NB-tab-general NB-active' }, [
                    $.make('div', { className: 'NB-preference' }, [
                        $.make('label', { className: 'NB-preference-label', 'for': 'NB-preference-language' }, gettext('Language')),
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('select', { id: 'NB-preference-language', name: 'language' },
                                [$.make('option', { value: 'auto' }, gettext('Automatic (device language)'))].concat(
                                    NEWSBLUR.languages.map(function (language) {
                                        return $.make('option', { value: language[0] }, language[1]);
                                    })
                                ))
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-daysofunread' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
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
                            (!NEWSBLUR.Globals.is_archive && $.make('a', { className: 'NB-premium-archive-upgrade-notice NB-premium-link', href: '#', 'data-feature': 'stay-unread' }, [
                                $.make('span', { className: 'NB-archive-badge' }, gettext('Premium Archive')),
                                gettext(' Customize days of unreads')
                            ]))
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Days of unreads')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('select', { id: 'NB-preference-timezone-1', name: 'timezone' }, [
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
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-dateformat-1', type: 'radio', name: 'dateformat', value: '12' }),
                                $.make('label', { 'for': 'NB-preference-dateformat-1' }, [
                                    gettext('Use 12-hour clock')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-dateformat-2', type: 'radio', name: 'dateformat', value: '24' }),
                                $.make('label', { 'for': 'NB-preference-dateformat-2' }, [
                                    gettext('Use 24-hour clock')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Timezone')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showunreadcountsintitle' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showunreadcountsintitle-1', type: 'checkbox', name: 'title_counts', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showunreadcountsintitle-1' }, [
                                    gettext('Show unread counts in the window title')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Window title')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showglobalsharedstories' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showglobalsharedstories-1', type: 'checkbox', name: 'show_global_shared_stories', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showglobalsharedstories-1' }, [
                                    gettext('Show Global Shared Stories')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showinfrequentsitestories-1', type: 'checkbox', name: 'show_infrequent_site_stories', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showinfrequentsitestories-1' }, [
                                    gettext('Show Infrequent Site Stories')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showwidelyreadstories-1', type: 'checkbox', name: 'show_widely_read_stories', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showwidelyreadstories-1' }, [
                                    gettext('Show Widely Read Stories')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showlongreads-1', type: 'checkbox', name: 'show_long_reads', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showlongreads-1' }, [
                                    gettext('Show Long Reads')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showgoodreads-1', type: 'checkbox', name: 'show_good_reads', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showgoodreads-1' }, [
                                    gettext('Show Good Reads')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Special Folders')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-autoopenfolder' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-autoopenfolder-1', type: 'radio', name: 'autoopen_folder', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-autoopenfolder-1' }, [
                                    gettext('Show the dashboard when loading NewsBlur')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-autoopenfolder-2', type: 'radio', name: 'autoopen_folder', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-autoopenfolder-2' }, [
                                    this.make_autoopen_folders()
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Default folder')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-animations' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-animations-1', type: 'radio', name: 'animations', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-animations-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/arrow_in.png' }),
                                    gettext('Show all animations')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-animations-2', type: 'radio', name: 'animations', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-animations-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/arrow_right.png' }),
                                    gettext('Jump immediately with no animations')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Animations')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-feedorder' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-feedorder-1', type: 'radio', name: 'feed_order', value: 'ALPHABETICAL' }),
                                $.make('label', { 'for': 'NB-preference-feedorder-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/pilcrow.png' }),
                                    gettext('Alphabetical')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-feedorder-2', type: 'radio', name: 'feed_order', value: 'MOSTUSED' }),
                                $.make('label', { 'for': 'NB-preference-feedorder-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/report_user.png' }),
                                    gettext('Most used at top, then alphabetical')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Site sidebar order')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-folder-counts' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-folder-counts-1', type: 'radio', name: 'folder_counts', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-folder-counts-1' }, [
                                    gettext('Only show counts on collapsed folders')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-folder-counts-2', type: 'radio', name: 'folder_counts', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-folder-counts-2' }, [
                                    gettext('Always show unread counts on folders')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Folder unread counts')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-tooltips' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-tooltips-1', type: 'radio', name: 'show_tooltips', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-tooltips-1' }, [
                                    gettext('Show tooltips')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-tooltips-2', type: 'radio', name: 'show_tooltips', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-tooltips-2' }, [
                                    gettext('Don\'t bother showing tooltips')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Tooltips'),
                            $.make('div', { className: 'tipsy tipsy-n' }, [
                                $.make('div', { className: 'tipsy-arrow' }),
                                $.make('div', { className: 'tipsy-inner' }, gettext('Tooltips like this'))
                            ]).css({
                                'display': 'block',
                                'top': 24,
                                'left': -5
                            })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-contextmenu' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-contextmenus-1', type: 'radio', name: 'show_contextmenus', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-contextmenus-1' }, [
                                    gettext('Open the feed and story title menu')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-contextmenus-2', type: 'radio', name: 'show_contextmenus', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-contextmenus-2' }, [
                                    gettext('Use the native browser context menu')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Right-clicking'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('Folders, feeds, and story titles'))
                        ])
                    ]),
                    ($.make('div', { className: 'NB-preference NB-preference-briefing-enabled' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-social-card NB-social-card-enable' }, [
                                $.make('input', { id: 'NB-preference-briefing-enabled-1', type: 'radio', name: 'briefing_enabled', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-briefing-enabled-1', className: 'NB-social-card-content' }, [
                                    $.make('span', { className: 'NB-social-card-title' }, gettext('Enable daily briefings')),
                                    $.make('ul', { className: 'NB-social-features-list' }, [
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('AI-curated summary of your top stories')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Customizable writing style and length')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Scheduled delivery (daily or twice daily)')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Choose which feeds to include')])
                                    ])
                                ])
                            ]),
                            $.make('div', { className: 'NB-social-card NB-social-card-disable' }, [
                                $.make('input', { id: 'NB-preference-briefing-enabled-2', type: 'radio', name: 'briefing_enabled', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-briefing-enabled-2', className: 'NB-social-card-content' }, [
                                    $.make('span', { className: 'NB-social-card-title' }, gettext('Disable daily briefings')),
                                    $.make('span', { className: 'NB-social-card-desc' }, gettext('Turn off automatic briefing generation'))
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Daily Briefing')
                        ])
                    ])),
                    ($.make('div', { className: 'NB-preference NB-preference-clustering-enabled' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-social-card NB-social-card-enable' }, [
                                $.make('input', { id: 'NB-preference-clustering-enabled-1', type: 'radio', name: 'story_clustering', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-clustering-enabled-1', className: 'NB-social-card-content' }, [
                                    $.make('span', { className: 'NB-social-card-title' }, gettext('Enable story clustering')),
                                    $.make('ul', { className: 'NB-social-features-list' }, [
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Group duplicate stories across your feeds')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('See which feeds cover the same story')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Reduce clutter in your river of stories')])
                                    ]),
                                    $.make('div', { className: 'NB-clustering-mark-read-option' + (!NEWSBLUR.Globals.is_archive ? ' NB-disabled' : '') }, [
                                        $.make('input', { id: 'NB-preference-cluster-mark-read', type: 'checkbox', name: 'cluster_mark_read', value: 'true', disabled: !NEWSBLUR.Globals.is_archive }),
                                        $.make('label', { 'for': 'NB-preference-cluster-mark-read' }, gettext('Mark duplicates as read')),
                                        (!NEWSBLUR.Globals.is_archive && $.make('a', { href: '#', className: 'NB-premium-archive-upgrade-notice NB-premium-link', 'data-feature': 'clustering' }, [
                                            $.make('span', { className: 'NB-archive-badge' }, gettext('Premium Archive'))
                                        ]))
                                    ])
                                ])
                            ]),
                            $.make('div', { className: 'NB-social-card NB-social-card-disable' }, [
                                $.make('input', { id: 'NB-preference-clustering-enabled-2', type: 'radio', name: 'story_clustering', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-clustering-enabled-2', className: 'NB-social-card-content' }, [
                                    $.make('span', { className: 'NB-social-card-title' }, gettext('Disable story clustering')),
                                    $.make('span', { className: 'NB-social-card-desc' }, gettext('Show every story individually without grouping'))
                                ])
                            ]),
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Story Clustering'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('Groups similar stories from different feeds'))
                        ])
                    ])),
                    $.make('div', { className: 'NB-preference NB-preference-opml' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('a', { className: 'NB-splash-link', href: NEWSBLUR.URLs['opml-export'] }, gettext('Download OPML'))
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Backup your sites'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('Download this XML file as a backup'))
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-email-settings' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('a', { className: 'NB-splash-link NB-link-account-email-settings', href: '#' }, gettext('Manage email settings')),
                            $.make('div', { className: 'NB-preference-email-status' }, gettext('You are unsubscribed from all NewsBlur emails')).toggle(!NEWSBLUR.assets.preference('send_emails'))
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Emails'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('Found in the Account dialog'))
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-feeds' }, [
                    $.make('div', { className: 'NB-preference NB-preference-layout' }, [
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "" }, [
                                $.make('label', { 'for': 'NB-preference-layout-1' }, [
                                    $.make('input', { id: 'NB-preference-layout-1', type: 'radio', name: 'story_layout', value: 'full' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_full_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, gettext("Full"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-2' }, [
                                    $.make('input', { id: 'NB-preference-layout-2', type: 'radio', name: 'story_layout', value: 'split' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_split_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, gettext("Split"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-3' }, [
                                    $.make('input', { id: 'NB-preference-layout-3', type: 'radio', name: 'story_layout', value: 'list' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_list_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, gettext("List"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-4' }, [
                                    $.make('input', { id: 'NB-preference-layout-4', type: 'radio', name: 'story_layout', value: 'grid' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_grid_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, gettext("Grid"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-5' }, [
                                    $.make('input', { id: 'NB-preference-layout-5', type: 'radio', name: 'story_layout', value: 'magazine' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_magazine_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, gettext("Magazine"))
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Default layout'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('You can override this on a per-site basis.')),
                            $.make('div', { className: 'NB-clear-overrides-layout NB-preference-sublabel-link NB-splash-link' }, gettext("Clear all overrides"))
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-view' }, [
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "NB-view-setting-original" }, [
                                $.make('label', { 'for': 'NB-preference-view-1' }, [
                                    $.make('input', { id: 'NB-preference-view-1', type: 'radio', name: 'default_view', value: 'page' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_original_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, gettext("Original"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-2' }, [
                                    $.make('input', { id: 'NB-preference-view-2', type: 'radio', name: 'default_view', value: 'feed' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_feed_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, gettext("Feed"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-3' }, [
                                    $.make('input', { id: 'NB-preference-view-3', type: 'radio', name: 'default_view', value: 'text' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_text_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, gettext("Text"))
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-4' }, [
                                    $.make('input', { id: 'NB-preference-view-4', type: 'radio', name: 'default_view', value: 'story' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_story_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, gettext("Story"))
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Default view'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('You can override this on a per-site basis.')),
                            $.make('div', { className: 'NB-clear-overrides-view NB-preference-sublabel-link NB-splash-link' }, gettext("Clear all overrides"))
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-view-setting' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('ul', { className: 'segmented-control NB-preference-view-setting-order' }, [
                                $.make('li', { className: 'NB-preference-view-setting-order-newest NB-active' }, gettext('Newest first')),
                                $.make('li', { className: 'NB-preference-view-setting-order-oldest' }, gettext('Oldest'))
                            ]),
                            $.make('ul', { className: 'segmented-control NB-preference-view-setting-read-filter' }, [
                                $.make('li', { className: 'NB-preference-view-setting-read-filter-all  NB-active' }, gettext('All stories')),
                                $.make('li', { className: 'NB-preference-view-setting-read-filter-unread' }, gettext('Unread only'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Default story order'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('You can override this on a per-site and per-folder basis.')),
                            $.make('div', { className: 'NB-clear-overrides-order NB-preference-sublabel-link NB-splash-link' }, gettext("Clear all overrides"))
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-openfeedaction' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-openfeedaction-1', type: 'radio', name: 'open_feed_action', value: 'newest' }),
                                $.make('label', { 'for': 'NB-preference-openfeedaction-1' }, [
                                    gettext('Open the first story')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-openfeedaction-0', type: 'radio', name: 'open_feed_action', value: 0, checked: true }),
                                $.make('label', { 'for': 'NB-preference-openfeedaction-0' }, [
                                    gettext('Show all stories')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('When opening a site')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-markreadstoryscroll' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadstoryscroll-1', type: 'radio', name: 'mark_read_on_scroll_titles', value: "true" }),
                                $.make('label', { 'for': 'NB-preference-markreadstoryscroll-1' }, [
                                    gettext('Mark stories as read when scrolled past')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadstoryscroll-0', type: 'radio', name: 'mark_read_on_scroll_titles', value: "false" }),
                                $.make('label', { 'for': 'NB-preference-markreadstoryscroll-0' }, [
                                    gettext('Don\'t automatically mark stories as read')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Mark stories read on scroll')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-density' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-density-compact', type: 'radio', name: 'density', value: "compact" }),
                                $.make('label', { 'for': 'NB-preference-density-compact' }, [
                                    gettext('Compact spacing: more dense')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-density-comfortable', type: 'radio', name: 'density', value: "comfortable" }),
                                $.make('label', { 'for': 'NB-preference-density-comfortable' }, [
                                    gettext('Comfortable spacing: less dense')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Spacing between feeds and story titles')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showcontentpreview' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showcontentpreview-1', type: 'radio', name: 'show_content_preview', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-showcontentpreview-1' }, [
                                    gettext('Show a preview of the story')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showcontentpreview-0', type: 'radio', name: 'show_content_preview', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showcontentpreview-0' }, [
                                    gettext('Don\'t show a preview, only show the story title')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Story content preview')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showimagepreview' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-sl', type: 'radio', name: 'image_preview', value: "small-left" }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-sl' }, [
                                    gettext('Small image thumbnail on the left')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-sr', type: 'radio', name: 'image_preview', value: "small-right" }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-sr' }, [
                                    gettext('Small image thumbnail on the right')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-ll', type: 'radio', name: 'image_preview', value: "large-left" }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-ll' }, [
                                    gettext('Large image thumbnail on the left')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-lr', type: 'radio', name: 'image_preview', value: "large-right" }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-lr' }, [
                                    gettext('Large image thumbnail on the right')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-0', type: 'radio', name: 'image_preview', value: "none" }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-0' }, [
                                    gettext('Don\'t show a thumbnail')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Image preview')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-doubleclickfeed' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickfeed-1', type: 'radio', name: 'doubleclick_feed', value: 'open' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickfeed-1' }, [
                                    gettext('Open the site in a new window')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickfeed-0', type: 'radio', name: 'doubleclick_feed', value: 'open_and_read' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickfeed-0' }, [
                                    gettext('Open the site in a new window and mark it as read')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickfeed-2', type: 'radio', name: 'doubleclick_feed', value: 'ignore' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickfeed-2' }, [
                                    gettext('Don\'t do anything on double-clicks')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Double-clicking a site')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-doubleclickunread' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickunread-1', type: 'radio', name: 'doubleclick_unread', value: 'markread' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickunread-1' }, [
                                    gettext('Mark the site as read')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickunread-0', type: 'radio', name: 'doubleclick_unread', value: "ignore" }),
                                $.make('label', { 'for': 'NB-preference-doubleclickunread-0' }, [
                                    gettext('Don\'t do anything on double-clicks')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Double-clicking an unread count')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-markreadconfirm' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadconfirm-1', type: 'radio', name: 'mark_read_river_confirm', value: 'feeds_folders' }),
                                $.make('label', { 'for': 'NB-preference-markreadconfirm-1' }, [
                                    gettext('Show confirmation when marking feeds or folders as read')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadconfirm-2', type: 'radio', name: 'mark_read_river_confirm', value: 'folders_only' }),
                                $.make('label', { 'for': 'NB-preference-markreadconfirm-2' }, [
                                    gettext('Show confirmation only when marking folders as read')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadconfirm-0', type: 'radio', name: 'mark_read_river_confirm', value: 'never' }),
                                $.make('label', { 'for': 'NB-preference-markreadconfirm-0' }, [
                                    gettext('Mark as read without confirmation')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Confirming mark as read')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-readstorydelay' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-1', type: 'radio', name: 'read_story_delay', value: '0' }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-1' }, [
                                    gettext('Immediately')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-2', type: 'radio', name: 'read_story_delay', value: '1' }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-2' }, [
                                    gettext('After '),
                                    $.make('span', { className: 'NB-tangle-readstorydelay', 'data-var': 'delay' }),
                                    $.make('span', { className: 'NB-tangle-seconds' }, gettext(' second'))
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-3', type: 'radio', name: 'read_story_delay', value: "-2" }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-3' }, [
                                    gettext('Manually or by clicking in the story')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-0', type: 'radio', name: 'read_story_delay', value: "-1" }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-0' }, [
                                    gettext('Manually by hitting '),
                                    $.make('div', {
                                        className: 'NB-keyboard-shortcut-key',
                                        style: 'display: inline; float: none;margin: 0 4px'
                                    }, [
                                        gettext('u')
                                    ]),
                                    gettext('or'),
                                    $.make('div', {
                                        className: 'NB-keyboard-shortcut-key',
                                        style: 'display: inline; float: none;margin: 0 4px'
                                    }, [
                                        gettext('m')
                                    ])
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Mark a story as read'),
                            $.make('div', { className: 'NB-preference-sublabel' }, gettext('Selecting a story in the story titles marks it as read.'))
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-markreadnextfeed' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadnextfeed-1', type: 'radio', name: 'markread_nextfeed', value: 'nextfeed' }),
                                $.make('label', { 'for': 'NB-preference-markreadnextfeed-1' }, [
                                    gettext('Open the next site/folder')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadnextfeed-0', type: 'radio', name: 'markread_nextfeed', value: "nothing" }),
                                $.make('label', { 'for': 'NB-preference-markreadnextfeed-0' }, [
                                    gettext('Stay on the same feed/folder')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('After marking feed/folder read')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showdiscover' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showdiscover-1', type: 'radio', name: 'show_discover', value: "true" }),
                                $.make('label', { 'for': 'NB-preference-showdiscover-1' }, [
                                    gettext('Show discover sites popover above story titles')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showdiscover-0', type: 'radio', name: 'show_discover', value: "false" }),
                                $.make('label', { 'for': 'NB-preference-showdiscover-0' }, [
                                    gettext('Hide discover sites popover')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Discover sites')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-disablesocial' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-social-card NB-social-card-enable' }, [
                                $.make('input', { id: 'NB-preference-disablesocial-0', type: 'radio', name: 'disable_social', value: "false" }),
                                $.make('label', { 'for': 'NB-preference-disablesocial-0', className: 'NB-social-card-content' }, [
                                    $.make('span', { className: 'NB-social-card-icon' }, ''),
                                    $.make('span', { className: 'NB-social-card-title' }, gettext('Enable social features')),
                                    $.make('ul', { className: 'NB-social-features-list' }, [
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Blurblogs')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Share stories')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Comment on stories')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('See shared stories')]),
                                        $.make('li', [$.make('span', { className: 'NB-feature-check' }, '✓'), gettext('Public comments')])
                                    ])
                                ])
                            ]),
                            $.make('div', { className: 'NB-social-card NB-social-card-disable' }, [
                                $.make('input', { id: 'NB-preference-disablesocial-1', type: 'radio', name: 'disable_social', value: "true" }),
                                $.make('label', { 'for': 'NB-preference-disablesocial-1', className: 'NB-social-card-content' }, [
                                    $.make('span', { className: 'NB-social-card-icon' }, ''),
                                    $.make('span', { className: 'NB-social-card-title' }, gettext('Disable social features')),
                                    $.make('span', { className: 'NB-social-card-desc' }, gettext('Hide all sharing, comments, and blurblog features'))
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Sharing')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-stories' }, [
                    $.make('div', { className: 'NB-preference NB-preference-story-share' }, [
                        $.make('div', { className: 'NB-preference-options' }, _.map(NEWSBLUR.assets.third_party_sharing_services, function (label, key) {
                            return $.make('div', { className: 'NB-preference-option', title: label }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-' + key, name: 'story_share_' + key }),
                                $.make('label', { 'for': 'NB-preference-story-share-' + key }, label)
                            ])
                        })),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Sharing services')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-window' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-window-1', type: 'radio', name: 'new_window', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-window-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/application_view_gallery.png' }),
                                    gettext('In this window')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-window-2', type: 'radio', name: 'new_window', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-window-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/silk/application_side_expand.png' }),
                                    gettext('In a new window')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Open links')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-truncatestory' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-1', type: 'radio', name: 'truncate_story', value: 'social' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-1' }, [
                                    gettext('Only truncate long shared stories in blurblogs')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-2', type: 'radio', name: 'truncate_story', value: 'all' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-2' }, [
                                    gettext('Force all tall stories to have a max height')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-3', type: 'radio', name: 'truncate_story', value: 'none' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-3' }, [
                                    gettext('Show the entire story, even if really, really long')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Truncate stories')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-public-comments' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-public-comments-1', type: 'radio', name: 'hide_public_comments', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-public-comments-1' }, gettext('Show from both friends and the public'))
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-public-comments-2', type: 'radio', name: 'hide_public_comments', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-public-comments-2' }, gettext('Only show comments from friends'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Show all comments')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-story-button-placement' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-button-placement-1', type: 'radio', name: 'story_button_placement', value: 'bottom' }),
                                $.make('label', { 'for': 'NB-preference-story-button-placement-1' }, gettext('Always show Train/Save/Share buttons below stories'))
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-button-placement-2', type: 'radio', name: 'story_button_placement', value: 'right' }),
                                $.make('label', { 'for': 'NB-preference-story-button-placement-2' }, gettext('Show buttons on the right (when there is room)'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Story side options placement')
                        ]),
                        $.make('div', { className: 'NB-preference-options NB-preference-story-sideoption-sticky' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-sideoption-sticky', type: 'checkbox', name: 'sticky_story_sideoptions' }),
                                $.make('label', { 'for': 'NB-preference-story-sideoption-sticky' }, gettext('Keep right-side buttons visible while reading'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label NB-preference-story-sideoption-sticky' }, [
                            gettext('Story side options')
                        ]),
                        $.make('div', { className: 'NB-preference-options' }, _.map(["email", "save", "train", "share", "related", "ask_ai"], function (label) {
                            var label_title = label.charAt(0).toUpperCase() + label.slice(1);
                            if (label === "ask_ai") {
                                label_title = "Ask AI";
                            }
                            return $.make('div', { className: 'NB-preference-option NB-preference-story-sideoption', title: label_title }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-sideoption-' + label, name: 'show_sideoption_' + label }),
                                $.make('label', { 'for': 'NB-preference-story-sideoption-' + label }, label_title)
                            ])
                        })),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Story side options buttons')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-youtube-captions' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-youtube-captions', type: 'checkbox', name: 'youtube_captions' }),
                                $.make('label', { 'for': 'NB-preference-youtube-captions' }, gettext('Enable captions/subtitles for YouTube videos'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('YouTube Captions')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-highlights' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-highlights-1', type: 'radio', name: 'highlights', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-highlights-1' }, gettext('Show highlighter when selecting text'))
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-highlights-2', type: 'radio', name: 'highlights', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-highlights-2' }, gettext('Disable the highlighter'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            gettext('Enable highlighting')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-keyboard' }, [
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-preferences-notpremium' }, [
                        gettext('You must have a '),
                        $.make('span', { className: 'NB-splash-link NB-premium-link' }, gettext('premium account')),
                        gettext(' to change keyboard shortcuts.')
                    ])),
                    $.make('div', { className: 'NB-preference NB-preference-keyboard-horizontalarrows' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-horizontalarrows-1',
                                    type: 'radio',
                                    name: 'keyboard_horizontalarrows',
                                    value: 'view',
                                    disabled: !NEWSBLUR.Globals.is_premium
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-horizontalarrows-1' }, gettext('Switch between views (original, feed, text, story)'))
                            ]),
                            $.make('div', [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-horizontalarrows-2',
                                    type: 'radio',
                                    name: 'keyboard_horizontalarrows',
                                    value: 'site',
                                    disabled: !NEWSBLUR.Globals.is_premium
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-horizontalarrows-2' }, gettext('Open the next site/folder'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                gettext('&#x2190;')
                            ]),
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                gettext('&#x2192;')
                            ])
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-keyboard-verticalarrows' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-verticalarrows-1',
                                    type: 'radio',
                                    name: 'keyboard_verticalarrows',
                                    value: 'story',
                                    disabled: !NEWSBLUR.Globals.is_premium
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-verticalarrows-1' }, gettext('Navigate between stories'))
                            ]),
                            $.make('div', [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-verticalarrows-2',
                                    type: 'radio',
                                    name: 'keyboard_verticalarrows',
                                    value: 'scroll',
                                    disabled: !NEWSBLUR.Globals.is_premium
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-verticalarrows-2' }, [
                                    gettext('Scroll up/down in story by '),
                                    $.make('span', { className: 'NB-tangle-arrowscrollspacing-control NB-preference-slider', 'data-var': 'arrow' }),
                                    $.make('span', { className: 'NB-tangle-arrowscrollspacing' }, '100'),
                                    gettext('px.'),
                                    $.make('input', { name: 'arrow_scroll_spacing', value: NEWSBLUR.Preferences.arrow_scroll_spacing, type: 'hidden' })
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                gettext('&#x2193;')
                            ]),
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                gettext('&#x2191;')
                            ])
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-keyboard-spacebar' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                gettext('Page down by '),
                                $.make('span', { className: 'NB-tangle-spacescrollspacing-control NB-preference-slider', 'data-var': 'space' }),
                                ' ',
                                $.make('span', { className: 'NB-tangle-spacescrollspacing' }, '40%'),
                                gettext(' of the screen'),
                                $.make('input', { name: 'space_scroll_spacing', value: NEWSBLUR.Preferences.space_scroll_spacing, type: 'hidden' })
                            ]),
                            $.make('div', { className: 'NB-preference-keyboard-spacebaraction' }, [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-spacebaraction-1',
                                    type: 'radio',
                                    name: 'space_bar_action',
                                    value: 'next_unread'
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-spacebaraction-1' }, gettext('Open next unread story when bottom of story is visible'))
                            ]),
                            $.make('div', { className: 'NB-preference-keyboard-spacebaraction' }, [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-spacebaraction-2',
                                    type: 'radio',
                                    name: 'space_bar_action',
                                    value: 'next_unread_50'
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-spacebaraction-2' }, gettext('Open next unread story when story is half-way up'))
                            ]),
                            $.make('div', [
                                $.make('input', {
                                    id: 'NB-preference-keyboard-spacebaraction-3',
                                    type: 'radio',
                                    name: 'space_bar_action',
                                    value: 'scroll_only'
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-spacebaraction-3' }, gettext('Only page down in story, do not open next unread story'))
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                gettext('space')
                            ])
                        ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-modal-submit NB-modal-submit-form' }, [
                $.make('div', { disabled: 'true', className: 'NB-modal-submit-button NB-modal-submit-green NB-disabled' }, gettext('Make changes above...'))
            ])
        ]);
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

    select_preferences: function () {
        var $modal = this.$modal;
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
        _.each(["email", "save", "train", "share", "related", "ask_ai"], function (sideoption) {
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

    slide_read_story_delay_slider: function (e, ui) {
        var value = (ui && ui.value) ||
            (NEWSBLUR.Preferences.read_story_delay > 0 ? NEWSBLUR.Preferences.read_story_delay : 1);
        $(".NB-tangle-seconds", this.$modal).text(value == 1 ? interpolate(gettext("%(value_1)s second."), {value_1: value}, true) : interpolate(gettext("%(value_1)s seconds."), {value_1: value}, true));
        if (NEWSBLUR.Preferences.read_story_delay > 0 || ui) {
            $("#NB-preference-readstorydelay-2", this.$modal).prop('checked', true).val(value);
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
        $(".NB-tangle-arrowscrollspacing", this.$modal).text(value);
        $("input[name=arrow_scroll_spacing]", this.$modal).val(value);
        if (NEWSBLUR.Preferences.keyboard_verticalarrows == 'scroll' || ui) {
            $("#NB-preference-keyboard-verticalarrows-2", this.$modal).prop('checked', true);
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
        $(".NB-tangle-spacescrollspacing", this.$modal).text(value + "%");
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

    save_preferences: function () {
        var self = this;
        var form = this.serialize_preferences();
        $('.NB-preference-error', this.$modal).text('');
        $('.NB-modal-submit-button', this.$modal).text(gettext('Saving...')).attr('disabled', true).addClass('NB-disabled');

        this.model.save_preferences(form, function (data) {
            if (data && data.code < 0) return;
            if (form.language !== NEWSBLUR.language_preference) { window.location.reload(); return; }
            NEWSBLUR.reader.switch_feed_view_unread_view();
            NEWSBLUR.reader.apply_story_styling(true);
            NEWSBLUR.reader.apply_tipsy_titles();
            NEWSBLUR.reader.adjust_for_narrow_window();
            NEWSBLUR.reader.add_body_classes();
            NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
            NEWSBLUR.app.sidebar_header.count();
            if (self.original_preferences['feed_order'] != form['feed_order'] ||
                self.original_preferences['folder_counts'] != form['folder_counts']) {
                NEWSBLUR.app.feed_list.make_feeds();
                NEWSBLUR.app.feed_list.make_social_feeds();
            }
            if (self.original_preferences['show_global_shared_stories'] != form['show_global_shared_stories'] ||
                self.original_preferences['show_infrequent_site_stories'] != form['show_infrequent_site_stories'] ||
                self.original_preferences['show_widely_read_stories'] != form['show_widely_read_stories'] ||
                self.original_preferences['show_long_reads'] != form['show_long_reads'] ||
                self.original_preferences['show_good_reads'] != form['show_good_reads'] ||
                self.original_preferences['briefing_enabled'] != form['briefing_enabled']) {
                NEWSBLUR.app.feed_list.toggle_filter_feeds();
            }
            if (self.original_preferences['ssl'] != form['ssl']) {
                NEWSBLUR.reader.check_and_load_ssl();
            }
            if (self.original_preferences['days_of_unread'] != form['days_of_unread']) {
                NEWSBLUR.reader.force_feeds_refresh();
            }
            self.close();
        });
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
            $sublabel.text(interpolate(gettext("Cleared %(value_1)s."), {value_1: Inflector.pluralize('override', data.removed, true)}, true));
        }, this));
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function ($t, $p) {
            e.preventDefault();
            var newtab;
            if ($t.hasClass('NB-modal-tab-general')) {
                newtab = 'general';
            } else if ($t.hasClass('NB-modal-tab-feeds')) {
                newtab = 'feeds';
            } else if ($t.hasClass('NB-modal-tab-stories')) {
                newtab = 'stories';
            } else if ($t.hasClass('NB-modal-tab-keyboard')) {
                newtab = 'keyboard';
            }
            self.resize_modal();
            self.switch_tab(newtab);
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-button' }, function ($t, $p) {
            e.preventDefault();

            self.save_preferences();
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
        $.targetIs(e, { tagSelector: '.segmented-control.NB-preference-view-setting-order li' }, function ($t, $p) {
            e.preventDefault();
            var order = $t.hasClass('NB-preference-view-setting-order-oldest') ? 'oldest' : 'newest';
            self.change_view_setting('order', order);
        });
        $.targetIs(e, { tagSelector: '.segmented-control.NB-preference-view-setting-read-filter li' }, function ($t, $p) {
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
    },

    handle_change: function () {
        var self = this;

        $('input[type=radio],input[type=checkbox],select', this.$modal).bind('change', _.bind(this.enable_save, this));
        $('input[name=story_button_placement]', this.$modal).bind('change', function () {
            self.update_story_sideoption_sticky_preference();
            self.resize_modal();
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

    enable_save: function () {
        $('.NB-modal-submit-button', this.$modal).removeAttr('disabled').removeClass('NB-disabled').text(gettext('Save Preferences'));
    },

    disable_save: function () {
        $('.NB-modal-submit-button', this.$modal).attr('disabled', true).addClass('NB-disabled').text(gettext('Make changes above...'));
    }

});
