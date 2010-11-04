// Preferences:
//  - Feed sort order
//  - New window behavior

NEWSBLUR.ReaderPreferences = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.runner();
};

NEWSBLUR.ReaderPreferences.prototype = {
    
    runner: function() {
        this.make_modal();
        this.select_preferences();
        this.handle_cancel();
        this.handle_change();
        this.open_modal();
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Preferences'),
            $.make('form', { className: 'NB-preferences-form' }, [
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
                        'Default view'
                    ])
                ]),
                $.make('div', { className: 'NB-preference NB-preference-window' }, [
                    $.make('div', { className: 'NB-preference-options' }, [
                        $.make('div', [
                            $.make('input', { id: 'NB-preference-window-1', type: 'radio', name: 'new_window', value: 0 }),
                            $.make('label', { 'for': 'NB-preference-window-1' }, 'Normally')
                        ]),
                        $.make('div', [
                            $.make('input', { id: 'NB-preference-window-2', type: 'radio', name: 'new_window', value: 1 }),
                            $.make('label', { 'for': 'NB-preference-window-2' }, 'In a new window')
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference-label'}, [
                        'Open links'
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
    
    open_modal: function() {
        var self = this;
        
        this.$modal.modal({
            'minWidth': 600,
            'maxWidth': 600,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
            },
            'onClose': function(dialog) {
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close();
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    select_preferences: function() {
        if (NEWSBLUR.Preferences.timezone) {
            $('select[name=timezone] option', this.$modal).each(function() {
                if ($(this).val() == NEWSBLUR.Preferences.timezone) {
                    $(this).attr('selected', true);
                    return false;
                }
            });
        }
        
        $('input[name=default_view]', this.$modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.default_view) {
                $(this).attr('checked', true);
                return false;
            }
        });
        $('input[name=new_window]', this.$modal).each(function() {
            if ($(this).val() == NEWSBLUR.Preferences.new_window) {
                $(this).attr('checked', true);
                return false;
            }
        });
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
        
    serialize_preferences: function() {
        var preferences = {};

        $('input[type=radio]:checked, select', this.$modal).each(function() {
            preferences[$(this).attr('name')] = $(this).val();
        });

        return preferences;
    },
    
    save_preferences: function() {
        var form = this.serialize_preferences();
        $('input[type=submit]', this.$modal).val('Saving...').attr('disabled', true).addClass('NB-disabled');
        
        this.model.save_preferences(form, function() {
            $.modal.close();
        });
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
    },
    
    handle_change: function() {
        $('input[type=radio],select', this.$modal).bind('change', _.bind(function() {
            $('input[type=submit]', this.$modal).removeAttr('disabled').removeClass('NB-disabled').val('Save Preferences');
        }, this));
    }
    
};