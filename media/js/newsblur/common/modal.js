NEWSBLUR.Modal = function(options) {
    var defaults = {
        width: 600,
        overlayClose: true
    };
    
    this.options = _.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.runner();
    this.flags = {};
};

NEWSBLUR.Modal.prototype = {
  
    runner: function() {},
    
    open_modal: function(callback) {
        var self = this;
        
        this.simplemodal = this.$modal.modal({
            'minWidth': this.options.width || 600,
            'maxWidth': this.options.width || 600,
            'overlayClose': this.options.overlayClose,
            'onOpen': function (dialog) {
                self.flags.open = true;
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.addClass(self.options.modal_container_class);
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200, function() {
                        if (self.options.onOpen) {
                            self.options.onOpen();
                        }
                        if (callback) {
                            callback();
                        }
                    });
                    setTimeout(function() {
                        // $(window).resize();
                        self.resize();
                        self.flags.modal_loaded = true;
                    }, 0);
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
                    if (self.options.onOpen) {
                        self.options.onOpen();
                    }
                    dialog.overlay.empty().remove();
                    $.modal.close(callback);
                });
                $('.NB-modal-holder').empty().remove();
            }
        });
    },
    
    resize: function() {
      // $(window).trigger('resize.simplemodal');
      $.modal.resize();
    },
    
    close: function(callback) {
        $('.NB-modal-loading', this.$modal).removeClass('NB-active');
        $.modal.close(callback);
    },
    
    make_feed_chooser: function (options) {
        options = options || {};
        options.selected_folder_title = this.model.folder_title;
        options.feed_id = this.feed_id;
        
        return NEWSBLUR.utils.make_feed_chooser(options);
    },
    
    initialize_feed: function(feed_id) {
        this.feed_id = feed_id;
        if (this.options.embedded) {
          this.feed = NEWSBLUR.stats_feed;
        } else {
          this.feed = this.model.get_feed(feed_id);
        }
        this.options.social_feed = this.feed && this.feed.is_social();
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', $.favicon(this.feed));
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed.get('feed_title'));
        $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).html(Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true)).show();
    },
    
    initialize_folder: function(folder_title) {
        this.folder_title = folder_title;
        this.folder = this.model.get_folder(folder_title);
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', NEWSBLUR.Globals.MEDIA_URL + '/img/icons/nouns/folder-open.svg');
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.folder_title);
        $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).hide();
    },
    
    switch_tab: function(newtab) {
        var $modal_tabs = $('.NB-modal-tab', this.$modal);
        var $tabs = $('.NB-tab', this.$modal);
        
        $modal_tabs.removeClass('NB-active');
        $tabs.removeClass('NB-active');
        
        $modal_tabs.filter('.NB-modal-tab-'+newtab).addClass('NB-active');
        $tabs.filter('.NB-tab-'+newtab).addClass('NB-active');
    }
    
};
