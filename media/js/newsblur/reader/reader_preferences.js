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
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-general' }, '一般'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-feeds' }, '站点'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-stories' }, '文章'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-keyboard' }, '快捷键')
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                '首选项',
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
                            '时区'
                        ])
                    ]),
/*
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
                    ]),*/
                    $.make('div', { className: 'NB-preference NB-preference-showunreadcountsintitle' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-showunreadcountsintitle-1', type: 'checkbox', name: 'title_counts', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-showunreadcountsintitle-1' }, [
                                    '在窗口标题显示未读文章数'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '浏览器窗口标题'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-animations' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-animations-1', type: 'radio', name: 'animations', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-animations-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/arrow_in.png' }),
                                    '显示所有动画效果'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-animations-2', type: 'radio', name: 'animations', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-animations-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/arrow_right.png' }),
                                    '立即跳转不显示任何动画'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '动画'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-feedorder' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-feedorder-1', type: 'radio', name: 'feed_order', value: 'ALPHABETICAL' }),
                                $.make('label', { 'for': 'NB-preference-feedorder-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/pilcrow.png' }),
                                    '按字母顺序'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-feedorder-2', type: 'radio', name: 'feed_order', value: 'MOSTUSED' }),
                                $.make('label', { 'for': 'NB-preference-feedorder-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/report_user.png' }),
                                    '使用最多的排在上面，优先于字母顺序'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '侧边栏站点顺序'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-folder-counts' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-folder-counts-1', type: 'radio', name: 'folder_counts', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-folder-counts-1' }, [
                                    '只在折叠状态的文件夹显示未读文章数'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-folder-counts-2', type: 'radio', name: 'folder_counts', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-folder-counts-2' }, [
                                    '总是在文件夹显示未读文章数'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '文件夹未读文章数'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-tooltips' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-tooltips-1', type: 'radio', name: 'show_tooltips', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-tooltips-1' }, [
                                    '显示工具提示'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-tooltips-2', type: 'radio', name: 'show_tooltips', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-tooltips-2' }, [
                                    '不要显示'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            '工具提示',
                            $.make('div', { className: 'tipsy tipsy-n' }, [
                                $.make('div', { className: 'tipsy-arrow' }),
                                $.make('div', { className: 'tipsy-inner' }, '类似这样的工具提示')
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
                                    '打开文件夹、Feed 和文章的菜单'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-contextmenus-2', type: 'radio', name: 'show_contextmenus', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-contextmenus-2' }, [
                                    '使用浏览器原生的右键菜单'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            '右键点击',
                            $.make('div', { className: 'NB-preference-sublabel' }, '文件夹、Feed 和文章的标题')
                        ])
                    ]),                    
                    $.make('div', { className: 'NB-preference NB-preference-opml' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('a', { className: 'NB-splash-link', href: NEWSBLUR.URLs['opml-export'] }, '下载 OPML')
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '备份你的站点',
                            $.make('div', { className: 'NB-preference-sublabel' }, '下载此 XML 文件作为备份')
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-feeds' }, [
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
                            '默认视图',
                            $.make('div', { className: 'NB-preference-sublabel' }, '你可以为每个站点分别设置而覆盖此选项。')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-view-setting' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('ul', { className: 'segmented-control NB-preference-view-setting-order' }, [
                                $.make('li', { className: 'NB-preference-view-setting-order-newest NB-active' }, '最新文章在前'),
                                $.make('li', { className: 'NB-preference-view-setting-order-oldest' }, '最旧文章在前')
                            ]),
                            $.make('ul', { className: 'segmented-control NB-preference-view-setting-read-filter' }, [
                                $.make('li', { className: 'NB-preference-view-setting-read-filter-all  NB-active' }, '所有文章'),
                                $.make('li', { className: 'NB-preference-view-setting-read-filter-unread' }, '未读文章')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '默认文章顺序',
                            $.make('div', { className: 'NB-preference-sublabel' }, '你可以为每个站点分别设置而覆盖此选项。')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-singlestory' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-singlestory-1', type: 'radio', name: 'feed_view_single_story', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-singlestory-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/text_linespacing.png' }),
                                    '显示所有文章'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-singlestory-2', type: 'radio', name: 'feed_view_single_story', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-singlestory-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/text_horizontalrule.png' }),
                                    '一次显示一篇文章'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Feed 视图'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-story-pane-position' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-pane-position-1', type: 'radio', name: 'story_pane_anchor', value: 'north' }),
                                $.make('label', { 'for': 'NB-preference-story-pane-position-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/layout_top.png' }),
                                    '上方'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-pane-position-2', type: 'radio', name: 'story_pane_anchor', value: 'west' }),
                                $.make('label', { 'for': 'NB-preference-story-pane-position-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/layout_left.png' }),
                                    '左侧'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-pane-position-3', type: 'radio', name: 'story_pane_anchor', value: 'south' }),
                                $.make('label', { 'for': 'NB-preference-story-pane-position-3' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/reader/layout_bottom.png' }),
                                    '下方'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '文章标题窗格'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-openfeedaction' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-openfeedaction-1', type: 'radio', name: 'open_feed_action', value: 'newest' }),
                                $.make('label', { 'for': 'NB-preference-openfeedaction-1' }, [
                                    '打开第一篇文章'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-openfeedaction-0', type: 'radio', name: 'open_feed_action', value: 0, checked: true }),
                                $.make('label', { 'for': 'NB-preference-openfeedaction-0' }, [
                                    '显示所有文章'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '当打开一个站点时'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-readstorydelay' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-1', type: 'radio', name: 'read_story_delay', value: '0' }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-1' }, [
                                    '立即'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-2', type: 'radio', name: 'read_story_delay', value: '1' }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-2' }, [
                                    '延迟 ',
                                    $.make('span', { className: 'NB-tangle-readstorydelay', 'data-var': 'delay' }),
                                    $.make('span', { className: 'NB-tangle-seconds' }, ' second.')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-readstorydelay-0', type: 'radio', name: 'read_story_delay', value: "-1" }),
                                $.make('label', { 'for': 'NB-preference-readstorydelay-0' }, [
                                    '通过键盘快捷键 ',
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
                            '标记一篇文章为已读',
                            $.make('div', { className: 'NB-preference-sublabel' }, '点击一篇文章后立即标记其为已读。')
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
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: '新浪微博' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-weibo', name: 'story_share_weibo' }),
                                $.make('label', { 'for': 'NB-preference-story-share-weibo' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: '腾讯微博' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-tweibo', name: 'story_share_tweibo' }),
                                $.make('label', { 'for': 'NB-preference-story-share-tweibo' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: '人人网' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-renren', name: 'story_share_renren' }),
                                $.make('label', { 'for': 'NB-preference-story-share-renren' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: '印象笔记' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-yinxiang', name: 'story_share_yinxiang' }),
                                $.make('label', { 'for': 'NB-preference-story-share-yinxiang' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: '推荐到豆瓣' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-douban', name: 'story_share_douban' }),
                                $.make('label', { 'for': 'NB-preference-story-share-douban' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: '网易微博' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-t163', name: 'story_share_t163' }),
                                $.make('label', { 'for': 'NB-preference-story-share-t163' })
                            ]),
                            $.make('div', { className: 'NB-preference-option', title: 'QQ空间' }, [
                                $.make('input', { type: 'checkbox', id: 'NB-preference-story-share-qzone', name: 'story_share_qzone' }),
                                $.make('label', { 'for': 'NB-preference-story-share-qzone' })
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '分享服务'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-window' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-window-1', type: 'radio', name: 'new_window', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-window-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/application_view_gallery.png' }),
                                    '在此标签页'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-window-2', type: 'radio', name: 'new_window', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-window-2' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/silk/application_side_expand.png' }),
                                    '打开新标签页'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '打开链接'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-hidestorychanges' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-hidestorychanges-1', type: 'radio', name: 'hide_story_changes', value: 0 }),
                                $.make('label', { 'for': 'NB-preference-hidestorychanges-1' }, [
                                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL+'/img/icons/circular/g_icn_modified.png' }),
                                    '在文章中显示 ',
                                    $.make('del', '变更'),
                                    ' 和 ',
                                    $.make('ins', '修订')
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-hidestorychanges-2', type: 'radio', name: 'hide_story_changes', value: 1 }),
                                $.make('label', { 'for': 'NB-preference-hidestorychanges-2' }, [
                                    '隐藏所有变更记录只显示最终版本'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '文章的变更记录'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-truncatestory' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-1', type: 'radio', name: 'truncate_story', value: 'social' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-1' }, [
                                    '只在 Zeitblog 里截短长文章'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-2', type: 'radio', name: 'truncate_story', value: 'all' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-2' }, [
                                    '使所有的文章都不超过一个最大长度'
                                ])
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-truncatestory-3', type: 'radio', name: 'truncate_story', value: 'none' }),
                                $.make('label', { 'for': 'NB-preference-truncatestory-3' }, [
                                    '显示完整的文章，即使很长很长'
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '截短文章'
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
                            'Feed 视图的字体'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-story-size' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-size-1', type: 'radio', name: 'story_size', value: 'xs' }),
                                $.make('label', { 'for': 'NB-preference-story-size-1', className: 'NB-preference-story-size-xs' }, '超小')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-size-2', type: 'radio', name: 'story_size', value: 's' }),
                                $.make('label', { 'for': 'NB-preference-story-size-2', className: 'NB-preference-story-size-s' }, '小')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-size-3', type: 'radio', name: 'story_size', value: 'm' }),
                                $.make('label', { 'for': 'NB-preference-story-size-3', className: 'NB-preference-story-size-m' }, '中')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-size-4', type: 'radio', name: 'story_size', value: 'l' }),
                                $.make('label', { 'for': 'NB-preference-story-size-4', className: 'NB-preference-story-size-l' }, '大')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-story-size-5', type: 'radio', name: 'story_size', value: 'xl' }),
                                $.make('label', { 'for': 'NB-preference-story-size-5', className: 'NB-preference-story-size-xl' }, '超大')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            'Feed 视图的文字大小'
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference NB-preference-public-comments' }, [
                        $.make('div', { className: 'NB-preference-options' }, [
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-public-comments-1', type: 'radio', name: 'hide_public_comments', value: 'false' }),
                                $.make('label', { 'for': 'NB-preference-public-comments-1' }, '同时显示好友的评论和其他公开的评论')
                            ]),
                            $.make('div', [
                                $.make('input', { id: 'NB-preference-public-comments-2', type: 'radio', name: 'hide_public_comments', value: 'true' }),
                                $.make('label', { 'for': 'NB-preference-public-comments-2' }, '只显示来自好友的评论')
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label'}, [
                            '显示所有评论'
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-tab NB-tab-keyboard' }, [
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-preferences-notpremium' }, [
                        '你必须拥有 ',
                        $.make('span', { className: 'NB-splash-link NB-premium-link' }, '高级帐户'),
                        ' 才能自定义键盘快捷键。'
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
                                $.make('label', { 'for': 'NB-preference-keyboard-horizontalarrows-1' }, '在视图之间切换 (原始站点、Feed、全文、原文)')
                            ]),
                            $.make('div', [
                                $.make('input', { 
                                    id: 'NB-preference-keyboard-horizontalarrows-2', 
                                    type: 'radio', 
                                    name: 'keyboard_horizontalarrows', 
                                    value: 'site',
                                    disabled: !NEWSBLUR.Globals.is_premium
                                }),
                                $.make('label', { 'for': 'NB-preference-keyboard-horizontalarrows-2' }, '打开下一个站点/文件夹')
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
                                $.make('label', { 'for': 'NB-preference-keyboard-verticalarrows-1' }, '在文章之间切换')
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
                                    '上下滚动文章 ',
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
                                '向下翻页 ',
                                $.make('span', { className: 'NB-tangle-spacescrollspacing-control NB-preference-slider', 'data-var': 'space' }),
                                ' ',
                                $.make('span', { className: 'NB-tangle-spacescrollspacing' }, '40%'),
                                ' 的屏幕高度',
                                $.make('input', { name: 'space_scroll_spacing', value: NEWSBLUR.Preferences.space_scroll_spacing, type: 'hidden' })
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
                $.make('div', { disabled: 'true', className: 'NB-modal-submit-button NB-modal-submit-green NB-disabled' }, '修改上面的配置...')
            ])
        ]);
    },
    
    resize_modal: function() {
        var $scroll = $('.NB-tab.NB-active', this.$modal);
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
        $('input[name=truncate_story]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.truncate_story) {
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
        $('input[name=show_contextmenus]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.show_contextmenus) {
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
        $('input[name=story_size]', $modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.story_size) {
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
            NEWSBLUR.app.story_list.show_stories_preference_in_feed_view();
            NEWSBLUR.app.sidebar_header.count();
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
    },
    
    handle_change: function() {
        
        $('input[type=radio],input[type=checkbox],select', this.$modal).bind('change', _.bind(this.enable_save, this));
    },
    
    enable_save: function() {
        $('.NB-modal-submit-button', this.$modal).removeAttr('disabled').removeClass('NB-disabled').text('保存首选项');
    },
    
    disable_save: function() {
        $('.NB-modal-submit-button', this.$modal).attr('disabled', true).addClass('NB-disabled').text('修改上面的配置...');
    }
    
});
