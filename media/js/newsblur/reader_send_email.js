NEWSBLUR.ReaderSendEmail = function(story_id, options) {
    var defaults = {};
    
    _.bindAll(this, 'close');

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.story_id = story_id;
    this.story = this.model.get_story(story_id);
    this.feed_id = this.story.story_feed_id;
    this.feed = this.model.get_feed(this.feed_id);

    this.runner();
};

NEWSBLUR.ReaderSendEmail.prototype = _.extend({}, NEWSBLUR.Modal.prototype, {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        
        if (!NEWSBLUR.Globals.is_authenticated) {
          this.save_callback({'code': -1, 'message': 'You must be logged in to send a story over email.'});
        }
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-email NB-modal' }, [
            $.make('span', { className: 'NB-modal-loading NB-spinner'}),
            $.make('h2', { className: 'NB-modal-title' }, 'Send Story by Email'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('div', { className: 'NB-modal-email-feed' }, [
                  $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed.favicon) }),
                  $.make('div', { className: 'NB-modal-feed-title' }, this.feed.feed_title)
                ]),
                $.make('div', { className: 'NB-modal-email-story-title' }, this.story.story_title),
                $.make('div', { className: 'NB-modal-email-story-permalink' }, this.story.story_permalink)
            ]),
            $.make('div', { className: 'NB-modal-email-to-container' }, [
              $.make('label', { 'for': 'NB-send-email-to' }, [
                $.make('span', { className: 'NB-raquo' }, '&raquo;'),
                ' Recipient\'s email: '
              ]),
              $.make('input', { className: 'NB-input NB-modal-to', name: 'to', id: 'NB-send-email-to', value: "" })
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
                  $.make('span', { className: 'NB-raquo' }, '&raquo;'),
                  ' Your name: '
                ]),
                $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from_name', id: 'NB-send-email-from-name', value: this.model.preference('full_name') || NEWSBLUR.Globals.username || '' })
              ]),
              $.make('div', { style: 'margin-top: 8px' }, [
                $.make('label', { 'for': 'NB-send-email-from-email' }, [
                  $.make('span', { className: 'NB-raquo' }, '&raquo;'),
                  ' Your email: '
                ]),
                $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from_email', id: 'NB-send-email-from-email', value: NEWSBLUR.Globals.email || this.model.preference('email') || '' })
              ])
            ]),
            $.make('form', { className: 'NB-recommend-form' }, [
                $.make('div', { className: 'NB-error' }),
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: 'NB-modal-submit-save NB-modal-submit-green', value: 'Send this story' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ])
        ]);
    },
    
    save: function(e) {
        var from_name  = $('input[name=from_name]', this.$modal).val();
        var from_email = $('input[name=from_email]', this.$modal).val();
        var to         = $('input[name=to]', this.$modal).val();
        var comments   = $('textarea', this.$modal).val();
        var $save      = $('input[type=submit]', this.$modal);
        
        $save.addClass('NB-disabled').val('Sending...');
        $('.NB-modal-loading', this.$modal).addClass('NB-active');
        this.model.preference('full_name', from_name);
        this.model.preference('email', from_email);
        $('.NB-error', this.$modal).fadeOut(500);
        
        this.model.send_story_email({
          story_id   : this.story_id,
          feed_id    : this.feed_id,
          from_name  : from_name,
          from_email : from_email,
          to         : to,
          comments   : comments
        }, _.bind(this.save_callback, this));
    },
    
    save_callback: function(data) {
        var $save = $('input[type=submit]', this.$modal);
        if (!data || data.code < 0) {
          $('.NB-error', this.$modal).html(data.message).fadeIn(500); 
          $('.NB-modal-loading', this.$modal).removeClass('NB-active');
          $save.removeClass('NB-disabled').val('Send this story');
        } else {
          $save.val('Sent!');
          this.close();
        }
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, function($t, $p) {
            e.preventDefault();
            
            self.save();
            return false;
        });
    }
    
});