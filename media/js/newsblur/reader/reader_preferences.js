// Preferences:
//  - Feed sort order
//  - New window behavior

NEWSBLUR.ReaderPreferences = function(options) {
    var defaults = {};
    
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
            $.make('a', { href: '#preferences', className: 'NB-link-account-preferences NB-splash-link' }, 'Switch to Account'),
            $.make('h2', { className: 'NB-modal-title' }, 'Preferences'),
            $.make('form', { className: 'NB-preferences-form' }, [
                $.make('div', { className: 'NB-preferences-scroll' }, [
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
                                    $.make('option', { value: 'Europe/Minsk' }, '(GMT+02:00) Minsk'),
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
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Timezone'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-view' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-view-1', type: 'radio', name: 'default_view', value: 'page' }),
                                $.make('label', { 'for': 'NB-preference-view-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/preferences_view_original.png' })
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-view-2', type: 'radio', name: 'default_view', value: 'feed' }),
                                $.make('label', { 'for': 'NB-preference-view-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/preferences_view_feed.png' })
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-view-3', type: 'radio', name: 'default_view', value: 'story' }),
                                $.make('label', { 'for': 'NB-preference-view-3' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/preferences_view_story.png' })
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Default view',
                            $.make('div', { className: 'NB-preference-sublabel' }, 'You can override this on a per-site basis.')
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
                            $.make('div', { className: 'NB-preference-sublabel' }, 'You can override this on a per-site and per-folder basis.')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-story-pane-position' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-pane-position-1', type: 'radio', name: 'story_pane_anchor', value: 'north' }),
                                $.make('label', { 'for': 'NB-preference-story-pane-position-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/layout_top.png' }),
                                    'Top'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-pane-position-2', type: 'radio', name: 'story_pane_anchor', value: 'west' }),
                                $.make('label', { 'for': 'NB-preference-story-pane-position-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/layout_left.png' }),
                                    'Left'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-pane-position-3', type: 'radio', name: 'story_pane_anchor', value: 'south' }),
                                $.make('label', { 'for': 'NB-preference-story-pane-position-3' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/layout_bottom.png' }),
                                    'Bottom'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Story titles pane'
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
                    $.make('div', { className: 'NB-preference NB-preference-hidereadfeeds' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-hidereadfeeds-1', type: 'radio', name: 'hide_read_feeds', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-hidereadfeeds-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/text_list_bullets.png' }),
                                    'Show everything'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-hidereadfeeds-2', type: 'radio', name: 'hide_read_feeds', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-hidereadfeeds-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/text_list_bullets_single.png' }),
                                    'Hide sites with no unread stories'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Site sidebar',
                            $.make('div', { className: 'NB-preference-sublabel' }, this.make_site_sidebar_count())
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
                    $.make('div', { className: 'NB-preference NB-preference-showunreadcountsintitle' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showunreadcountsintitle-1', type: 'checkbox', name: 'show_unread_counts_in_title', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showunreadcountsintitle-1' }, [
                                    'Show unread counts in the window title'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Window title'
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
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/lock.png' }),
                                    'Only use a secure https connection'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'SSL'
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
                                    $.make('span', { className: 'NB-tangle-seconds' }, ' second.')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-0', type: 'radio', name: 'read_story_delay', value: "-1" }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-0' }, [
                                    'Manually by hitting ',
                                    $.make('div', { className: 'NB-keyboard-shortcut-key', 
                                                    style: 'display: inline; float: none' }, [
                                        'u'
                                    ])
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Mark a story as read'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-hidestorychanges' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-hidestorychanges-1', type: 'radio', name: 'hide_story_changes', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-hidestorychanges-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/code_icon.png' }),
                                    'Show ',
                                    $.make('del', 'changes'),
                                    ' ',
                                    $.make('ins', 'revisions'),
                                    ' in stories'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-hidestorychanges-2', type: 'radio', name: 'hide_story_changes', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-hidestorychanges-2' }, [
                                    'Hide changes and only show the final story'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Story changes'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-singlestory' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-singlestory-1', type: 'radio', name: 'feed_view_single_story', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-singlestory-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/text_linespacing.png' }),
                                    'Show all stories'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-singlestory-2', type: 'radio', name: 'feed_view_single_story', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-singlestory-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/text_horizontalrule.png' }),
                                    'Show a single story at a time'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Feed view'
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
                    $.make('div', { className: 'NB-preference NB-preference-story-styling' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-styling-1', type: 'radio', name: 'story_styling', value: 'sans-serif' }),
                                $.make('label', { 'for': 'NB-preference-story-styling-1', className: 'NB-preference-story-styling-sans-serif' }, 'Lucida Grande, sans serif')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-styling-2', type: 'radio', name: 'story_styling', value: 'serif' }),
                                $.make('label', { 'for': 'NB-preference-story-styling-2', className: 'NB-preference-story-styling-serif' }, 'Georgia, serif')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Feed view styling'
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
                            $.make('div', { className: 'NB-preference-option', title: 'Delicious' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-delicious', name: 'story_share_delicious' }),
                                $.make('label', { 'for': 'NB-preference-story-share-delicious' })
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Sharing services'
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
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-green NB-disabled', value: 'Change what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ]).bind('submit', function(e) {
                e.preventDefault();
                self.save_preferences();
                return false;
            })
        ]);
    },
    
    resize_modal: function() {
        var $scroll = $('.NB-preferences-scroll', this.$modal);
        var $modal = this.$modal;
        var $modal_container = $modal.closest('.simplemodal-container');
        
        if ($modal.height() > $modal_container.height() - 24) {
            $scroll.height($scroll.height() - 5);
            this.resize_modal();
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
        
        $('input[name=default_view]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.default_view) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=story_pane_anchor]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.story_pane_anchor) {
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
        $('input[name=hide_read_feeds]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.hide_read_feeds) {
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
        $('input[name=show_unread_counts_in_title]', $modal).each(function() {
            if (NEWSBLUR.Preferences.show_unread_counts_in_title) {
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
        $('input[name=read_story_delay]', $modal).each(function() {
            if ($(this).val() == ""+NEWSBLUR.Preferences.read_story_delay) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=hide_story_changes]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.hide_story_changes) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=feed_view_single_story]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.feed_view_single_story) {
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
        $('input[name=story_styling]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.story_styling) {
                $(this).attr('checked', true);
                return false;
            }
        });
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
        this.slide_read_story_delay_slider();
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
        preferences['default_order'] = $('.NB-preference-view-setting-order li.NB-active', this.$modal).hasClass('NB-preference-view-setting-order-oldest') ? 'oldest' : 'newest';
        preferences['default_read_filter'] = $('.NB-preference-view-setting-read-filter li.NB-active', this.$modal).hasClass('NB-preference-view-setting-read-filter-unread') ? 'unread' : 'all';

        return preferences;
    },
    
    save_preferences: function() {
        var self = this;
        var form = this.serialize_preferences();
        $('.NB-preference-error', this.$modal).text('');
        $('input[type=submit]', this.$modal).val('Saving...').attr('disabled', true).addClass('NB-disabled');
        
        this.model.save_preferences(form, function(data) {
            NEWSBLUR.reader.switch_feed_view_unread_view();
            NEWSBLUR.reader.apply_story_styling(true);
            NEWSBLUR.reader.apply_tipsy_titles();
            NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
            if (self.original_preferences['feed_order'] != form['feed_order'] ||
                self.original_preferences['folder_counts'] != form['folder_counts']) {
              NEWSBLUR.app.feed_list.make_feeds();
              NEWSBLUR.app.feed_list.make_social_feeds();
            }
            if (self.original_preferences['story_pane_anchor'] != form['story_pane_anchor']) {
              NEWSBLUR.reader.apply_resizable_layout(true);
            }
            if (self.original_preferences['ssl'] != form['ssl']) {
                NEWSBLUR.reader.check_and_load_ssl();
            }
            self.close();
        });
    },
    
    make_site_sidebar_count: function() {
        var sites = _.keys(this.model.feeds).length;
        var unreads = _.select(this.model.feeds, function(f) {
          return f.ng || f.nt || f.ps;
        }).length;
        var message = [
            "Currently ",
            unreads,
            " out of ",
            sites,
            Inflector.pluralize(' site', sites),
            " would be shown."
        ].join('');
        
        return message;
    },
    
    close_and_load_account: function() {
      this.close(function() {
          NEWSBLUR.reader.open_account_modal();
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
    
    
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
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
    },
    
    handle_change: function() {
        
        $('input[type=radio],input[type=checkbox],select', this.$modal).bind('change', _.bind(this.enable_save, this));
    },
    
    enable_save: function() {
        $('input[type=submit]', this.$modal).removeAttr('disabled').removeClass('NB-disabled').val('Save Preferences');
    },
    
    disable_save: function() {
        $('input[type=submit]', this.$modal).attr('disabled', true).addClass('NB-disabled').val('Change what you like above...');
    }
    
});