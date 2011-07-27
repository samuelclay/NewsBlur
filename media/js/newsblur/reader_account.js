NEWSBLUR.ReaderAccount = function(options) {
    var defaults = {};
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.AssetModel.reader();

    this.runner();
};

NEWSBLUR.ReaderAccount.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderAccount.prototype.constructor = NEWSBLUR.ReaderAccount;

_.extend(NEWSBLUR.ReaderAccount.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();

        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-preferences NB-modal-account NB-modal' }, [
            $.make('a', { href: '#preferences', className: 'NB-link-account-preferences NB-splash-link' }, 'Switch to Preferences'),
            $.make('h2', { className: 'NB-modal-title' }, 'My Account'),
            $.make('form', { className: 'NB-preferences-form' }, [
                $.make('div', { className: 'NB-preference NB-preference-username' }, [
                    $.make('div', { className: 'NB-preference-options' }, [
                        $.make('div', { className: 'NB-preference-option' }, [
                            $.make('input', { id: 'NB-preference-username', type: 'text', name: 'username', value: NEWSBLUR.Globals.username })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference-label'}, [
                        $.make('label', { 'for': 'NB-preference-username' }, 'Username'),

                        $.make('div', { className: 'NB-preference-error'})
                    ])
                ]),
                $.make('div', { className: 'NB-preference NB-preference-email' }, [
                    $.make('div', { className: 'NB-preference-options' }, [
                        $.make('div', { className: 'NB-preference-option' }, [
                            $.make('input', { id: 'NB-preference-email', type: 'text', name: 'email', value: NEWSBLUR.Globals.email })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference-label'}, [
                        $.make('label', { 'for': 'NB-preference-email' }, 'Email address'),

                        $.make('div', { className: 'NB-preference-error'})
                    ])
                ]),
                $.make('div', { className: 'NB-preference NB-preference-password' }, [
                    $.make('div', { className: 'NB-preference-options' }, [
                        $.make('div', { className: 'NB-preference-option' }, [
                            $.make('label', { 'for': 'NB-preference-password-old' }, 'Old password'),
                            $.make('input', { id: 'NB-preference-password-old', type: 'password', name: 'old_password', value: '' })
                        ]),
                        $.make('div', { className: 'NB-preference-option' }, [
                            $.make('label', { 'for': 'NB-preference-password-new' }, 'New password'),
                            $.make('input', { id: 'NB-preference-password-new', type: 'password', name: 'new_password', value: '' })
                        ])
                    ]),
                    $.make('div', { className: 'NB-preference-label'}, [
                        'Change password',
                        $.make('div', { className: 'NB-preference-error'})
                    ])
                ]),
                $.make('div', { className: 'NB-preference NB-preference-premium' }, [
                    $.make('div', { className: 'NB-preference-options' }, [
                        (!NEWSBLUR.Globals.is_premium && $.make('a', { className: 'NB-modal-submit-button NB-modal-submit-green NB-account-premium-modal' }, 'Go Premium!')),
                        (NEWSBLUR.Globals.is_premium && $.make('div', [
                            'Thank you! You have a ',
                            $.make('b', 'premium account'),
                            '.'
                        ]))
                    ]),
                    $.make('div', { className: 'NB-preference-label'}, [
                        'Premium'
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
                ]),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-modal-submit-green NB-disabled', value: 'Change what you like above...' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ])
        ]);
    },
    
    close_and_load_preferences: function() {
      this.close(function() {
          NEWSBLUR.reader.open_preferences_modal();
      });
    },
    
    close_and_load_premium: function() {
      this.close(function() {
          NEWSBLUR.reader.open_feedchooser_modal();
      });
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-account-premium-modal' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_premium();
        });        
        $.targetIs(e, { tagSelector: '.NB-link-account-preferences' }, function($t, $p) {
            e.preventDefault();
            
            self.close_and_load_preferences();
        });
    }
    
});