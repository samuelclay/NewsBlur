NEWSBLUR.ReaderSendEmail = function(story, options) {
    var defaults = {};
    
    _.bindAll(this, 'close', 'save_callback', 'error');

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.story = story;
    this.feed_id = this.story.get('story_feed_id');
    this.feed = this.model.get_feed(this.feed_id);

    this.runner();
};

NEWSBLUR.ReaderSendEmail.prototype = new NEWSBLUR.Modal;

_.extend(NEWSBLUR.ReaderSendEmail.prototype, {
    
    runner: function() {
        _.bindAll(this, 'save');
        this.options.onOpen = _.bind(function() {
            $('input[name=to]', this.$modal).focus();
        }, this);
        this.make_modal();
        this.open_modal();
        this.existing_emails = $.evalJSON($.cookie('NB:email:addresses')) || [];
        this.autocomplete_emails();
        
        if (!NEWSBLUR.Globals.is_authenticated) {
          this.save_callback({'code': -1, 'message': 'You must be logged in to send a story over email.'});
        }
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        $('input, textarea', this.$modal).bind('keydown', 'ctrl+return', this.save);
        $('input, textarea', this.$modal).bind('keydown', 'meta+return', this.save);
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-email NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('div', { className: 'NB-modal-error'}),
            $.make('h2', { className: 'NB-modal-title' }, 'Send Story by Email'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                (this.feed && $.make('div', { className: 'NB-modal-email-feed' }, [
                  $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
                  $.make('div', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title'))
                ])),
                $.make('div', { className: 'NB-modal-email-story-title' }, this.story.story_title),
                $.make('div', { className: 'NB-modal-email-story-permalink' }, this.story.story_permalink)
            ]),
            $.make('div', { className: 'NB-modal-email-to-container' }, [
              $.make('label', { 'for': 'NB-send-email-to' }, [
                ' Recipient emails: '
              ]),
              $.make('input', { className: 'NB-input NB-modal-to', name: 'to', id: 'NB-send-email-to', value: 
          ($.cookie('NB:email:to') || "") })
            ]),
            $.make('div', { className: 'NB-modal-email-explanation' }, [
                "Add an optional comment to send with the story. The story will be sent below your comment."
            ]),
            $.make('div', { className: 'NB-modal-email-comments-container' }, [
                $.make('textarea', { className: 'NB-modal-email-comments' })
            ]),
            $.make('div', { className: 'NB-modal-email-from-container' }, [
              $.make('div', [
                $.make('label', { 'for': 'NB-send-email-from-name' }, [
                  ' Your name: '
                ]),
                $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from_name', id: 'NB-send-email-from-name', value: this.model.preference('full_name') || NEWSBLUR.Globals.username || '' })
              ]),
              $.make('div', { style: 'margin-top: 8px' }, [
                $.make('label', { 'for': 'NB-send-email-from-email' }, [
                  ' Your email: '
                ]),
                $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from_email', id: 'NB-send-email-from-email', value: NEWSBLUR.Globals.email || this.model.preference('email') || '' })
              ]),
              $.make('div', { style: 'margin-top: 8px' }, [
                $.make('label', { 'for': 'NB-send-email-cc' }, [
                  ' CC me: '
                ]),
                $.make('div', { className: 'NB-modal-email-cc-wrapper' }, [
                    $.make('input', { className: 'NB-modal-email-cc', name: 'email_cc', id: 'NB-send-email-cc', type: "checkbox", checked: this.model.preference('email_cc') }),
                    $.make('label', { 'for': 'NB-send-email-cc' }, [
                        "Yes, send me a copy of this email"
                    ])
                ])
              ])
            ]),
            $.make('form', { className: 'NB-recommend-form' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: 'NB-modal-submit-button NB-modal-submit-green', value: 'Send this story' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-emailclient' }, 'open in an email client')
                ]),
                $.make('div', { className: 'NB-error' })
            ])
        ]);
    },
    
    save: function(e) {
        var from_name  = $('input[name=from_name]', this.$modal).val();
        var from_email = $('input[name=from_email]', this.$modal).val();
        var to         = $('input[name=to]', this.$modal).val();
        var email_cc   = $('input[name=email_cc]', this.$modal).is(":checked");
        var comments   = $('textarea', this.$modal).val();
        var $save      = $('input[type=submit]', this.$modal);
        var $error     = $('.NB-modal-error', this.$modal);
        
        $error.hide();
        $save.addClass('NB-disabled').val('Sending...');
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        this.model.preference('full_name', from_name);
        this.model.preference('email', from_email);
        this.model.preference('email_cc', email_cc);
        $('.NB-error', this.$modal).hide();
        
        this.model.send_story_email({
          story_id   : this.story.id,
          feed_id    : this.feed_id,
          from_name  : from_name,
          from_email : from_email,
          email_cc   : email_cc,
          to         : to,
          comments   : comments
        }, this.save_callback, this.error);
    },
    
    save_callback: function(data) {
        var $save = $('input[type=submit]', this.$modal);
        if (!data || data.code < 0) {
          $('.NB-error', this.$modal).html(data.message).fadeIn(500); 
          $('.NB-modal-loading', this.$modal).removeClass('NB-active');
          $save.removeClass('NB-disabled').val('Send this story');
        } else {
          $save.val('Sent!');
          $.cookie('NB:email:to', $('input[name=to]', this.$modal).val());
          var emails = $('input[name=to]', this.$modal).val();
          emails = emails.replace(/[, ]+/g, ' ').split(' ');
          emails = _.uniq(this.existing_emails.concat(emails));
          emails = _.map(emails, function(e) { return _.string.trim(e); });
          emails = _.compact(emails);
          $.cookie('NB:email:addresses', $.toJSON(emails), {expires: 365*10});
          this.close();
        }
    },
    
    error: function(data) {
        var $error = $('.NB-error', this.$modal);
        var $save = $('input[type=submit]', this.$modal);
        $error.show();
        console.log(['Error sending email', data]);
        if (!data || !data.message) {
            $error.text("There was a issue on the backend with sending your email. Sorry about this! It has been noted and will be fixed soon. You should probably send this manually now.");
        } else {
          $error.html(data.message).fadeIn(500); 
        }
        $save.removeClass('NB-disabled').val('Send this story');
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        
        this.resize();
    },
    
    open_email_client: function() {
        var from_name  = $('input[name=from_name]', this.$modal).val();
        var from_email = $('input[name=from_email]', this.$modal).val();
        var to         = $('input[name=to]', this.$modal).val();
        var comments   = $('textarea', this.$modal).val();

        var url = [
            'mailto:',
            to,
            '?subject=',
            from_name,
            ' is sharing a story: ',
            this.story.story_title,
            '&body=',
            comments,
            '%0D%0A%0D%0A--%0D%0A%0D%0A',
            this.story.story_permalink,
            '%0D%0A%0D%0A',
            encodeURIComponent($(this.story.story_content()).text()),
            '%0D%0A%0D%0A',
            '--',
            '%0D%0A%0D%0A',
            'Shared with NewsBlur.com'
        ].join('');
        window.open(url);
    },
    
    autocomplete_emails: function() {
        var $to = $('input[name=to]', this.$modal);
        var existing_emails = this.existing_emails;
        
        var split = function(val) {
            return val.split( /,\s*/ );
        };
        var extractLast = function(term) {
            return split( term ).pop();
        };

        $to
            // don't navigate away from the field on tab when selecting an item
            .bind( "keydown", function( event ) {
                if ( event.keyCode === $.ui.keyCode.TAB &&
                        $( this ).data( "ui-autocomplete" ).menu.active ) {
                    event.preventDefault();
                }
            })
            .autocomplete({
                delay: 0,
                minLength: 0,
                appendTo: '.NB-modal-email',
                source: function( request, response ) {
                    // delegate back to autocomplete, but extract the last term
                    console.log(["autocomplete", request, request.term, existing_emails]);
                    response( $.ui.autocomplete.filter(
                        existing_emails, extractLast( request.term ) ) );
                },
                focus: function() {
                    // prevent value inserted on focus
                    return false;
                },
                select: function( event, ui ) {
                    var terms = split( this.value );
                    // remove the current input
                    terms.pop();
                    // add the selected item
                    terms.push( ui.item.value );
                    // add placeholder to get the comma-and-space at the end
                    terms.push( "" );
                    this.value = terms.join( ", " );
                    return false;
                }
            });
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-button' }, function($t, $p) {
            e.preventDefault();
            
            self.save();
            return false;
        });
        $.targetIs(e, { tagSelector: '.NB-modal-emailclient' }, function($t, $p) {
            e.preventDefault();
            
            self.open_email_client();
            return false;
        });
    }
    
});