// Preferences:
//  - Feed sort order
//  - New window behavior

NEWSBLUR.ReaderPreferences = function(options) {
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

    runner: function() {
        this.options.onOpen = _.bind(function() {
            this.resize_modal();
        }, this);
        this.make_modal();
        this.select_preferences();
        this.handle_change();
        this.open_modal();
        this.original_preferences = this.serialize_preferences();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal' }, [
            $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-general' }, 'General'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-feeds' }, 'Feeds'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-stories' }, 'Stories'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-keyboard' }, 'Keyboard')
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Preferences',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('form', { className: 'NB-preferences-form' }, [
                $.make('div', { className: 'NB-tab NB-tab-general NB-active' }, [
                    $.make('div', { className: 'NB-preference' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('select', { id: 'NB-preference-timezone-1', name: 'timezone' }, [
                                    $.make('option', { value: 'Pacific/Midway' }, '(GMT-11:00) Midway Island, Samoa'),
                                    $.make('option', { value: 'America/Adak' }, '(GMT-10:00) Hawaii-Aleutian'),
                                    $.make('option', { value: 'Etc/GMT+10' }, '(GMT-10:00) Hawaii'),
                                    $.make('option', { value: 'Pacific/Marquesas' }, '(GMT-09:30) Marquesas Islands'),
                                    $.make('option', { value: 'Pacific/Gambier' }, '(GMT-09:00) Gambier Islands'),
                                    $.make('option', { value: 'America/Anchorage' }, '(GMT-09:00) Alaska'),
                                    $.make('option', { value: 'America/Ensenada' }, '(GMT-08:00) Tijuana, Baja California'),
                                    $.make('option', { value: 'Etc/GMT+8' }, '(GMT-08:00) Pitcairn Islands'),
                                    $.make('option', { value: 'America/Los_Angeles' }, '(GMT-08:00) Pacific Time (US & Canada)'),
                                    $.make('option', { value: 'America/Denver' }, '(GMT-07:00) Mountain Time (US & Canada)'),
                                    $.make('option', { value: 'America/Chihuahua' }, '(GMT-07:00) Chihuahua, La Paz, Mazatlan'),
                                    $.make('option', { value: 'America/Dawson_Creek' }, '(GMT-07:00) Arizona'),
                                    $.make('option', { value: 'America/Belize' }, '(GMT-06:00) Saskatchewan, Central America'),
                                    $.make('option', { value: 'America/Cancun' }, '(GMT-06:00) Guadalajara, Mexico City'),
                                    $.make('option', { value: 'Chile/EasterIsland' }, '(GMT-06:00) Easter Island'),
                                    $.make('option', { value: 'America/Chicago' }, '(GMT-06:00) Central Time (US & Canada)'),
                                    $.make('option', { value: 'America/New_York' }, '(GMT-05:00) Eastern Time (US & Canada)'),
                                    $.make('option', { value: 'America/Havana' }, '(GMT-05:00) Cuba'),
                                    $.make('option', { value: 'America/Bogota' }, '(GMT-05:00) Bogota, Lima, Quito, Rio Branco'),
                                    $.make('option', { value: 'America/Caracas' }, '(GMT-04:30) Caracas'),
                                    $.make('option', { value: 'America/Santiago' }, '(GMT-04:00) Santiago'),
                                    $.make('option', { value: 'America/La_Paz' }, '(GMT-04:00) La Paz'),
                                    $.make('option', { value: 'Atlantic/Stanley' }, '(GMT-04:00) Faukland Islands'),
                                    $.make('option', { value: 'America/Campo_Grande' }, '(GMT-04:00) Brazil'),
                                    $.make('option', { value: 'America/Goose_Bay' }, '(GMT-04:00) Atlantic Time (Goose Bay)'),
                                    $.make('option', { value: 'America/Glace_Bay' }, '(GMT-04:00) Atlantic Time (Canada)'),
                                    $.make('option', { value: 'America/St_Johns' }, '(GMT-03:30) Newfoundland'),
                                    $.make('option', { value: 'America/Araguaina' }, '(GMT-03:00) UTC-3'),
                                    $.make('option', { value: 'America/Montevideo' }, '(GMT-03:00) Montevideo'),
                                    $.make('option', { value: 'America/Miquelon' }, '(GMT-03:00) Miquelon, St. Pierre'),
                                    $.make('option', { value: 'America/Godthab' }, '(GMT-03:00) Greenland'),
                                    $.make('option', { value: 'America/Argentina/Buenos_Aires' }, '(GMT-03:00) Buenos Aires'),
                                    $.make('option', { value: 'America/Sao_Paulo' }, '(GMT-03:00) Brasilia'),
                                    $.make('option', { value: 'America/Noronha' }, '(GMT-02:00) Mid-Atlantic'),
                                    $.make('option', { value: 'Atlantic/Cape_Verde' }, '(GMT-01:00) Cape Verde Is.'),
                                    $.make('option', { value: 'Atlantic/Azores' }, '(GMT-01:00) Azores'),
                                    $.make('option', { value: 'Europe/Belfast' }, '(GMT) Greenwich Mean Time : Belfast'),
                                    $.make('option', { value: 'Europe/Dublin' }, '(GMT) Greenwich Mean Time : Dublin'),
                                    $.make('option', { value: 'Europe/Lisbon' }, '(GMT) Greenwich Mean Time : Lisbon'),
                                    $.make('option', { value: 'Europe/London' }, '(GMT) Greenwich Mean Time : London'),
                                    $.make('option', { value: 'Africa/Abidjan' }, '(GMT) Monrovia, Reykjavik'),
                                    $.make('option', { value: 'Europe/Amsterdam' }, '(GMT+01:00) Amsterdam, Berlin, Stockholm'),
                                    $.make('option', { value: 'Europe/Belgrade' }, '(GMT+01:00) Belgrade, Budapest, Prague'),
                                    $.make('option', { value: 'Europe/Brussels' }, '(GMT+01:00) Brussels, Copenhagen, Paris'),
                                    $.make('option', { value: 'Africa/Algiers' }, '(GMT+01:00) West Central Africa'),
                                    $.make('option', { value: 'Africa/Windhoek' }, '(GMT+01:00) Windhoek'),
                                    $.make('option', { value: 'Asia/Beirut' }, '(GMT+02:00) Beirut'),
                                    $.make('option', { value: 'Africa/Cairo' }, '(GMT+02:00) Cairo'),
                                    $.make('option', { value: 'Asia/Gaza' }, '(GMT+02:00) Gaza'),
                                    $.make('option', { value: 'Africa/Blantyre' }, '(GMT+02:00) Harare, Pretoria'),
                                    $.make('option', { value: 'Asia/Jerusalem' }, '(GMT+02:00) Jerusalem'),
                                    $.make('option', { value: 'Europe/Minsk' }, '(GMT+02:00) Minsk, Kyiv'),
                                    $.make('option', { value: 'Asia/Damascus' }, '(GMT+02:00) Syria'),
                                    $.make('option', { value: 'Europe/Moscow' }, '(GMT+03:00) Moscow, St. Petersburg'),
                                    $.make('option', { value: 'Africa/Addis_Ababa' }, '(GMT+03:00) Nairobi'),
                                    $.make('option', { value: 'Asia/Tehran' }, '(GMT+03:30) Tehran'),
                                    $.make('option', { value: 'Asia/Dubai' }, '(GMT+04:00) Abu Dhabi, Muscat'),
                                    $.make('option', { value: 'Asia/Yerevan' }, '(GMT+04:00) Yerevan'),
                                    $.make('option', { value: 'Asia/Kabul' }, '(GMT+04:30) Kabul'),
                                    $.make('option', { value: 'Asia/Yekaterinburg' }, '(GMT+05:00) Ekaterinburg'),
                                    $.make('option', { value: 'Asia/Tashkent' }, '(GMT+05:00) Tashkent'),
                                    $.make('option', { value: 'Asia/Kolkata' }, '(GMT+05:30) Chennai, Mumbai, New Delhi'),
                                    $.make('option', { value: 'Asia/Katmandu' }, '(GMT+05:45) Kathmandu'),
                                    $.make('option', { value: 'Asia/Dhaka' }, '(GMT+06:00) Astana, Dhaka'),
                                    $.make('option', { value: 'Asia/Novosibirsk' }, '(GMT+06:00) Novosibirsk'),
                                    $.make('option', { value: 'Asia/Rangoon' }, '(GMT+06:30) Yangon (Rangoon)'),
                                    $.make('option', { value: 'Asia/Bangkok' }, '(GMT+07:00) Bangkok, Hanoi, Jakarta'),
                                    $.make('option', { value: 'Asia/Krasnoyarsk' }, '(GMT+07:00) Krasnoyarsk'),
                                    $.make('option', { value: 'Asia/Hong_Kong' }, '(GMT+08:00) Beijing, Chongqing, Hong Kong'),
                                    $.make('option', { value: 'Asia/Irkutsk' }, '(GMT+08:00) Irkutsk, Ulaan Bataar'),
                                    $.make('option', { value: 'Australia/Perth' }, '(GMT+08:00) Perth'),
                                    $.make('option', { value: 'Australia/Eucla' }, '(GMT+08:45) Eucla'),
                                    $.make('option', { value: 'Asia/Tokyo' }, '(GMT+09:00) Osaka, Sapporo, Tokyo'),
                                    $.make('option', { value: 'Asia/Seoul' }, '(GMT+09:00) Seoul'),
                                    $.make('option', { value: 'Asia/Yakutsk' }, '(GMT+09:00) Yakutsk'),
                                    $.make('option', { value: 'Australia/Adelaide' }, '(GMT+09:30) Adelaide'),
                                    $.make('option', { value: 'Australia/Darwin' }, '(GMT+09:30) Darwin'),
                                    $.make('option', { value: 'Australia/Brisbane' }, '(GMT+10:00) Brisbane'),
                                    $.make('option', { value: 'Australia/Sydney' }, '(GMT+10:00) Sydney, Hobart'),
                                    $.make('option', { value: 'Asia/Vladivostok' }, '(GMT+10:00) Vladivostok'),
                                    $.make('option', { value: 'Australia/Lord_Howe' }, '(GMT+10:30) Lord Howe Island'),
                                    $.make('option', { value: 'Etc/GMT-11' }, '(GMT+11:00) Solomon Is., New Caledonia'),
                                    $.make('option', { value: 'Asia/Magadan' }, '(GMT+11:00) Magadan'),
                                    $.make('option', { value: 'Pacific/Norfolk' }, '(GMT+11:30) Norfolk Island'),
                                    $.make('option', { value: 'Asia/Anadyr' }, '(GMT+12:00) Anadyr, Kamchatka'),
                                    $.make('option', { value: 'Pacific/Auckland' }, '(GMT+12:00) Auckland, Wellington'),
                                    $.make('option', { value: 'Etc/GMT-12' }, '(GMT+12:00) Fiji, Kamchatka, Marshall Is.'),
                                    $.make('option', { value: 'Pacific/Chatham' }, '(GMT+12:45) Chatham Islands'),
                                    $.make('option', { value: 'Pacific/Tongatapu' }, '(GMT+13:00) Nuku\'alofa'),
                                    $.make('option', { value: 'Pacific/Kiritimati' }, '(GMT+14:00) Kiritimati')
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-dateformat-1', type: 'radio', name: 'dateformat', value: '12' }),
                                $.make('label', { 'for': 'NB-preference-dateformat-1' }, [
                                    'Use 12-hour clock'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-dateformat-2', type: 'radio', name: 'dateformat', value: '24' }),
                                $.make('label', { 'for': 'NB-preference-dateformat-2' }, [
                                    'Use 24-hour clock'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Timezone'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-ssl' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-ssl-1', type: 'radio', name: 'ssl', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-ssl-1' }, [
                                    'Use a standard connection'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-ssl-2', type: 'radio', name: 'ssl', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-ssl-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/g_icn_lock.png' }),
                                    'Only use a secure https connection'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'SSL'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showunreadcountsintitle' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showunreadcountsintitle-1', type: 'checkbox', name: 'title_counts', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showunreadcountsintitle-1' }, [
                                    'Show unread counts in the window title'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Window title'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-autoopenfolder' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-autoopenfolder-1', type: 'radio', name: 'autoopen_folder', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-autoopenfolder-1' }, [
                                    'Show the dashboard when loading NewsBlur'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-autoopenfolder-2', type: 'radio', name: 'autoopen_folder', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-autoopenfolder-2' }, [
                                    this.make_autoopen_folders()
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Default folder'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-animations' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-animations-1', type: 'radio', name: 'animations', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-animations-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/arrow_in.png' }),
                                    'Show all animations'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-animations-2', type: 'radio', name: 'animations', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-animations-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/arrow_right.png' }),
                                    'Jump immediately with no animations'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Animations'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-feedorder' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-feedorder-1', type: 'radio', name: 'feed_order', value: 'ALPHABETICAL' }),
                                $.make('label', { 'for': 'NB-preference-feedorder-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/pilcrow.png' }),
                                    'Alphabetical'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-feedorder-2', type: 'radio', name: 'feed_order', value: 'MOSTUSED' }),
                                $.make('label', { 'for': 'NB-preference-feedorder-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/report_user.png' }),
                                    'Most used at top, then alphabetical'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Site sidebar order'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-folder-counts' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-folder-counts-1', type: 'radio', name: 'folder_counts', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-folder-counts-1' }, [
                                    'Only show counts on collapsed folders'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-folder-counts-2', type: 'radio', name: 'folder_counts', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-folder-counts-2' }, [
                                    'Always show unread counts on folders'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Folder unread counts'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-tooltips' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-tooltips-1', type: 'radio', name: 'show_tooltips', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-tooltips-1' }, [
                                    'Show tooltips'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-tooltips-2', type: 'radio', name: 'show_tooltips', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-tooltips-2' }, [
                                    'Don\'t bother showing tooltips'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Tooltips',
                            $.make('div', { className: 'tipsy tipsy-n' }, [
                                $.make('div', { className: 'tipsy-arrow' }),
                                $.make('div', { className: 'tipsy-inner' }, 'Tooltips like this')
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
                                    'Open the feed and story title menu'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-contextmenus-2', type: 'radio', name: 'show_contextmenus', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-contextmenus-2' }, [
                                    'Use the native browser context menu'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Right-clicking',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'Folders, feeds, and story titles')
                        ])
                    ]),                    
                    $.make('div', { className: 'NB-preference NB-preference-opml' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('a', { className: 'NB-splash-link', href: NEWSBLUR.URLs['opml-export'] }, 'Download OPML')
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Backup your sites',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'Download this XML file as a backup')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-feeds' }, [
                    $.make('div', { className: 'NB-preference NB-preference-layout' }, [
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "" }, [
                                $.make('label', { 'for': 'NB-preference-layout-1' }, [
                                    $.make('input', { id: 'NB-preference-layout-1', type: 'radio', name: 'story_layout', value: 'full' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_full_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Full")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-2' }, [
                                    $.make('input', { id: 'NB-preference-layout-2', type: 'radio', name: 'story_layout', value: 'split' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_split_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Split")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-3' }, [
                                    $.make('input', { id: 'NB-preference-layout-3', type: 'radio', name: 'story_layout', value: 'list' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_list_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "List")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-4' }, [
                                    $.make('input', { id: 'NB-preference-layout-4', type: 'radio', name: 'story_layout', value: 'grid' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_grid_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Grid")
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Default layout',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'You can override this on a per-site basis.'),
                            $.make('div', { className: 'NB-clear-overrides-layout NB-preference-sublabel-link NB-splash-link' }, "Clear all overrides")
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-view' }, [
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "NB-view-setting-original" }, [
                                $.make('label', { 'for': 'NB-preference-view-1' }, [
                                    $.make('input', { id: 'NB-preference-view-1', type: 'radio', name: 'default_view', value: 'page' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_original_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Original")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-2' }, [
                                    $.make('input', { id: 'NB-preference-view-2', type: 'radio', name: 'default_view', value: 'feed' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_feed_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Feed")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-3' }, [
                                    $.make('input', { id: 'NB-preference-view-3', type: 'radio', name: 'default_view', value: 'text' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_text_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Text")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-4' }, [
                                    $.make('input', { id: 'NB-preference-view-4', type: 'radio', name: 'default_view', value: 'story' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/nav_story_story_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Story")
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Default view',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'You can override this on a per-site basis.'),
                            $.make('div', { className: 'NB-clear-overrides-view NB-preference-sublabel-link NB-splash-link' }, "Clear all overrides")
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-view-setting' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('ul', { className: 'segmented-control NB-preference-view-setting-order' }, [
                                $.make('li', { className: 'NB-preference-view-setting-order-newest NB-active' }, 'Newest first'),
                                $.make('li', { className: 'NB-preference-view-setting-order-oldest' }, 'Oldest')
                            ]),
                            $.make('ul', { className: 'segmented-control NB-preference-view-setting-read-filter' }, [
                                $.make('li', { className: 'NB-preference-view-setting-read-filter-all  NB-active' }, 'All stories'),
                                $.make('li', { className: 'NB-preference-view-setting-read-filter-unread' }, 'Unread only')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Default story order',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'You can override this on a per-site and per-folder basis.'),
                            $.make('div', { className: 'NB-clear-overrides-order NB-preference-sublabel-link NB-splash-link' }, "Clear all overrides")
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-openfeedaction' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-openfeedaction-1', type: 'radio', name: 'open_feed_action', value: 'newest' }),
                                $.make('label', { 'for': 'NB-preference-openfeedaction-1' }, [
                                    'Open the first story'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-openfeedaction-0', type: 'radio', name: 'open_feed_action', value: 0, checked: true }),
                                $.make('label', { 'for': 'NB-preference-openfeedaction-0' }, [
                                    'Show all stories'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'When opening a site'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-markreadstoryscroll' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadstoryscroll-1', type: 'radio', name: 'mark_read_on_scroll_titles', value: "true" }),
                                $.make('label', { 'for': 'NB-preference-markreadstoryscroll-1' }, [
                                    'Mark stories as read when scrolled past'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadstoryscroll-0', type: 'radio', name: 'mark_read_on_scroll_titles', value: "false" }),
                                $.make('label', { 'for': 'NB-preference-markreadstoryscroll-0' }, [
                                    'Don\'t automatically mark stories as read'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Mark stories read on scroll'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showcontentpreview' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showcontentpreview-1', type: 'radio', name: 'show_content_preview', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-showcontentpreview-1' }, [
                                    'Show a preview of the story'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showcontentpreview-0', type: 'radio', name: 'show_content_preview', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showcontentpreview-0' }, [
                                    'Don\'t show a preview, only show the story title'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Story content preview'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-showimagepreview' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-1', type: 'radio', name: 'show_image_preview', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-1' }, [
                                    'Show an image thumbnail in the story title'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showimagepreview-0', type: 'radio', name: 'show_image_preview', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showimagepreview-0' }, [
                                    'Don\'t show a thumbnail'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Image preview'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-doubleclickfeed' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickfeed-1', type: 'radio', name: 'doubleclick_feed', value: 'open' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickfeed-1' }, [
                                    'Open the site in a new window'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickfeed-0', type: 'radio', name: 'doubleclick_feed', value: 'open_and_read' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickfeed-0' }, [
                                    'Open the site in a new window and mark it as read'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickfeed-2', type: 'radio', name: 'doubleclick_feed', value: 'ignore' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickfeed-2' }, [
                                    'Don\'t do anything on double-clicks'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Double-clicking a site'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-doubleclickunread' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickunread-1', type: 'radio', name: 'doubleclick_unread', value: 'markread' }),
                                $.make('label', { 'for': 'NB-preference-doubleclickunread-1' }, [
                                    'Mark the site as read'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-doubleclickunread-0', type: 'radio', name: 'doubleclick_unread', value: "ignore" }),
                                $.make('label', { 'for': 'NB-preference-doubleclickunread-0' }, [
                                    'Don\'t do anything on double-clicks'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Double-clicking an unread count'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-markreadriverconfirm' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadriverconfirmation-1', type: 'radio', name: 'mark_read_river_confirm', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-markreadriverconfirmation-1' }, [
                                    'Show confirmation when marking everything read'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadriverconfirm-0', type: 'radio', name: 'mark_read_river_confirm', value: "false" }),
                                $.make('label', { 'for': 'NB-preference-markreadriverconfirm-0' }, [
                                    'Mark everything as read without confirmation'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Marking All Site Stories as read'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-readstorydelay' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-1', type: 'radio', name: 'read_story_delay', value: '0' }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-1' }, [
                                    'Immediately'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-2', type: 'radio', name: 'read_story_delay', value: '1' }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-2' }, [
                                    'After ',
                                    $.make('span', { className: 'NB-tangle-readstorydelay', 'data-var': 'delay' }),
                                    $.make('span', { className: 'NB-tangle-seconds' }, ' second')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-0', type: 'radio', name: 'read_story_delay', value: "-1" }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-0' }, [
                                    'Manually by hitting ',
                                    $.make('div', { className: 'NB-keyboard-shortcut-key', 
                                                    style: 'display: inline; float: none;margin: 0 4px' }, [
                                        'u'
                                    ]),
                                    'or',
                                    $.make('div', { className: 'NB-keyboard-shortcut-key', 
                                                    style: 'display: inline; float: none;margin: 0 4px' }, [
                                        'm'
                                    ])
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Mark a story as read',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'Clicking on a story marks it as read immediately.')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-markreadnextfeed' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadnextfeed-1', type: 'radio', name: 'markread_nextfeed', value: 'nextfeed' }),
                                $.make('label', { 'for': 'NB-preference-markreadnextfeed-1' }, [
                                    'Open the next site/folder'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-markreadnextfeed-0', type: 'radio', name: 'markread_nextfeed', value: "nothing" }),
                                $.make('label', { 'for': 'NB-preference-markreadnextfeed-0' }, [
                                    'Stay on the same feed/folder'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'After marking feed/folder read'
                        ])
                    ])

                ]),
                $.make('div', { className: 'NB-tab NB-tab-stories' }, [
                    $.make('div', { className: 'NB-preference NB-preference-story-share' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', { className: 'NB-preference-option', title: 'Twitter' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-twitter', name: 'story_share_twitter' }),
                                $.make('label', { 'for': 'NB-preference-story-share-twitter' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Facebook' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-facebook', name: 'story_share_facebook' }),
                                $.make('label', { 'for': 'NB-preference-story-share-facebook' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Readability' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-readability', name: 'story_share_readability' }),
                                $.make('label', { 'for': 'NB-preference-story-share-readability' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Instapaper' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-instapaper', name: 'story_share_instapaper' }),
                                $.make('label', { 'for': 'NB-preference-story-share-instapaper' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Pinboard.in' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-pinboard', name: 'story_share_pinboard' }),
                                $.make('label', { 'for': 'NB-preference-story-share-pinboard' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Pinterest' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-pinterest', name: 'story_share_pinterest' }),
                                $.make('label', { 'for': 'NB-preference-story-share-pinterest' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Buffer' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-buffer', name: 'story_share_buffer' }),
                                $.make('label', { 'for': 'NB-preference-story-share-buffer' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Diigo' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-diigo', name: 'story_share_diigo' }),
                                $.make('label', { 'for': 'NB-preference-story-share-diigo' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Kippt' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-kippt', name: 'story_share_kippt' }),
                                $.make('label', { 'for': 'NB-preference-story-share-kippt' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Evernote' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-evernote', name: 'story_share_evernote' }),
                                $.make('label', { 'for': 'NB-preference-story-share-evernote' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Google+' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-googleplus', name: 'story_share_googleplus' }),
                                $.make('label', { 'for': 'NB-preference-story-share-googleplus' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Pocket (RIL)' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-readitlater', name: 'story_share_readitlater' }),
                                $.make('label', { 'for': 'NB-preference-story-share-readitlater' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Tumblr' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-tumblr', name: 'story_share_tumblr' }),
                                $.make('label', { 'for': 'NB-preference-story-share-tumblr' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Blogger' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-blogger', name: 'story_share_blogger' }),
                                $.make('label', { 'for': 'NB-preference-story-share-blogger' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'Delicious' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-delicious', name: 'story_share_delicious' }),
                                $.make('label', { 'for': 'NB-preference-story-share-delicious' })
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Sharing services'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-window' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-window-1', type: 'radio', name: 'new_window', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-window-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/application_view_gallery.png' }),
                                    'In this window'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-window-2', type: 'radio', name: 'new_window', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-window-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/application_side_expand.png' }),
                                    'In a new window'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Open links'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-fullwidthdstory' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-fullwidthdstory-1', type: 'radio', name: 'full_width_story', value: "false" }),
                                $.make('label', { 'for': 'NB-preference-fullwidthdstory-1' }, [
                                    'Wrap story content at 700px to ease reading'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-fullwidthdstory-2', type: 'radio', name: 'full_width_story', value: "true" }),
                                $.make('label', { 'for': 'NB-preference-fullwidthdstory-2' }, [
                                    'Wrap story content at the edge of the screen'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Story width'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-truncatestory' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-1', type: 'radio', name: 'truncate_story', value: 'social' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-1' }, [
                                    'Only truncate long shared stories in blurblogs'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-2', type: 'radio', name: 'truncate_story', value: 'all' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-2' }, [
                                    'Force all tall stories to have a max height'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-3', type: 'radio', name: 'truncate_story', value: 'none' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-3' }, [
                                    'Show the entire story, even if really, really long'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Truncate stories'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-public-comments' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-public-comments-1', type: 'radio', name: 'hide_public_comments', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-public-comments-1' }, 'Show from both friends and the public')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-public-comments-2', type: 'radio', name: 'hide_public_comments', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-public-comments-2' }, 'Only show comments from friends')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Show all comments'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-story-button-placement' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-button-placement-1', type: 'radio', name: 'story_button_placement', value: 'bottom' }),
                                $.make('label', { 'for': 'NB-preference-story-button-placement-1' }, 'Always show Train/Save/Share buttons below stories')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-button-placement-2', type: 'radio', name: 'story_button_placement', value: 'right' }),
                                $.make('label', { 'for': 'NB-preference-story-button-placement-2' }, 'Show buttons on the right (when there is room)')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Story button placement'
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-keyboard' }, [
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-preferences-notpremium' }, [
                        'You must have a ',
                        $.make('span', { className: 'NB-splash-link NB-premium-link' }, 'premium account'),
                        ' to change keyboard shortcuts.'
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
                                $.make('label', { 'for': 'NB-preference-keyboard-horizontalarrows-1' }, 'Switch between views (original, feed, text, story)')
                            ]),
                            $.make('div', [
                                $.make('input', { 
                                    id: 'NB-preference-keyboard-horizontalarrows-2', 
                                    type: 'radio', 
                                    name: 'keyboard_horizontalarrows', 
                                    value: 'site',
                                    disabled: !NEWSBLUR.Globals.is_premium
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-horizontalarrows-2' }, 'Open the next site/folder')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                '&#x2190;'
                            ]),
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                '&#x2192;'
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
                                $.make('label', { 'for': 'NB-preference-keyboard-verticalarrows-1' }, 'Navigate between stories')
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
                                    'Scroll up/down in story by ',
                                    $.make('span', { className: 'NB-tangle-arrowscrollspacing-control NB-preference-slider', 'data-var': 'arrow' }),
                                    $.make('span', { className: 'NB-tangle-arrowscrollspacing' }, '100'),
                                    'px.',
                                    $.make('input', { name: 'arrow_scroll_spacing', value: NEWSBLUR.Preferences.arrow_scroll_spacing, type: 'hidden' })
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                '&#x2193;'
                            ]),
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                '&#x2191;'
                            ])
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-keyboard-spacebar' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                'Page down by ',
                                $.make('span', { className: 'NB-tangle-spacescrollspacing-control NB-preference-slider', 'data-var': 'space' }),
                                ' ',
                                $.make('span', { className: 'NB-tangle-spacescrollspacing' }, '40%'),
                                ' of the screen',
                                $.make('input', { name: 'space_scroll_spacing', value: NEWSBLUR.Preferences.space_scroll_spacing, type: 'hidden' })
                            ]),
                            $.make('div', { className: 'NB-preference-keyboard-spacebaraction' }, [
                                $.make('input', { 
                                    id: 'NB-preference-keyboard-spacebaraction-1', 
                                    type: 'radio', 
                                    name: 'space_bar_action', 
                                    value: 'next_unread'
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-spacebaraction-1' }, 'Open next unread story when bottom of story is visible')
                            ]),
                            $.make('div', { className: 'NB-preference-keyboard-spacebaraction' }, [
                                $.make('input', { 
                                    id: 'NB-preference-keyboard-spacebaraction-2', 
                                    type: 'radio', 
                                    name: 'space_bar_action', 
                                    value: 'next_unread_50'
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-spacebaraction-2' }, 'Open next unread story when story is half-way up')
                            ]),
                            $.make('div', [
                                $.make('input', { 
                                    id: 'NB-preference-keyboard-spacebaraction-3', 
                                    type: 'radio', 
                                    name: 'space_bar_action', 
                                    value: 'scroll_only'
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-spacebaraction-3' }, 'Only page down in story, do not open next unread story')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            $.make('div', { className: 'NB-keyboard-shortcut-key' }, [
                                'space'
                            ])
                        ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-modal-submit NB-modal-submit-form' }, [
                $.make('div', { disabled: 'true', className: 'NB-modal-submit-button NB-modal-submit-green NB-disabled' }, 'Make changes above...')
            ])
        ]);
    },
    
    make_autoopen_folders: function() {
        var autoopen_folder = NEWSBLUR.Preferences.autoopen_folder;
        var $folders = NEWSBLUR.utils.make_folders(autoopen_folder, {
            name: 'default_folder',
            toplevel: "All Site Stories"
        });
        return $folders;
    },
    
    resize_modal: function(old_height) {
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
    
    select_preferences: function() {
        var $modal = this.$modal;
        
        if (NEWSBLUR.Preferences.timezone) {
            $('select[name=timezone] option', $modal).each(function() {
                if ($(this).val() == NEWSBLUR.Preferences.timezone) {
                    $(this).attr('selected', true);
                    return false;
                }
            });
        }
        
        $('select[name=default_folder] option', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.default_folder) {
                $(this).attr('selected', true);
                return false;
            }
        });
        $('input[name=story_layout]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.story_layout) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=default_view]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.default_view) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=new_window]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.new_window) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=feed_order]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.feed_order) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=ssl]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.ssl) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=autoopen_folder]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.autoopen_folder) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=title_counts]', $modal).each(function() {
            if (NEWSBLUR.Preferences.title_counts) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=open_feed_action]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.open_feed_action) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=mark_read_on_scroll_titles]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.mark_read_on_scroll_titles) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=show_content_preview]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.show_content_preview) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=show_image_preview]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.show_image_preview) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=doubleclick_feed]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.doubleclick_feed) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=doubleclick_unread]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.doubleclick_unread) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=mark_read_river_confirm]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.mark_read_river_confirm) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=markread_nextfeed]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.markread_nextfeed) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=read_story_delay]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.read_story_delay) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=full_width_story]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.full_width_story) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=truncate_story]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.truncate_story) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=animations]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.animations) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=dateformat]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.dateformat) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=folder_counts]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.folder_counts) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=show_tooltips]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.show_tooltips) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=show_contextmenus]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.show_contextmenus) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=hide_public_comments]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.hide_public_comments) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=story_button_placement]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.story_button_placement) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=keyboard_verticalarrows]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.keyboard_verticalarrows) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=keyboard_horizontalarrows]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.keyboard_horizontalarrows) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=space_bar_action]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.space_bar_action) {
                $(this).attr('checked', true);
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
        
        var share_preferences = _.select(_.keys(NEWSBLUR.Preferences), function(p) { 
            return p.indexOf('story_share') != -1; 
        });
        _.each(share_preferences, function(share) {
            var share_name = share.match(/story_share_(.*)/)[1];
            $('input#NB-preference-story-share-'+share_name, $modal).attr('checked', NEWSBLUR.Preferences[share]);
        });
        
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
    },
    
    slide_read_story_delay_slider: function(e, ui) {
        var value = (ui && ui.value) ||
                    (NEWSBLUR.Preferences.read_story_delay > 0 ? NEWSBLUR.Preferences.read_story_delay : 1);
        $(".NB-tangle-seconds", this.$modal).text(value == 1 ? value + ' second.' : value + ' seconds.');
        if (NEWSBLUR.Preferences.read_story_delay > 0 || ui) {
            $("#NB-preference-readstorydelay-2", this.$modal).attr('checked', true).val(value);
            if (ui) {
                this.enable_save();
            }
        }
    },

    slide_arrow_scroll_spacing_slider: function(e, ui) {
        var value = (ui && ui.value) || NEWSBLUR.Preferences.arrow_scroll_spacing;
        if (!NEWSBLUR.Globals.is_premium) {
            value = NEWSBLUR.Preferences.arrow_scroll_spacing;
        }
        $(".NB-tangle-arrowscrollspacing", this.$modal).text(value);
        $("input[name=arrow_scroll_spacing]", this.$modal).val(value);
        if (NEWSBLUR.Preferences.keyboard_verticalarrows == 'scroll' || ui) {
            $("#NB-preference-keyboard-verticalarrows-2", this.$modal).attr('checked', true);
            if (ui) {
                this.enable_save();
            }
        }
    },

    slide_space_scroll_spacing_slider: function(e, ui) {
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

    serialize_preferences: function() {
        var preferences = {};

        $('input[type=radio]:checked, select', this.$modal).each(function() {
            var name       = $(this).attr('name');
            var preference = preferences[name] = $(this).val();
            if (preference == 'true')       preferences[name] = true;
            else if (preference == 'false') preferences[name] = false;
        });
        $('input[type=checkbox]', this.$modal).each(function() {
            preferences[$(this).attr('name')] = $(this).is(':checked');
        });
        $('input[type=hidden]', this.$modal).each(function() {
            preferences[$(this).attr('name')] = $(this).val();
        });
        preferences['default_order'] = $('.NB-preference-view-setting-order li.NB-active', this.$modal).hasClass('NB-preference-view-setting-order-oldest') ? 'oldest' : 'newest';
        preferences['default_read_filter'] = $('.NB-preference-view-setting-read-filter li.NB-active', this.$modal).hasClass('NB-preference-view-setting-read-filter-unread') ? 'unread' : 'all';

        return preferences;
    },
    
    save_preferences: function() {
        var self = this;
        var form = this.serialize_preferences();
        $('.NB-preference-error', this.$modal).text('');
        $('.NB-modal-submit-button', this.$modal).text('Saving...').attr('disabled', true).addClass('NB-disabled');
        
        this.model.save_preferences(form, function(data) {
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
            if (self.original_preferences['ssl'] != form['ssl']) {
                NEWSBLUR.reader.check_and_load_ssl();
            }
            self.close();
        });
    },
    
    close_and_load_account: function() {
      this.close(function() {
          NEWSBLUR.reader.open_account_modal();
      });
    },
    
    close_and_load_feedchooser: function() {
        this.close(function() {
            NEWSBLUR.reader.open_feedchooser_modal();
        });
    },
    
    change_view_setting: function(view, setting) {
        if (view == 'order') {
            $('.NB-preference-view-setting-order-oldest').toggleClass('NB-active', setting == 'oldest');
            $('.NB-preference-view-setting-order-newest').toggleClass('NB-active', setting != 'oldest');
        } else if (view == 'read_filter') {
            $('.NB-preference-view-setting-read-filter-unread').toggleClass('NB-active', setting == 'unread');
            $('.NB-preference-view-setting-read-filter-all').toggleClass('NB-active', setting != 'unread');
        }
        
        this.enable_save();
    },
    
    clear_overrides: function(type) {
        var $sublabel = $('.NB-clear-overrides-' + type, this.$modal);
        $sublabel.text('Resetting...').removeClass('NB-splash-link');
        NEWSBLUR.assets.clear_view_settings(type, _.bind(function(data) {
            $sublabel.text('Cleared ' + Inflector.pluralize('override', data.removed, true) + '.');
        }, this));
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-tab' }, function($t, $p) {
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
        $.targetIs(e, { tagSelector: '.NB-modal-submit-button' }, function($t, $p) {
            e.preventDefault();
            
            self.save_preferences();
        });

        $.targetIs(e, { tagSelector: '.NB-add-url-submit' }, function($t, $p) {
            e.preventDefault();
            
            self.save_preferences();
        });
        $.targetIs(e, { tagSelector: '.NB-link-account-preferences' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_account();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-cancel' }, function($t, $p) {
            e.preventDefault();
            
            self.close();
        });
        $.targetIs(e, { tagSelector: '.NB-premium-link' }, function($t, $p) {
            e.preventDefault();
            self.close_and_load_feedchooser();
        });
        $.targetIs(e, { tagSelector: '.segmented-control.NB-preference-view-setting-order li' }, function($t, $p) {
            e.preventDefault();
            var order = $t.hasClass('NB-preference-view-setting-order-oldest') ? 'oldest' : 'newest';
            self.change_view_setting('order', order);
        });
        $.targetIs(e, { tagSelector: '.segmented-control.NB-preference-view-setting-read-filter li' }, function($t, $p) {
            e.preventDefault();
            var read_filter = $t.hasClass('NB-preference-view-setting-read-filter-unread') ? 'unread' : 'all';
            self.change_view_setting('read_filter', read_filter);
        });
        $.targetIs(e, { tagSelector: '.NB-clear-overrides-view' }, function($t, $p) {
            e.preventDefault();
            self.clear_overrides('view');
        });
        $.targetIs(e, { tagSelector: '.NB-clear-overrides-order' }, function($t, $p) {
            e.preventDefault();
            self.clear_overrides('order');
        });
        $.targetIs(e, { tagSelector: '.NB-clear-overrides-layout' }, function($t, $p) {
            e.preventDefault();
            self.clear_overrides('layout');
        });
    },
    
    handle_change: function() {
        
        $('input[type=radio],input[type=checkbox],select', this.$modal).bind('change', _.bind(this.enable_save, this));
    },
    
    enable_save: function() {
        $('.NB-modal-submit-button', this.$modal).removeAttr('disabled').removeClass('NB-disabled').text('Save Preferences');
    },
    
    disable_save: function() {
        $('.NB-modal-submit-button', this.$modal).attr('disabled', true).addClass('NB-disabled').text('Make changes above...');
    }
    
});