NEWSBLUR.ReaderStatistics = function(feed_id, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.AssetModel.reader();
    this.google_favicon_url = 'http://www.google.com/s2/favicons?domain_url=';
    this.feed_id = feed_id;
    this.feed = this.model.get_feed(feed_id);
    this.feeds = this.model.get_feeds();
    this.first_load = true;
    this.runner();
};

NEWSBLUR.ReaderStatistics.prototype = {
    
    runner: function() {
        var self = this;
        
        this.make_modal();
        this.open_modal();
        setTimeout(function() {
            self.get_stats();
        }, 50);
        
        this.$modal.bind('change', $.rescope(this.handle_change, this));
    },
    
    make_modal: function() {
        var self = this;
        
        this.$modal = $.make('div', { className: 'NB-modal-statistics NB-modal' }, [
            $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                this.make_feed_chooser()
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, 'Statistics &amp; History'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: this.google_favicon_url + this.feed.feed_link }),
                $.make('span', { className: 'NB-modal-feed-title' }, this.feed.feed_title)
            ]),
            $.make('div', { className: 'NB-modal-statistics-info' })
        ]);
    },
        
    initialize_feed: function(feed_id) {
        this.feed_id = feed_id;
        this.feed = this.model.get_feed(feed_id);
        
        $('.NB-modal-subtitle .NB-modal-feed-image', this.$modal).attr('src', this.google_favicon_url + this.feed['feed_link']);
        $('.NB-modal-subtitle .NB-modal-feed-title', this.$modal).html(this.feed['feed_title']);
    },
    
    open_modal: function() {
        var self = this;

        this.$modal.modal({
            'minWidth': 600,
            'minHeight': 425,
            'overlayClose': true,
            'autoResize': true,
            'onOpen': function (dialog) {
                dialog.overlay.fadeIn(200, function () {
                    dialog.container.fadeIn(200);
                    dialog.data.fadeIn(200);
                });
            },
            'onShow': function(dialog) {
                $('#simplemodal-container').corner('6px');
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
    
    make_feed_chooser: function() {
        var $chooser = $.make('select', { name: 'feed', className: 'NB-modal-feed-chooser' });
        
        for (var f in this.feeds) {
            var feed = this.feeds[f];
            var $option = $.make('option', { value: feed.id }, feed.feed_title);
            $option.appendTo($chooser);
            
            if (feed.id == this.feed_id) {
                $option.attr('selected', true);
            }
        }
        
        $('option', $chooser).tsort();
        return $chooser;
    },
    
    get_stats: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        this.model.get_feed_statistics(this.feed_id, $.rescope(this.populate_stats, this));
    },
    
    populate_stats: function(s, data) {
        var self = this;
        
        NEWSBLUR.log(['Stats', data]);
        
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.removeClass('NB-active');
        
        var interval_start = data['update_interval_minutes'];
        var interval_end = data['update_interval_minutes'] * 1.25;
        var interval = '';
        if (interval_start < 60) {
            interval = interval_start + ' to ' + interval_end + ' minutes';
        } else {
            var interval_start_hours = parseInt(interval_start / 60, 10);
            var interval_end_hours = parseInt(interval_end / 60, 10);
            var dec_start = interval_start % 60;
            var dec_end = interval_end % 60;
            interval = interval_start_hours + (dec_start >= 30 ? '.5' : '') + ' to ' + interval_end_hours + (dec_end >= 30 || interval_start_hours == interval_end_hours ? '.5' : '') + ' hours';
        }
        
        var $stats = this.make_stats(data, interval);
        $('.NB-modal-statistics-info', this.$modal).replaceWith($stats);
        
        setTimeout(function() {
            self.make_charts(data);  
        }, this.first_load ? 500 : 50);
        
        setTimeout(function() {
            $.modal.impl.resize(self.$modal);
        }, 50);
    },
    
    make_stats: function(data, interval) {
        var $stats = $.make('div', { className: 'NB-modal-statistics-info' }, [
            $.make('div', { className: 'NB-statistics-stat NB-statistics-updates'}, [
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Last Update'),
                $.make('div', { className: 'NB-statistics-count' }, data['last_update'] + ' ago')
              ]),
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Every'),
                $.make('div', { className: 'NB-statistics-count' }, interval)
              ]),
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Next Update'),
                $.make('div', { className: 'NB-statistics-count' }, 'in ' + data['next_update'])
              ])
            ]),
            $.make('div', { className: 'NB-statistics-stat NB-statistics-history'}, [
                $.make('div', { className: 'NB-statistics-history-stat' }, [
                    $.make('div', { className: 'NB-statistics-count' }, ''+data['subscriber_count']),
                    $.make('div', { className: 'NB-statistics-label' }, 'subscribers'),
                    $.make('div', { className: 'NB-statistics-count' }, ''+data['average_stories_per_month']),
                    $.make('div', { className: 'NB-statistics-label' }, ' stories per month')
                ]),
                $.make('div', { id: 'NB-statistics-history-chart', className: 'NB-statistics-history-chart' })
            ])
        ]);
        
        return $stats;
    },
    
    make_charts: function(data) {
        var r = Raphael("NB-statistics-history-chart", 325, 170);
        var lines = r.g.linechart(20, 20, 290, 200, 
                                  [[0, 2, 4, 6, 8, 10, 12],
                                   [0, 2, 4, 6, 8, 10, 12]], 
                                  [[12, 12, 23, 15, 17, 27, 22], 
                                   [10, 20, 30, 25, 15, 28, 2]], {
            nostroke: false, 
            axis: false, 
            symbol: "o", 
            smooth: true
        }).hoverColumn(function () {
            this.tags = r.set();
            for (var i = 0, ii = this.y.length; i < ii; i++) {
                this.tags.push(r.g.tag(this.x, this.y[i], this.values[i], 160, 10).insertBefore(this).attr([{fill: "#fff"}, {fill: this.symbols[i].attr("fill")}]));
            }
        }, function () {
            this.tags && this.tags.remove();
        });
        lines.symbols.attr({r: 3});
        // lines.lines[0].animate({"stroke-width": 6}, 1000);
        // lines.symbols[0].attr({stroke: "#fff"});
        // lines.symbols[0][1].animate({fill: "#f00"}, 1000);
    },
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function($t, $p){
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_stats();
        });
    }
    
};