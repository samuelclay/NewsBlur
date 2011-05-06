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
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-email NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Send Story by Email'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('div', { className: 'NB-modal-email-story-title' }, this.story.story_title),
                $.make('div', { className: 'NB-modal-email-feed' }, [
                  $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed.favicon) }),
                  $.make('div', { className: 'NB-modal-feed-title' }, this.feed.feed_title)
                ]),
                $.make('div', { className: 'NB-modal-email-story-permalink' }, this.story.story_permalink)
            ]),
            $.make('div', { className: 'NB-modal-email-to-container' }, [
              '&raquo; Recipient\'s email: ',
              $.make('input', { className: 'NB-input NB-modal-to', name: 'to', value: "" })
            ]),
            $.make('div', { className: 'NB-modal-email-explanation' }, [
                "Add an optional comment to send with the story. The story will be sent below your comment."
            ]),
            $.make('div', { className: 'NB-modal-email-comments-container' }, [
                $.make('textarea', { className: 'NB-modal-email-comments' })
            ]),
            $.make('div', { className: 'NB-modal-email-from-container' }, [
              '&raquo; Your name: ',
              $.make('input', { className: 'NB-input NB-modal-email-from', name: 'from', value: NEWSBLUR.Globals.username })
            ]),
            $.make('form', { className: 'NB-recommend-form' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: 'NB-modal-submit-save NB-modal-submit-green', value: 'Send this story' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ])
        ]);
    },
    
    save: function(e) {
        var from     = $('input[name=from]', this.$modal).val();
        var to       = $('input[name=to]', this.$modal).val();
        var comments = $('textarea', this.$modal).val();
        var $save    = $('input[type=submit]', this.$modal);
        
        $save.addClass('NB-disabled').val('Sending...');
        
        this.model.send_story_email({
          story_id : this.story_id,
          feed_id  : this.feed_id,
          from     : from,
          to       : to,
          comments : comments
        }, this.close, function(error) {
            $save.removeClass('NB-disabled').val('Send Email');
        });
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