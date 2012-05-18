NEWSBLUR.ReaderStatistics = function(feed_id, options) {
    var defaults = {};
    
    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.feed_id = feed_id;
    this.feed = this.model.get_feed(feed_id);
    this.feeds = this.model.get_feeds();
    this.first_load = true;
    this.runner();
};

NEWSBLUR.ReaderStatistics.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderStatistics.prototype.constructor = NEWSBLUR.ReaderStatistics;

_.extend(NEWSBLUR.ReaderStatistics.prototype, {
    
    runner: function() {
        var self = this;
        
        this.initialize_feed(this.feed_id);
        this.make_modal();
        this.open_modal();
        setTimeout(function() {
            self.get_stats();
        }, 50);
        
        this.$modal.bind('click', $.rescope(this.handle_click, this));
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
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.feed_title),
                    $.make('span', { className: 'NB-modal-feed-subscribers' }, Inflector.commas(this.feed.num_subscribers) + Inflector.pluralize(' subscriber', this.feed.num_subscribers))
                ])
            ]),
            $.make('div', { className: 'NB-modal-statistics-info' })
        ]);
        
        var $stats = this.make_stats({
            'last_update': '',
            'next_update': ''
        });
        $('.NB-modal-statistics-info', this.$modal).replaceWith($stats);
    },
    
    get_stats: function() {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        
        var statistics_fn = this.options.social_feed ? this.model.get_social_statistics : this.model.get_feed_statistics;
        statistics_fn.call(this.model, this.feed_id, $.rescope(this.populate_stats, this));
    },
    
    populate_stats: function(s, data) {
        var self = this;
        
        NEWSBLUR.log(['Stats', data]);
        
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.removeClass('NB-active');
        
        var $stats = this.make_stats(data);
        $('.NB-modal-statistics-info', this.$modal).replaceWith($stats);
        
        setTimeout(function() {
            self.make_charts(data);  
        }, this.first_load ? 500 : 50);
        
        setTimeout(function() {
            $.modal.impl.resize(self.$modal);
        }, 100);
    },
    
    make_stats: function(data) {
        var update_interval = this.calculate_update_interval(data['update_interval_minutes']);
        var premium_update_interval = this.calculate_update_interval(data['premium_update_interval_minutes']);
        
        var $stats = $.make('div', { className: 'NB-modal-statistics-info' }, [
            (!this.options.social_feed && $.make('div', { className: 'NB-statistics-stat NB-statistics-updates'}, [
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Last Update'),
                $.make('div', { className: 'NB-statistics-count' }, '&nbsp;' + (data['last_update'] && (data['last_update'] + ' ago')))
              ]),
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Every'),
                $.make('div', { className: 'NB-statistics-count' }, update_interval)
              ]),
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Next Update'),
                (data.active && $.make('div', { className: 'NB-statistics-count' }, '&nbsp;' + (data['next_update'] && ('in ' + data['next_update'])))),
                (!data.active && $.make('div', { className: 'NB-statistics-count' }, "Not active"))
              ]),
              (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-statistics-premium-stats' }, [
                  $.make('div', { className: 'NB-statistics-update'}, [
                    $.make('div', { className: 'NB-statistics-label' }, [
                        'If you went ',
                        $.make('a', { href: '#', className: 'NB-premium-link NB-splash-link' }, 'premium'),
                        ', ',
                        $.make('br'),
                        'this site would update every'
                    ]),
                    $.make('div', { className: 'NB-statistics-count' }, premium_update_interval)
                  ])
              ]))
            ])),
            $.make('div', { className: 'NB-statistics-stat NB-statistics-history'}, [
                $.make('div', { className: 'NB-statistics-history-stat' }, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Stories per month')
                ]),
                $.make('div', { id: 'NB-statistics-history-chart', className: 'NB-statistics-history-chart' })
            ]),
            (data.classifier_counts && $.make('div', { className: 'NB-statistics-state NB-statistics-classifiers' }, [
                this.make_classifier_count('tag', data.classifier_counts['tag']),
                this.make_classifier_count('author', data.classifier_counts['author']),
                this.make_classifier_count('title', data.classifier_counts['title']),
                this.make_classifier_count('feed', data.classifier_counts['feed'])
            ])),
            (!this.options.social_feed && $.make('div', { className: 'NB-statistics-stat NB-statistics-fetches'}, [
                $.make('div', { className: 'NB-statistics-fetches-half'}, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Feed Fetch'),
                    $.make('div', this.make_history(data, 'feed_fetch'))
                ]),
                $.make('div', { className: 'NB-statistics-fetches-half'}, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Page Fetch'),
                    $.make('div', this.make_history(data, 'page_fetch'))
                ]),
                $.make('div', { className: 'NB-statistics-fetches-half'}, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Feed Push'),
                    $.make('div', this.make_history(data, 'feed_push'))
                ])
            ]))
        ]);
        
        return $stats;
    },
    
    calculate_update_interval: function(update_interval_minutes) {
        if (!update_interval_minutes) return '&nbsp;';
        
        var interval_start = update_interval_minutes;
        var interval_end = update_interval_minutes * 1.25;
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
        
        return interval;
    },
    
    make_classifier_count: function(facet, data) {
        var self = this;
        if (!data) return;
        
        var $facets = $.make('div', { className: 'NB-statistics-facets' }, [
            $.make('div', { className: 'NB-statistics-facet-title' }, Inflector.pluralize(facet, data.length))
        ]);
        
        var max = 10;
        _.each(data, function(v) {
            if (v.pos > max || v.neg > max) {
                max = Math.max(v.pos, v.neg);
            }
        });
        
        var max_width = 100;
        var multiplier = max_width / parseFloat(max, 10);
        var calculate_width = function(count) {
            return Math.max(1, multiplier * count);
        };
        
        _.each(data, function(counts) {
            var pos = counts.pos || 0;
            var neg = counts.neg || 0;
            var key = counts[facet];
            if (facet == 'feed') {
                key = [$.make('div', [
                    $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(self.feed) }),
                    $.make('span', { className: 'NB-modal-feed-title' }, self.feed.feed_title)
                ])];
            }
            if (!key || (!pos && !neg)) return;
            var $facet = $.make('div', { className: 'NB-statistics-facet' }, [
                (pos && $.make('div', { className: 'NB-statistics-facet-pos' }, [
                    $.make('div', { className: 'NB-statistics-facet-bar' }).css('width', calculate_width(pos)),
                    $.make('div', { className: 'NB-statistics-facet-count' }, pos + Inflector.pluralize(' like', pos)).css('margin-left', calculate_width(pos)+5)
                ])),
                (neg && $.make('div', { className: 'NB-statistics-facet-neg' }, [
                    $.make('div', { className: 'NB-statistics-facet-bar' }).css('width', calculate_width(neg)),
                    $.make('div', { className: 'NB-statistics-facet-count' }, neg + Inflector.pluralize(' dislike', neg)).css('margin-right', calculate_width(neg)+5)
                ])),
                $.make('div', { className: 'NB-statistics-facet-separator' }),
                $.make('div', { className: 'NB-statistics-facet-name' }, key)
            ]);
            $facets.append($facet);
        });
        
        return $facets;
    },
    
    make_history: function(data, fetch_type) {
        var fetches = data[fetch_type+'_history'];
        var $history;
        
        if (!fetches || !fetches.length) {
            $history = $.make('div', { className: 'NB-statistics-history-empty' }, "Nothing recorded.");
        } else {
            $history = _.map(fetches, function(fetch) {
                var feed_ok = _.contains([200, 304], fetch.status_code) || !fetch.status_code;
                var status_class = feed_ok ? ' NB-ok ' : ' NB-errorcode ';
                return $.make('div', { className: 'NB-statistics-history-fetch' + status_class, title: feed_ok ? '' : fetch.exception }, [
                    $.make('div', { className: 'NB-statistics-history-fetch-date' }, fetch.fetch_date || fetch.push_date),
                    $.make('div', { className: 'NB-statistics-history-fetch-message' }, [
                        fetch.message,
                        (fetch.status_code && $.make('div', { className: 'NB-statistics-history-fetch-code' }, ' ('+fetch.status_code+')'))
                    ])
                ]);
            });
        }

        return $history;
    },
    
    make_charts: function(data) {
        data['story_count_history'] = _.map(data['story_count_history'], function(date) {
            var date_matched = date[0].match(/(\d{4})-(\d{1,2})/);
            return [(new Date(parseInt(date_matched[1], 10), parseInt(date_matched[2],10)-1)).getTime(),
                    date[1]];
        });
        var $plot = $(".NB-statistics-history-chart");
        var plot = $.plot($plot,
            [ { data: data['story_count_history'], label: "Stories"} ], {
                series: {
                    lines: { show: true },
                    points: { show: true }
                },
                average: data['average_stories_per_month'],
                legend: { show: false },
                grid: { hoverable: true, clickable: true },
                yaxis: { tickDecimals: 0, min: 0 },
                xaxis: { mode: 'time', minTickSize: [1, 'month'], timeformat: '%b %y' }
            });
    },
    
    close_and_load_premium: function() {
      this.close(function() {
          NEWSBLUR.reader.open_feedchooser_modal();
      });
    },
    
    // ===========
    // = Actions =
    // ===========
    
    handle_change: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function($t, $p){
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_stats();
        });
    },
    
    handle_click: function(elem, e) {
        var self = this;
        
        $.targetIs(e, { tagSelector: '.NB-premium-link' }, function($t, $p) {
            e.preventDefault();
            self.close_and_load_premium();
        });
    }
    
});