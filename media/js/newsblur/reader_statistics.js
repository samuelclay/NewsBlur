NEWSBLUR.ReaderStatistics = function(feed_id, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.feed_id = feed_id;
    this.feed = this.model.get_feed(feed_id);
    this.runner();
};

NEWSBLUR.ReaderStatistics.prototype = {
    
    runner: function() {
        this.make_modal();
        this.open_modal();
        this.get_stats();
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-statistics NB-modal' }, [
            $.make('h2', { className: 'NB-modal-title' }, 'Statistics &amp; History'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-statistics-feed-image feed_favicon', src: this.google_favicon_url + this.feed.feed_link }),
                $.make('span', { className: 'NB-modal-statistics-feed-title' }, this.feed.feed_title)
            ])
        ]);
    },
    
    open_modal: function() {
        var self = this;

        var $holder = $.make('div', { className: 'NB-modal-holder' }).append(this.$modal).appendTo('body').css({'visibility': 'hidden', 'display': 'block', 'width': 600});
        var height = $('.NB-add', $holder).outerHeight(true);
        $holder.css({'visibility': 'visible', 'display': 'none'});
        
        var w = $.modal.impl.getDimensions();
        if (height > w[0] - 70) {
            height = w[0] - 70;
        }
        
        this.$modal.modal({
            'minWidth': 600,
            'maxHeight': height,
            'overlayClose': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px').css({'width': 600, 'height': height});
                $.modal.impl.setPosition();
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
    
    get_stats: function() {
        this.model.get_feed_statistics(this.feed_id, $.rescope(this.populate_stats, this));
    },
    
    populate_stats: function(s, data) {
        NEWSBLUR.log(['Stats', data]);
    }
    
};