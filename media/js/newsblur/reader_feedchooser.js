NEWSBLUR.ReaderFeedchooser = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.runner();
};

NEWSBLUR.ReaderFeedchooser.prototype = {
    
    runner: function() {
        this.MAX_FEEDS = 40;
        this.approve_list = [];
        this.make_modal();
        this.open_modal();
        this.initial_load_feeds();
        
        this.$modal.bind('mousedown', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-feedchooser NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Choose Your '+this.MAX_FEEDS),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('b', [
                    'You have a ',
                    $.make('span', { style: 'color: #303060;' }, 'Standard Account'),
                    ', which can follow up to '+this.MAX_FEEDS+' sites at a time.'
                ]),
                'Choose which '+this.MAX_FEEDS+' you would like to follow. You can always change these.'
            ]),
            $.make('div', { className: 'NB-feedchooser-info'}, [
                $.make('div', { className: 'NB-feedchooser-info-counts'})
            ]),
            this.make_feeds(),
            $.make('form', { className: 'NB-feedchooser-form' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', disabled: 'true', className: 'NB-disabled NB-modal-submit-save NB-modal-submit-green', value: 'Check what you like above...' }),
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
    
    make_feeds: function() {
        var feeds = this.model.feeds;
        
        var $feeds = $('#feed_list').clone(true).attr({
            'id': 'NB-feedchooser-feeds',
            'class': 'NB-feedlist NB-feedchooser unread_view_positive',
            'style': ''
        });
        
        $('.unread_count_positive', $feeds).text('On');
        $('.unread_count_negative', $feeds).text('Off');
        return $feeds;
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
    
    add_feed_to_decline: function(feed_id) {
        this.approve_list = _.without(this.approve_list, feed_id);
        var $feed = this.find_feed_in_feed_list(feed_id);
        
        $feed.removeClass('NB-feedchooser-approve');
        $feed.addClass('NB-feedchooser-decline');
        this.update_counts();
    },
    
    add_feed_to_approve: function(feed_id) {
        if (!_.contains(this.approve_list, feed_id)) {
            this.approve_list.push(feed_id);
            var $feed = this.find_feed_in_feed_list(feed_id);
            
            $feed.removeClass('NB-feedchooser-decline');
            $feed.addClass('NB-feedchooser-approve');
        }
        this.update_counts();
    },
        
    find_feed_in_feed_list: function(feed_id) {
        var $feed_list = $('.NB-feedchooser', this.$modal);
        var $feeds = $([]);
        
        $('.feed', $feed_list).each(function() {
            if ($(this).data('feed_id') == feed_id) {
                $feeds.push($(this).get(0));
            }
        });
        
        return $feeds;
    },
    
    update_counts: function() {
        var $count = $('.NB-feedchooser-info-counts');
        var approved = this.approve_list.length;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var difference = approved - this.MAX_FEEDS;
        
        $count.text(approved + '/' + this.MAX_FEEDS);
        $count.toggleClass('NB-full', approved == this.MAX_FEEDS);
        $count.toggleClass('NB-error', approved > this.MAX_FEEDS);
        
        if (approved > this.MAX_FEEDS) {
          $submit.removeClass('NB-disabled').attr('disabled', true).val('Too many sites! Deselect ' + (
            difference == 1 ?
            '1 site...' :
            difference + ' sites...'
          ));
        } else {
          $submit.removeClass('NB-disabled').attr('disabled', false).val('OK! These are my ' + approved + '.');
        }
    },
    
    initial_load_feeds: function() {
        var self = this;
        var $feeds = $('.feed', this.$modal);
        
        // Get feed subscribers
        var min_subscribers = _.last(
          _.first(
            _.pluck(this.model.get_feeds(), 'subs').sort(function(a,b) { 
              return b-a; 
            }), 
            this.MAX_FEEDS
          )
        );
        
        // Decline everything
        var feeds = [];
        $feeds.each(function() {
            var feed_id = $(this).data('feed_id');
            
            self.add_feed_to_decline(feed_id);
            
            if (self.model.get_feed(feed_id)['subs'] >= min_subscribers) {
                feeds.push(feed_id);
            }
        });
        
        // Approve feeds in subs
        _.each(feeds, function(feed_id) {
            if (self.model.get_feed(feed_id)['subs'] > min_subscribers &&
                self.approve_list.length < self.MAX_FEEDS) {
                self.add_feed_to_approve(feed_id);
            }
        });
        _.each(feeds, function(feed_id) {
            if (self.model.get_feed(feed_id)['subs'] == min_subscribers &&
                self.approve_list.length < self.MAX_FEEDS) {
                self.add_feed_to_approve(feed_id);
            }
        });
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.feed' }, _.bind(function($t, $p) {
            e.preventDefault();
            
            var feed_id = $t.data('feed_id');
            if (_.contains(this.approve_list, feed_id)) {
                this.add_feed_to_decline(feed_id);
            } else {
                this.add_feed_to_approve(feed_id);
            }
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, _.bind(function($t, $p) {
            e.preventDefault();
            
        }, this));
    },

    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    }
                
};