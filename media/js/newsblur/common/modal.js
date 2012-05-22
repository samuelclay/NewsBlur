NEWSBLUR.Modal = function(options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
    this.flags = {};
};

NEWSBLUR.Modal.prototype = {
  
    runner: function() {},
    
    open_modal: function(callback) {
        var self = this;
        
        this.$modal.modal({
            'minWidth': 600,
            'maxWidth': 600,
            'overlayClose': true,
            'onOpen': function (dialog) {
                self.flags.open = true;
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200, function() {
                        if (self.options.onOpen) {
                            self.options.onOpen();
                        }
                    });
                    setTimeout(function() {
                        $(window).resize();
                    });
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
                if (self.options.onShow) {
                    self.options.onShow();
                }
            },
            'onClose': function(dialog, callback) {
                self.flags.open = false;
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
    
    resize: function() {
      $(window).trigger('resize.simplemodal');
    },
    
    close: function(callback) {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        $.modal.close(callback);
    },
    
    make_feed_chooser: function() {
        var $chooser = $.make('select', { name: 'feed', className: 'NB-modal-feed-chooser' });
        var current_feed_id = this.feed_id;
        this.feeds = this.model.get_feeds();
        
        this.feeds.each(function(feed) {
            var $option = $.make('option', { value: feed.id }, feed.get('feed_title'));
            $option.appendTo($chooser);
            
            if (feed.id == current_feed_id) {
                $option.attr('selected', true);
            }
        });
        
        $('option', $chooser).tsort();
        return $chooser;
    },
    
    initialize_feed: function(feed_id) {
        this.feed_id = feed_id;
        this.feed = this.model.get_feed(feed_id);
        this.options.social_feed = this.feed.is_social();
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', $.favicon(this.feed));
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed.get('feed_title'));
        $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).html(Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true));
    }
    

    
};