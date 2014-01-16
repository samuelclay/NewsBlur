NEWSBLUR.ReaderRecommendFeed = function(feed_id, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.feed_id = feed_id;
    this.feed = this.model.get_feed(feed_id);
    this.feeds = this.model.get_feeds();
    this.first_load = true;
    this.runner();
};

NEWSBLUR.ReaderRecommendFeed.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderRecommendFeed.prototype.constructor = NEWSBLUR.ReaderRecommendFeed;

_.extend(NEWSBLUR.ReaderRecommendFeed.prototype, {
        
    runner: function() {
        this.make_modal();
        this.open_modal();
        _.delay(_.bind(function() {
            this.get_tagline();
        }, this), 50);
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-recommend NB-modal' }, [
            $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                this.make_feed_chooser({skip_starred: true, skip_social: true})
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, [
                $.make('div', { className: 'NB-icon' }),
                'Recommend this Site',
                $.make('div', { className: 'NB-icon-dropdown' })
            ]),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title')),
                    $.make('span', { className: 'NB-modal-feed-subscribers' }, Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true))
                ])
            ]),
            $.make('div', { className: 'NB-modal-recommend-explanation' }, [
                "Spruce up the site's tagline. If chosen, this site will enjoy a week on the NewsBlur dashboard."
            ]),
            $.make('div', { className: 'NB-modal-recommend-tagline-container' }, [
                $.make('textarea', { className: 'NB-modal-recommend-tagline' })
            ]),
            $.make('div', { className: 'NB-modal-recommend-credit' }, [
              '&raquo; Want credit? Enter your Twitter username: ',
              $.make('input', { className: 'NB-input NB-modal-recommend-twitter' })
            ]),
            $.make('form', { className: 'NB-recommend-form' }, [
                $.make('div', { className: 'NB-modal-submit' }, [
                    $.make('input', { type: 'submit', className: 'NB-modal-submit-save NB-modal-submit-green', value: 'Recommend Site' }),
                    ' or ',
                    $.make('a', { href: '#', className: 'NB-modal-cancel' }, 'cancel')
                ])
            ])
        ]);
    },
    
    get_tagline: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        this.model.get_feed_recommendation_info(this.feed_id, _.bind(this.populate_tagline, this));
    },
    
    populate_tagline: function(data) {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.removeClass('NB-active');
        
        $('.NB-modal-recommend-tagline', this.$modal).val(data.tagline);

        if (data.previous_recommendation) {
            $submit.addClass('NB-disabled').val('Previously Recommended on: ' + data.previous_recommendation);
        } else {
            $submit.removeClass('NB-disabled').val('Recommend Site');
        }
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
                    setTimeout(function() {
                        $(window).resize();
                    });
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
    
    save : function() {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        $submit.addClass('NB-disabled').val('Saving...');
        
        this.model.save_recommended_site({
            feed_id : this.feed_id,
            tagline : $('.NB-modal-recommend-tagline').val(),
            twitter : $('.NB-modal-recommend-twitter').val()
        }, function() {
            $.modal.close();
        });
    },
    
    // ===========
    // = Actions =
    // ===========

    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-cancel' }, function($t, $p) {
            e.preventDefault();
            $.modal.close();
        });
        
        $.targetIs(e, { tagSelector: '.NB-modal-submit-save' }, function($t, $p) {
            e.preventDefault();
            if (!$t.hasClass('NB-disabled')) {
                self.save();
            }
        });
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function($t, $p){
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_tagline();
        });
    }
    
});