NEWSBLUR.ReaderFeedchooser = function(options) {
    var defaults = {};

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
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
        this.choose_dollar_amount(2);
        
        this.flags = {
            'has_saved': false
        };
        
        this.$modal.bind('mousedown', $.rescope(this.handle_click, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-feedchooser NB-modal' }, [
            // $.make('h2', { className: 'NB-modal-title' }, 'Choose Your '+this.MAX_FEEDS),
            $.make('div', { className: 'NB-feedchooser-type NB-feedchooser-left'}, [
              $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                        $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, 'Free'),
                        ' Standard Account'
                  ]),
                    $.make('h2', { className: 'NB-modal-subtitle' }, [
                        $.make('b', [
                            'You can follow up to '+this.MAX_FEEDS+' sites.'
                        ]),
                        $.make('br'),
                        'You can always change these.'
                    ]),
                  $.make('div', { className: 'NB-feedchooser-info-counts'}),
                  $.make('div', { className: 'NB-feedchooser-info-sort'}, 'Auto-Selected By Popularity'),
                  $.make('div', { className: 'NB-feedchooser-info-reset NB-splash-link'}, 'Reset to popular sites')
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
            $.make('div', { className: 'NB-feedchooser-type NB-last', style: 'position: relative'}, [
              $.make('div', { className: 'NB-feedchooser-porpoise' }, 'OR'),

              $.make('div', { className: 'NB-feedchooser-info'}, [
                  $.make('div', { className: 'NB-feedchooser-info-type' }, [
                    $.make('span', { className: 'NB-feedchooser-subtitle-type-prefix' }, 'Super-Mega'),
                    ' Premium Account'
                  ])
              ]),
              $.make('ul', { className: 'NB-feedchooser-premium-bullets' }, [
                $.make('li', { className: 'NB-1' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Enable every site by going premium'
                ]),
                $.make('li', { className: 'NB-2' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Sites updated up to 10x more often'
                ]),
                $.make('li', { className: 'NB-3' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'River of News (reading by folder)'
                ]),
                $.make('li', { className: 'NB-4' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Privacy options for your blurblog'
                ]),
                $.make('li', { className: 'NB-5' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'You feed my poor, hungry dog for ',
                  $.make('span', { className: 'NB-feedchooser-hungry-dog' }, '6 days'),
                  $.make('img', { className: 'NB-feedchooser-premium-poor-hungry-dog', src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/shiloh.jpg' })
                ]),
                $.make('li', { className: 'NB-6' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'You are directly supporting a young startup'
                ]),
                $.make('li', { className: 'NB-7' }, [
                  $.make('div', { className: 'NB-feedchooser-premium-bullet-image' }),
                  'Choose how much you would like to pay',
                  $.make('div', { style: 'color: #490567' }, 'The only difference is happiness')
                ])
              ]),
              $.make('div', { className: 'NB-modal-submit NB-modal-submit-paypal' }, [
                  // this.make_google_checkout()
                  $.make('div', { className: 'NB-feedchooser-dollar' }, [
                      $.make('div', { className: 'NB-feedchooser-dollar-value NB-1' }, [
                          $.make('div', { className: 'NB-feedchooser-dollar-month' }, [
                            $.make('div', { className: 'NB-feedchooser-dollar-image' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/hamburger_s.png', style: "position: absolute; left: 8px;top: 9px"  })
                            ]),
                            '$12/year'
                          ]),
                          $.make('div', { className: 'NB-feedchooser-dollar-year' }, '($1/month)')
                      ]),
                      $.make('div', { className: 'NB-feedchooser-dollar-value NB-2' }, [
                          $.make('div', { className: 'NB-feedchooser-dollar-month' }, [
                            $.make('div', { className: 'NB-feedchooser-dollar-image' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/hamburger_s.png', style: "position: absolute; left: -24px;top: 9px" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/hamburger_m.png', style: "position: absolute; left: 4px;top: 6px"  })
                            ]),
                            '$24/year'
                          ]),
                          $.make('div', { className: 'NB-feedchooser-dollar-year' }, '($2/month)')
                      ]),
                      $.make('div', { className: 'NB-feedchooser-dollar-value NB-3' }, [
                          $.make('div', { className: 'NB-feedchooser-dollar-month' }, [
                            $.make('div', { className: 'NB-feedchooser-dollar-image' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/hamburger_s.png', style: "position: absolute; left: -58px;top: 10px" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/hamburger_m.png', style: "position: absolute; left: -31px;top: 8px" }),
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/hamburger_l.png', style: "position: absolute; left: 0; top: 6px" })
                            ]),
                            '$36/year'
                          ]),
                          $.make('div', { className: 'NB-feedchooser-dollar-year' }, '($3/month)')
                      ])
                  ]),
                  $.make('div', { className: 'NB-feedchooser-processor' }, [
                      $.make('div', { className: 'NB-feedchooser-paypal' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/logo-paypal.png', height: 30 }),
                        $.make('div', { className: 'NB-feedchooser-paypal-form' })
                      ]),
                      $.make('div', { className: 'NB-feedchooser-stripe' }, [
                        $.make('div', { className: 'NB-creditcards' }, [
                            $.make('img', { src: "https://manage.stripe.com/img/credit_cards/visa.png" }),
                            $.make('img', { src: "https://manage.stripe.com/img/credit_cards/mastercard.png" }),
                            $.make('img', { src: "https://manage.stripe.com/img/credit_cards/amex.png" }),
                            $.make('img', { src: "https://manage.stripe.com/img/credit_cards/discover.png" })
                        ]),
                        $.make('div', { 
                            className: "NB-stripe-button NB-modal-submit-button NB-modal-submit-green"
                        }, [
                            "Pay by",
                            $.make('br'),
                            "Credit Card"
                        ])
                      ])
                  ])
              ])
            ])
        ]);
    },
    
    make_paypal_button: function() {
        var self = this;
        var $paypal = $('.NB-feedchooser-paypal-form', this.$modal);
        $.get('/profile/paypal_form', function(response) {
          $paypal.html(response);
          self.choose_dollar_amount(2);
        });
    },
    
    make_google_button: function() {
      var checkout = '<script type="text/javascript" src="https://images-na.ssl-images-amazon.com/images/G/01/cba/js/widget/widget.js"></script><form method=POST action="https://payments.amazon.com/checkout/A215TOHXICT770"><input type="hidden" name="order-input" value="type:cba-signed-order/sha1-hmac/1;order:PD94bWwgdmVyc2lvbj0nMS4wJyBlbmNvZGluZz0nVVRGLTgnPz48T3JkZXIgeG1sbnM9J2h0dHA6Ly9wYXltZW50cy5hbWF6b24uY29tL2NoZWNrb3V0LzIwMDgtMTEtMzAvJz48Q2FydD48SXRlbXM+PEl0ZW0+PE1lcmNoYW50SWQ+QTIxNVRPSFhJQ1Q3NzA8L01lcmNoYW50SWQ+PFRpdGxlPk5ld3NCbHVyIFByZW1pdW0gLSAxIFllYXI8L1RpdGxlPjxEZXNjcmlwdGlvbj5UaGFuayB5b3UsIHRoYW5rIHlvdSwgdGhhbmsgeW91ITwvRGVzY3JpcHRpb24+PFByaWNlPjxBbW91bnQ+MTI8L0Ftb3VudD48Q3VycmVuY3lDb2RlPlVTRDwvQ3VycmVuY3lDb2RlPjwvUHJpY2U+PFF1YW50aXR5PjE8L1F1YW50aXR5PjxGdWxmaWxsbWVudE5ldHdvcms+TUVSQ0hBTlQ8L0Z1bGZpbGxtZW50TmV0d29yaz48L0l0ZW0+PC9JdGVtcz48L0NhcnQ+PC9PcmRlcj4=;signature:Zfg83JluKTIhItevtaGpspjdbfQ="><input alt="Checkout with Amazon Payments" src="https://payments.amazon.com/gp/cba/button?ie=UTF8&color=tan&background=white&cartOwnerId=A215TOHXICT770&size=large" type="image"></form>';
      var $checkout = $(checkout);
      return $checkout;
    },
    
    make_feeds: function() {
        var feeds = this.model.feeds;
        this.feed_count = feeds.size();
        
        var $feeds = new NEWSBLUR.Views.FeedList({
            feed_chooser: true
        }).make_feeds().$el;
        
        if ($feeds.data('sortable')) $feeds.data('sortable').disable();
        
        // Expand collapsed folders
        $('.NB-folder-collapsed', $feeds).css({
            'display': 'block',
            'opacity': 1
        }).removeClass('NB-folder-collapsed');
        
        // Pretend unfetched feeds are fine
        $('.NB-feed-unfetched', $feeds).removeClass('NB-feed-unfetched');
        
        $('.unread_count_positive', $feeds).text('On');
        $('.unread_count_negative', $feeds).text('Off');
        
        return $feeds;
    },

    resize_modal: function(previous_height) {
        var content_height = $('.NB-feedchooser-left', this.$modal).height() + 32;
        var container_height = this.$modal.parent().height();
        if (content_height > container_height && previous_height != content_height) {
            var chooser_height = $('#NB-feedchooser-feeds').height();
            var diff = Math.max(4, content_height - container_height);
            $('#NB-feedchooser-feeds').css({'max-height': chooser_height - diff});
            _.defer(_.bind(function() { this.resize_modal(content_height); }, this), 1);
        }
    },
    
    open_modal: function() {
        var self = this;
        this.$modal.modal({
            'minWidth': 860,
            'maxWidth': 860,
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
                if (!self.flags['has_saved'] && !self.model.flags['has_chosen_feeds']) {
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
        
        if (!$feed) return;
        
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
        
        if (!$feed) return;
        
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
            var feed_id = parseInt($(this).data('id'), 10);
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
    
    update_counts: function(initial_load) {
        var $count = $('.NB-feedchooser-info-counts');
        var approved = this.approve_list.length;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var difference = approved - this.MAX_FEEDS;
        
        $count.text(approved + '/' + Inflector.commas(this.feed_count));
        $count.toggleClass('NB-full', approved == this.MAX_FEEDS);
        $count.toggleClass('NB-error', approved > this.MAX_FEEDS);

        if (!initial_load) {
            this.hide_autoselected_label();
        }
        if (approved > this.MAX_FEEDS) {
          $submit.addClass('NB-disabled').addClass('NB-modal-submit-grey').attr('disabled', true).val('Too many sites! Deselect ' + (
            difference == 1 ?
            '1 site...' :
            difference + ' sites...'
          ));
        } else {
          $submit.removeClass('NB-disabled').removeClass('NB-modal-submit-grey').attr('disabled', false).val('Turn on these '+ approved +' sites, please');
        }
    },
    
    initial_load_feeds: function(reset) {
        var start = new Date();
        var self = this;
        var $feeds = $('.feed', this.$modal);
        var feeds = this.model.get_feeds();

        if (!feeds.size()) {
            _.defer(_.bind(function() {
                var $info = $('.NB-feedchooser-info', this.$modal);
                $('.NB-feedchooser-info-counts', $info).hide();
                $('.NB-feedchooser-info-sort', $info).hide();
                $('.NB-feedchooser-info-reset', $info).hide();
                $('#NB-feedchooser-feeds').hide();
                $('.NB-modal-submit-save').hide();
                $('.NB-modal-submit-add').show();
            }, this));
            return;
        }
        
        var active_feeds = feeds.any(function(feed) { return feed.get('active'); });
        if (!active_feeds || reset) {
            // Get feed subscribers bottom cut-off
            var min_subscribers = _.last(
              _.first(
                _.map(feeds.select(function(f) { return !f.has_exception; }), function(f) { return f.get('subs'); }).sort(function(a,b) { 
                  return b-a; 
                }), 
                this.MAX_FEEDS
              )
            );
        
            // Decline everything
            var approve_feeds = [];
            feeds.each(function(feed) {
                self.add_feed_to_decline(parseInt(feed.id, 10));
            
                if (feed.get('subs') >= min_subscribers) {
                    approve_feeds.push(parseInt(feed.id, 10));
                }
            });
        
            // Approve feeds in subs
            _.each(approve_feeds, function(feed_id) {
                if (feeds.get(feed_id).get('subs') > min_subscribers &&
                    self.approve_list.length < self.MAX_FEEDS &&
                    !self.model.get_feed(feed_id)['has_exception']) {
                    self.add_feed_to_approve(feed_id);
                }
            });
            _.each(approve_feeds, function(feed_id) {
                if (self.model.get_feed(feed_id).get('subs') == min_subscribers &&
                    self.approve_list.length < self.MAX_FEEDS) {
                    self.add_feed_to_approve(feed_id);
                }
            });
            
            this.show_autoselected_label();
        } else {
            // Get active feeds
            var active_feeds = _.pluck(feeds.select(function(feed) {
                return feed.get('active');
            }), 'id');
            this.approve_list = active_feeds;
            
            // Approve or decline
            var feeds = [];
            $feeds.each(function() {
                var feed_id = parseInt($(this).data('id'), 10);
                
                if (_.contains(active_feeds, feed_id)) {
                    self.add_feed_to_approve(feed_id);
                } else {
                    self.add_feed_to_decline(feed_id);
                }
            });
            
            _.defer(_.bind(function() { this.hide_autoselected_label(); }, this));
        }
        _.defer(_.bind(function() { this.update_counts(true); }, this));
    },
    
    show_autoselected_label: function() {
        $('.NB-feedchooser-info-reset', this.$modal).fadeOut(500, _.bind(function() {
            $('.NB-feedchooser-info-sort', this.$modal).fadeIn(500);
        }, this));
    },
    
    hide_autoselected_label: function() {
        $('.NB-feedchooser-info-sort', this.$modal).fadeOut(500, _.bind(function() {
            $('.NB-feedchooser-info-sort', this.$modal).hide();
            $('.NB-feedchooser-info-reset', this.$modal).fadeIn(500);
        }, this));
    },
    
    save: function() {
        var self = this;
        var approve_list = this.approve_list;
        var $submit = $('.NB-modal-submit-save', this.$modal);
        $submit.addClass('NB-disabled').removeClass('NB-modal-submit-green').val('Saving...');
        this.update_homepage_count();
        
        this.model.save_feed_chooser(approve_list, function() {
            self.flags['has_saved'] = true;
            NEWSBLUR.reader.hide_feed_chooser_button();
            NEWSBLUR.assets.load_feeds();
            $.modal.close();
        });
    },
    
    close_and_add: function() {
        $.modal.close(function() {
            NEWSBLUR.add_feed = new NEWSBLUR.ReaderAddFeed();
        });
    },
    
    open_stripe_form: function() {
        window.location.href = "https://" + NEWSBLUR.URLs.domain + "/profile/stripe_form?plan=" + this.plan;
    },
    
    update_homepage_count: function() {
      var $count = $('.NB-module-account-feedcount');
      var $site_count = $('.NB-module-account-trainer-site-count');
      var $button = $('.NB-module-account-upgrade');
      var approve_list = this.approve_list;
      
      $count.text(approve_list.length);
      $site_count.text(Inflector.pluralize('site', approve_list.length, true));
      $button.removeClass('NB-modal-submit-green').addClass('NB-modal-submit-grey');
      $('.NB-module-account-trainer').removeClass('NB-hidden').hide().slideDown(500);
    },
    
    choose_dollar_amount: function(plan) {
        var $value = $('.NB-feedchooser-dollar-value', this.$modal);
        var $input = $('input[name=a3]');
        var $days = $('.NB-feedchooser-hungry-dog', this.$modal);
        
        this.plan = plan;

        $value.removeClass('NB-selected');
        $value.filter('.NB-'+plan).addClass('NB-selected');
        if (plan == 1) {
            $input.val(12);
            $days.text('6 days');
        } else if (plan == 2) {
            $input.val(24);
            $days.text('12 days');
        } else if (plan == 3) {
            $input.val(36);
            $days.text('18 days');
        }
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.feed' }, _.bind(function($t, $p) {
            e.preventDefault();
            
            var feed_id = parseInt($t.attr('data-id'), 10);
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
        
        $.targetIs(e, { tagSelector: '.NB-stripe-button' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.open_stripe_form();
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-feedchooser-info-reset' }, _.bind(function($t, $p) {
            e.preventDefault();
            this.initial_load_feeds(true);
        }, this));
        
        $.targetIs(e, { tagSelector: '.NB-feedchooser-dollar-value' }, _.bind(function($t, $p) {
            e.preventDefault();
            var step;
            if ($t.hasClass('NB-1')) {
                step = 1;
            } else if ($t.hasClass('NB-2')) {
                step = 2;
            } else if ($t.hasClass('NB-3')) {
                step = 3;
            }
            this.choose_dollar_amount(step);
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