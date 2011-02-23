NEWSBLUR.ReaderFeedchooser = function(options) {
    var defaults = {};

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.runner();
};

NEWSBLUR.ReaderFeedchooser.prototype = {
    
    runner: function() {
        this.start = new Date();
        this.MAX_FEEDS = 64;
        this.approve_list = [];
        this.make_modal();
        this.make_paypal_button();
        _.defer(_.bind(function() { this.open_modal(); }, this));
        this.find_feeds_in_feed_list();
        this.initial_load_feeds();
        this.setup_dollar_slider();
        this.update_dollar_count(1);
        
        this.flags = {
            'has_saved': false
        };
        
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
                    ', which can follow up to '+this.MAX_FEEDS+' sites.'
                ]),
                'You can always change these.'
            ]),
            $.make('div', { className: 'NB-feedchooser-type'}, [
              $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                        $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, 'Free'),
                        ' Standard Account'
                  ]),
                  $.make('div', { className: 'NB-feedchooser-info-counts'}),
                  $.make('div', { className: 'NB-feedchooser-info-sort'}, 'Auto-Selected By Popularity')
              ]),
              this.make_feeds(),
              $.make('form', { className: 'NB-feedchooser-form' }, [
                  $.make('div', { className: 'NB-modal-submit' }, [
                      // $.make('div', { className: 'NB-modal-submit-or' }, 'or'),
                      $.make('input', { type: 'submit', disabled: 'true', className: 'NB-disabled NB-modal-submit-save NB-modal-submit-green', value: 'Check what you like above...' }),
                      $.make('input', { type: 'submit', className: 'NB-modal-submit-add NB-modal-submit-green', value: 'First, add sites' })
                  ])
              ]).bind('submit', function(e) {
                  e.preventDefault();
                  return false;
              })
            ]),
            $.make('div', { className: 'NB-feedchooser-type NB-last'}, [
              $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                    $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, 'Super-Mega'),
                    ' Premium Account'
                  ])
              ]),
              $.make('ul', { className: 'NB-feedchooser-premium-bullets' }, [
                $.make('li', { className: 'NB-1' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Sites are updated 10x more often.'
                ]),
                $.make('li', { className: 'NB-2' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Unlimited number of sites.'
                ]),
                $.make('li', { className: 'NB-3' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Access to the premium-only River of News.'
                ]),
                $.make('li', { className: 'NB-4' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Access to the future premium-only features like searching and visualizations.'
                ]),
                $.make('li', { className: 'NB-5' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'You feed my poor, hungry dog for 6 days!',
                  $.make('img', { className: 'NB-feedchooser-premium-poor-hungry-dog', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/shiloh.jpg' })
                ]),
                $.make('li', { className: 'NB-6' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'You are supporting an indie developer.'
                ]),
                $.make('li', { className: 'NB-7' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Choose how much you would like to pay.',
                  $.make('div', { style: 'color: #490567' }, 'The only difference is happiness.')
                ])
              ]),
              $.make('div', { className: 'NB-modal-submit NB-modal-submit-paypal' }, [
                  // this.make_google_checkout()
                  $.make('div', { className: 'NB-feedchooser-paypal' }),
                  $.make('div', { className: 'NB-feedchooser-dollar' }, [
                      $.make('div', { className: 'NB-feedchooser-dollar-slider'}),
                      $.make('div', { className: 'NB-feedchooser-dollar-value' }, [
                          $.make('div', { className: 'NB-feedchooser-dollar-month' }),
                          $.make('div', { className: 'NB-feedchooser-dollar-year' })
                      ])
                  ])
              ])
            ])
        ]);
    },
    
    make_paypal_button: function() {
        var self = this;
        var $paypal = $('.NB-feedchooser-paypal', this.$modal);
        $.get('/profile/paypal_form', function(response) {
          $paypal.html(response);
          self.update_dollar_count(1);
        });
    },
    
    make_google_button: function() {
      var checkout = '<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js"></script><form method=POST action="https://payments.amazon.com/checkout/A215TOHXICT770"><input type="hidden" name="order-input" value="type:cba-signed-order/sha1-hmac/1;order:PD94bWwgdmVyc2lvbj0nMS4wJyBlbmNvZGluZz0nVVRGLTgnPz48T3JkZXIgeG1sbnM9J2h0dHA6Ly9wYXltZW50cy5hbWF6b24uY29tL2NoZWNrb3V0LzIwMDgtMTEtMzAvJz48Q2FydD48SXRlbXM+PEl0ZW0+PE1lcmNoYW50SWQ+QTIxNVRPSFhJQ1Q3NzA8L01lcmNoYW50SWQ+PFRpdGxlPk5ld3NCbHVyIFByZW1pdW0gLSAxIFllYXI8L1RpdGxlPjxEZXNjcmlwdGlvbj5UaGFuayB5b3UsIHRoYW5rIHlvdSwgdGhhbmsgeW91ITwvRGVzY3JpcHRpb24+PFByaWNlPjxBbW91bnQ+MTI8L0Ftb3VudD48Q3VycmVuY3lDb2RlPlVTRDwvQ3VycmVuY3lDb2RlPjwvUHJpY2U+PFF1YW50aXR5PjE8L1F1YW50aXR5PjxGdWxmaWxsbWVudE5ldHdvcms+TUVSQ0hBTlQ8L0Z1bGZpbGxtZW50TmV0d29yaz48L0l0ZW0+PC9JdGVtcz48L0NhcnQ+PC9PcmRlcj4=;signature:Zfg83JluKTIhItevtaGpspjdbfQ="><input alt="Checkout with Amazon Payments" src="https://payments.amazon.com/gp/cba/button?ie=UTF8&color=tan&background=white&cartOwnerId=A215TOHXICT770&size=large" type="image"></form>';
      var $checkout = $(checkout);
      return $checkout;
    },
    
    make_feeds: function() {
        var feeds = this.model.feeds;
        
        var $feeds = $('#feed_list').clone(true).attr({
            'id': 'NB-feedchooser-feeds',
            'class': 'NB-feedlist NB-feedchooser unread_view_positive',
            'style': ''
        });
        
        // Expand collapsed folders
        $('.folder', $feeds).css({
            'display': 'block',
            'opacity': 1
        });
        
        // Pretend unfetched feeds are fine
        $('.NB-feed-unfetched', $feeds).removeClass('NB-feed-unfetched');
        
        $('.unread_count_positive', $feeds).text('On');
        $('.unread_count_negative', $feeds).text('Off');
        
        return $feeds;
    },
    
    resize_modal: function(previous_height) {
        var height = this.$modal.height() + 16;
        var parent_height = this.$modal.parent().height();
        if (height > parent_height && previous_height != height) {
            var chooser_height = $('#NB-feedchooser-feeds').height();
            var diff = Math.max(4, height - parent_height);
            $('#NB-feedchooser-feeds').css({'max-height': chooser_height - diff});
            _.defer(_.bind(function() { this.resize_modal(height); }, this), 1);
        }
    },
    
    open_modal: function() {
        var self = this;
        this.$modal.modal({
            'minWidth': 750,
            'maxWidth': 750,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200, function() {
                        _.defer(_.bind(self.resize_modal, self), 10);
                    });
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
            },
            'onClose': function(dialog, callback) {
                if (!self.flags['has_saved'] && !NEWSBLUR.reader.flags['has_chosen_feeds']) {
                    NEWSBLUR.reader.show_feed_chooser_button();
                }
                dialog.data.hide().empty().remove();
                dialog.container.hide().empty().remove();
                dialog.overlay.fadeOut(200, function() {
                    dialog.overlay.empty().remove();
                    $.modal.close(callback);
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    add_feed_to_decline: function(feed_id, update) {
        this.approve_list = _.without(this.approve_list, feed_id);
        var $feed = this.$feeds[feed_id];
        
        $feed.removeClass('NB-feedchooser-approve');
        $feed.addClass('NB-feedchooser-decline');
        if (update) {
            this.update_counts();
        }
    },
    
    add_feed_to_approve: function(feed_id, update) {
        if (!_.contains(this.approve_list, feed_id)) {
            this.approve_list.push(feed_id);
        }
        var $feed = this.$feeds[feed_id];
        $feed.removeClass('NB-feedchooser-decline');
        $feed.addClass('NB-feedchooser-approve');
        if (update) {
            this.update_counts();
        }
    },
        
    find_feeds_in_feed_list: function() {
        var self = this;
        var $feed_list = $('.NB-feedchooser', this.$modal);
        var $feeds = {};
        
        $('.feed', $feed_list).each(function() {
            var feed_id = $(this).data('feed_id');
            if (!(feed_id in $feeds)) {
                $feeds[feed_id] = $([]);
            }
            $feeds[feed_id].push($(this).get(0));
        });

        // Remove invalid feeds that only show up in the assetmodel.
        // This occurs when a feed is still subscribed, but not in the user's folders.
        var found_feeds = _.uniq(_.keys($feeds)).sort();
        var invalid_feeds = _.each(self.model.feeds, function(feed_id) { 
            if (!_.contains(found_feeds, feed_id)) {
                delete self.model.feeds[feed_id];
            }
        });
        
        this.$feeds = $feeds;
    },
    
    update_counts: function() {
        var $count = $('.NB-feedchooser-info-counts');
        var approved = this.approve_list.length;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var difference = approved - this.MAX_FEEDS;
        
        $count.text(approved + '/' + this.MAX_FEEDS);
        $count.toggleClass('NB-full', approved == this.MAX_FEEDS);
        $count.toggleClass('NB-error', approved > this.MAX_FEEDS);
        $('.NB-feedchooser-info-sort', this.$modal).fadeOut(500);
        if (approved > this.MAX_FEEDS) {
          $submit.addClass('NB-disabled').attr('disabled', true).val('Too many sites! Deselect ' + (
            difference == 1 ?
            '1 site...' :
            difference + ' sites...'
          ));
        } else {
          $submit.removeClass('NB-disabled').attr('disabled', false).val('Turn on these '+ approved +' sites, please');
        }
    },
    
    initial_load_feeds: function() {
        var start = new Date();
        var self = this;
        var $feeds = $('.feed', this.$modal);
        var feeds = this.model.get_feeds();
        
        if (!_.keys(feeds).length) {
            _.defer(_.bind(function() {
                var $info = $('.NB-feedchooser-info', this.$modal);
                $('.NB-feedchooser-info-counts', $info).hide();
                $('.NB-feedchooser-info-sort', $info).hide();
                $('#NB-feedchooser-feeds').hide();
                $('.NB-modal-submit-save').hide();
                $('.NB-modal-submit-add').show();
            }, this));
            return;
        }
        
        var active_feeds = _.any(_.pluck(feeds, 'active'));
        if (!active_feeds) {
            // Get feed subscribers
            var min_subscribers = _.last(
              _.first(
                _.pluck(_.select(this.model.get_feeds(), function(f) { return !f.has_exception; }), 'subs').sort(function(a,b) { 
                  return b-a; 
                }), 
                this.MAX_FEEDS
              )
            );
        
            // Decline everything
            var approve_feeds = [];
            _.each(feeds, function(feed, feed_id) {
                self.add_feed_to_decline(parseInt(feed_id, 10));
            
                if (feed['subs'] >= min_subscribers) {
                    approve_feeds.push(parseInt(feed_id, 10));
                }
            });
        
            // Approve feeds in subs
            _.each(approve_feeds, function(feed_id) {
                if (self.model.get_feed(feed_id)['subs'] > min_subscribers &&
                    self.approve_list.length < self.MAX_FEEDS &&
                    !self.model.get_feed(feed_id)['has_exception']) {
                    self.add_feed_to_approve(feed_id);
                }
            });
            _.each(approve_feeds, function(feed_id) {
                if (self.model.get_feed(feed_id)['subs'] == min_subscribers &&
                    self.approve_list.length < self.MAX_FEEDS) {
                    self.add_feed_to_approve(feed_id);
                }
            });
        } else {
            // Get active feeds
            var active_feeds = _.pluck(_.select(feeds, function(feed) {
                if (feed.active) return true;
            }), 'id');
            this.approve_list = active_feeds;
            
            // Approve or decline
            var feeds = [];
            $feeds.each(function() {
                var feed_id = $(this).data('feed_id');
                
                if (_.contains(active_feeds, feed_id)) {
                    self.add_feed_to_approve(feed_id);
                } else {
                    self.add_feed_to_decline(feed_id);
                }
            });
        }
        _.defer(_.bind(function() { this.update_counts(); }, this));
    },
    
    save: function() {
        var self = this;
        var approve_list = this.approve_list;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        $submit.addClass('NB-disabled').val('Saving...');
        this.update_homepage_count();
        
        this.model.save_feed_chooser(approve_list, function() {
            self.flags['has_saved'] = true;
            NEWSBLUR.reader.hide_feed_chooser_button();
            NEWSBLUR.reader.load_feeds();
            $.modal.close();
        });
    },
    
    close_and_add: function() {
        $.modal.close(function() {
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed();
        });
    },
    
    update_homepage_count: function() {
      var $count = $('.NB-module-account-feedcount');
      var $button = $('.NB-module-account-upgrade');
      var approve_list = this.approve_list;
      
      $count.text(approve_list.length);
      $button.removeClass('NB-modal-submit-green').addClass('NB-modal-submit-close');
      $('.NB-module-account-trainer').removeClass('NB-hidden').hide().slideDown(500);
    },
    
    setup_dollar_slider: function() {
        var self = this;
        
        $('.NB-feedchooser-dollar-slider', this.$modal).slider({
            range: 'max',
            min: 0,
            max: 2,
            step: 1,
            value: 1,
            slide: function(e, ui) {
                self.update_dollar_count(ui.value);
            },
            stop: function(e, ui) {
                self.update_dollar_count(ui.value);
            }
        }).change();
    },
    
    update_dollar_count: function(step) {
        var $month = $('.NB-feedchooser-dollar-month', this.$modal);
        var $year = $('.NB-feedchooser-dollar-year', this.$modal);
        var $dollar = $('.NB-feedchooser-dollar', this.$modal);
        var $input = $('input[name=a3]');
        
        $dollar.removeClass('NB-0').removeClass('NB-1').removeClass('NB-2').addClass('NB-'+step);
        if (step == 0) {
            $month.text('$1/month');
            $year.text('($12/year)');
            $input.val(12);
        } else if (step == 1) {
            $month.text('$2/month');
            $year.text('($24/year)');
            $input.val(24);
        } else if (step == 2) {
            $month.text('$5/month');
            $year.text('($64/year)');
            $input.val(64);
        }
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
                this.add_feed_to_decline(feed_id, true);
            } else {
                this.add_feed_to_approve(feed_id, true);
            }
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.save();
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-add' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.close_and_add();
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