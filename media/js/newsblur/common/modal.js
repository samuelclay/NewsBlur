NEWSBLUR.Modal = function(options) {
    var defaults = {
        width: 600
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
        
        this.$modal.modal({
            'minWidth': this.options.width || 600,
            'maxWidth': this.options.width || 600,
            'overlayClose': true,
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
    
    make_feed_chooser: function(options) {
        options = options || {};
        var $chooser = $.make('select', { name: 'feed', className: 'NB-modal-feed-chooser' });
        var $feeds_optgroup = $.make('optgroup', { label: "Sites" });
        var $social_feeds_optgroup = $.make('optgroup', { label: "Blurblogs" });
        var $starred_feeds_optgroup = $.make('optgroup', { label: "Saved Tags" });
        var current_feed_id = this.feed_id;
        
        var make_feed_option = function(feed) {
            if (!feed.get('feed_title')) return;
            
            var $option = $.make('option', { value: feed.id }, feed.get('feed_title'));
            $option.appendTo(feed.is_starred() ? $starred_feeds_optgroup : 
                             feed.is_social() ? $social_feeds_optgroup : 
                             $feeds_optgroup);
            
            if (feed.id == current_feed_id) {
                $option.attr('selected', true);
            }
        };
        
        this.feeds = this.model.get_feeds();
        this.feeds.each(make_feed_option);
        
        if (!options.skip_social) {
            this.social_feeds = this.model.get_social_feeds();
            this.social_feeds.each(make_feed_option);
        }
        
        if (!options.skip_starred) {
            this.starred_feeds = this.model.get_starred_feeds();
            this.starred_feeds.each(make_feed_option);
        }
        
        $('option', $feeds_optgroup).tsort();
        $('option', $social_feeds_optgroup).tsort();
        $('option', $starred_feeds_optgroup).tsort();
        
        $chooser.append($feeds_optgroup);
        if (!options.skip_social) {
            $chooser.append($social_feeds_optgroup);
        }
        if (!options.skip_starred) {
            $chooser.append($starred_feeds_optgroup);
        }
        
        return $chooser;
    },
    
    initialize_feed: function(feed_id) {
        this.feed_id = feed_id;
        this.feed = this.model.get_feed(feed_id);
        this.options.social_feed = this.feed && this.feed.is_social();
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', $.favicon(this.feed));
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed.get('feed_title'));
        $('.NB-modal-subtitle .NB-modal-feed-subscribers', this.$modal).html(Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true)).show();
    },
    
    initialize_folder: function(folder_title) {
        this.folder_title = folder_title;
        this.folder = this.model.get_folder(folder_title);
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/g_icn_folder.png');
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