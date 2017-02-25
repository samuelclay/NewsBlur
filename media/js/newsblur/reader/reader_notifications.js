NEWSBLUR.ReaderNotifications = function(feed_id, options) {
    var defaults = {
        'onOpen': function() {
            $(window).trigger('resize.simplemodal');
        }
    };
        
    this.options = $.extend({}, defaults, options);
    this.model   = NEWSBLUR.assets;
    this.feed_id = feed_id;
    this.feed    = this.model.get_feed(feed_id);
    
    this.runner();
};

NEWSBLUR.ReaderNotifications.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderNotifications.prototype.constructor = NEWSBLUR.ReaderNotifications;

_.extend(NEWSBLUR.ReaderNotifications.prototype, {
    
    runner: function() {
        console.log(['Reader notifications', this.feed, this.feed_id]);
        this.make_modal();
        this.handle_cancel();
        this.open_modal();
        if (this.feed_id) {
            this.initialize_feed(this.feed_id);
        }
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },

    initialize_feed: function(feed_id) {
        var frequency = this.feed.get('notification_frequency');
        var notifications = this.feed.get('notifications');

        NEWSBLUR.Modal.prototype.initialize_feed.call(this, feed_id);
        
        var $site = $(".NB-modal-section-site", this.$modal);
        $site.html(this.make_feed_notification(this.feed));

        var $all = $(".NB-modal-section-all", this.$modal);
        $all.html(this.make_feed_notifications());
        
        this.resize();
    },
    
    get_feed_settings: function() {
        if (this.feed.is_starred()) return;
        
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        var settings_fn = this.options.social_feed ? this.model.get_social_settings :
                          this.model.get_feed_settings;
        settings_fn.call(this.model, this.feed_id, _.bind(this.populate_settings, this));
    },
    
    populate_settings: function(data) {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        
        $loading.removeClass('NB-active');
        this.resize();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-notifications NB-modal' }, [
            (this.feed && $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                this.make_feed_chooser()
            ])),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-modal-loading' }),
                $.make('div', { className: 'NB-icon' }),
                'Notifications',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            (this.feed && $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('fieldset', [
                    $.make('legend', 'Site Notifications'),
                    $.make('div', { className: 'NB-modal-section NB-modal-section-site'}, [
                        this.make_feed_notification(this.feed)
                    ])
                ])
            ])),
            $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                $.make('fieldset', [
                    $.make('legend', 'All Notifications'),
                    $.make('div', { className: 'NB-modal-section NB-modal-section-all'}, [
                        this.make_feed_notifications()
                    ])
                ])
            ])
        ]);
    },
    
    handle_cancel: function() {
        var $cancel = $('.NB-modal-cancel', this.$modal);
        
        $cancel.click(function(e) {
            e.preventDefault();
            $.modal.close();
        });
    },
    
    make_feed_notification: function(feed) {
        var $feed = new NEWSBLUR.Views.FeedNotificationView({model: feed});
        
        return $feed.render().$el;
    },
    
    make_feed_notifications: function() {
        var site_feed_id = this.feed && this.feed.id;
        var notifications = this.model.get_feeds().select(function(feed) {
            return feed.get('notification_types') && feed.id != site_feed_id;
        });
        var $feeds = [];
        
        notifications.sort(function(a, b) { return a.get('feed_title') < b.get('feed_title'); });
        for (var feed in notifications) {
            $feeds.push(this.make_feed_notification(notifications[feed]));
        }
        
        return $feeds;
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
    
        $.targetIs(e, { tagSelector: '.NB-modal-submit-retry' }, function($t, $p) {
            e.preventDefault();
            
            self.save_retry_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-delete' }, function($t, $p) {
            e.preventDefault();
            
            self.delete_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-address' }, function($t, $p) {
            e.preventDefault();
            
            self.change_feed_address();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-link' }, function($t, $p) {
            e.preventDefault();
            
            self.change_feed_link();
        });
        $.targetIs(e, { tagSelector: '.NB-premium-only-link' }, function($t, $p){
            e.preventDefault();
            
            self.close(function() {
                NEWSBLUR.reader.open_feedchooser_modal({premium_only: true});
            });
        });
    },
    
    animate_saved: function() {
        var $status = $('.NB-exception-option-view .NB-exception-option-status', this.$modal);
        $status.text('Saved').animate({
            'opacity': 1
        }, {
            'queue': false,
            'duration': 600,
            'complete': function() {
                _.delay(function() {
                    $status.animate({'opacity': 0}, {'queue': false, 'duration': 1000});
                }, 300);
            }
        });
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function($t, $p){
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_feed_settings();
        });
    }
    
});