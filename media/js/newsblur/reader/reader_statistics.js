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
                this.make_feed_chooser({skip_starred: true})
            ]),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title' }, 'Statistics &amp; History'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(this.feed) }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }, this.feed.get('feed_title')),
                    $.make('span', { className: 'NB-modal-feed-subscribers ' + (_.isUndefined(this.feed.get('num_subscribers')) && 'NB-hidden') }, Inflector.pluralize(' subscriber', this.feed.get('num_subscribers'), true))
                ])
            ]),
            $.make('div', { className: 'NB-modal-statistics-info' })
        ]);
        
        var $stats = this.make_stats({
            'last_update': '',
            'next_update': '',
            'loading': true
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
        $(".NB-modal-feed-subscribers", this.$modal).removeClass('NB-hidden').text(Inflector.pluralize(' subscriber', data.num_subscribers, true));
        var $expires_label = $(".NB-statistics-push-expires-label", this.$modal);
        var $expires = $(".NB-statistics-push-expires", this.$modal);
        if (data['push_expires']) {
            $expires_label.html("Push expires");
            $expires.html(data['push_expires']);
        } else {
            $expires_label.html("");
            $expires.html("");
        }
        setTimeout(function() {
            self.make_chart_count(data);
            self.make_chart_hours(data);
            self.make_chart_days(data);
        }, this.first_load ? 200 : 50);
        
        setTimeout(function() {
            $.modal.impl.resize(self.$modal);
        }, 100);
    },
    
    make_stats: function(data) {
        var update_interval = NEWSBLUR.utils.calculate_update_interval(data['update_interval_minutes']);
        var premium_update_interval = NEWSBLUR.utils.calculate_update_interval(data['premium_update_interval_minutes']);
        
        var $stats = $.make('div', { className: 'NB-modal-statistics-info' }, [
            (!this.options.social_feed && $.make('div', { className: 'NB-statistics-stat NB-statistics-updates'}, [
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Last Update'),
                $.make('div', { className: 'NB-statistics-count' }, '&nbsp;' + (data['last_update'] && (data['last_update'] + ' ago')))
              ]),
              $.make('div', { className: 'NB-statistics-update'}, [
                (data['push'] && $.make('div', { className: 'NB-statistics-realtime' }, [
                    $.make('div', { className: 'NB-statistics-label' }, [
                        $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + '/img/reader/realtime_spinner.gif', className: 'NB-statisics-realtime-spinner' }),
                        'Real-time'
                    ]),
                    $.make('div', { className: 'NB-statistics-count' }, 'Supplemented by checks every ' + update_interval)
                ])),
                (!data['push'] && $.make('div', [
                    $.make('div', { className: 'NB-statistics-label' }, 'Every'),
                    $.make('div', { className: 'NB-statistics-count' }, update_interval)
                ]))
              ]),
              $.make('div', { className: 'NB-statistics-update'}, [
                $.make('div', { className: 'NB-statistics-label' }, 'Next Update'),
                (data.active && $.make('div', { className: 'NB-statistics-count' }, '&nbsp;' + (data['next_update'] && ('in ' + data['next_update'])))),
                (!data.active && !data.loading && $.make('div', { className: 'NB-statistics-count' }, "Not active"))
              ]),
              ((data.average_stories_per_month == 0 || data.stories_last_month == 0) &&
               data.update_interval_minutes > 60 &&
                  $.make('div', { className: 'NB-statistics-update-explainer' }, [
                    $.make('b', 'Why so infrequently?'),
                    'This site has published zero stories in the past month or has averaged less than a single story a month. As soon as it starts publishing at least once a month, it will automatically fetch more frequently.'
                  ])),
              (data.errors_since_good &&
                  $.make('div', { className: 'NB-statistics-update-explainer' }, [
                    $.make('b', 'Why is the next update not at the normal rate?'),
                    'This site has is throwing exceptions and is not in a healthy state. Look at the bottom of this dialog to see the exact status codes for the feed. The more errors for the feed, the longer time taken between fetches.'
                  ])),
              (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-statistics-premium-stats' }, [
                  $.make('div', { className: 'NB-statistics-update'}, [
                    $.make('div', { className: 'NB-statistics-label' }, [
                        'If you went ',
                        $.make('a', { href: '#', className: 'NB-premium-link NB-splash-link' }, 'premium'),
                        ', ',
                        $.make('br'),
                        'this site would update every'
                    ]),
                    $.make('div', { className: 'NB-statistics-count' }, premium_update_interval),
                    (data['push'] && $.make('div', { className: 'NB-statistics-realtime' }, [
                        $.make('div', { className: 'NB-statistics-label' }, [
                            'but it wouldn\'t matter because',
                            $.make('br'),
                            'this site is already in real-time'
                        ])
                    ]))
                  ])
              ]))
            ])),
            $.make('div', { className: 'NB-statistics-stat NB-statistics-history'}, [
                $.make('div', { className: 'NB-statistics-history-stat' }, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Stories per month')
                ]),
                $.make('canvas', { id: 'NB-statistics-history-count-chart', className: 'NB-statistics-history-count-chart' })
            ]),
            $.make('div', { className: 'NB-statistics-stat NB-statistics-history'}, [
                $.make('div', { className: 'NB-statistics-history-stat' }, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Stories per day')
                ]),
                $.make('canvas', { id: 'NB-statistics-history-days-chart', className: 'NB-statistics-history-days-chart' })
            ]),
            $.make('div', { className: 'NB-statistics-stat NB-statistics-history'}, [
                $.make('div', { className: 'NB-statistics-history-stat' }, [
                    $.make('div', { className: 'NB-statistics-label' }, 'Daily distribution of stories')
                ]),
                $.make('div', { className: 'NB-statistics-history-hours-chart' })
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
                    $.make('div', this.make_history(data, 'feed_push')),
                    $.make('div', { className: 'NB-statistics-label NB-statistics-push-expires-label' }, 'Push Expires'),
                    $.make('div', { className: 'NB-statistics-label NB-statistics-push-expires' })
                ])
            ]))
        ]);
        
        return $stats;
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
            if (facet == 'feed' && self.options.social_feed && counts['feed_id'] != 0) {
                key = [$.make('div', [
                    $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(counts['feed_id']) }),
                    $.make('span', { className: 'NB-modal-feed-title' }, counts['feed_title'])
                ])];                
             } else  if (facet == 'feed') {
                key = [$.make('div', [
                    $.make('img', { className: 'NB-modal-feed-image feed_favicon', src: $.favicon(self.feed) }),
                    $.make('span', { className: 'NB-modal-feed-title' }, self.feed.get('feed_title'))
                ])];
            }
            if (!key || (!pos && !neg)) return;
            var $facet = $.make('div', { className: 'NB-statistics-facet' }, [
                (pos && $.make('div', { className: 'NB-statistics-facet-pos' }, [
                    $.make('div', { className: 'NB-statistics-facet-bar' }).css('width', calculate_width(pos)),
                    $.make('div', { className: 'NB-statistics-facet-count' }, Inflector.pluralize(' like', pos, true)).css('margin-left', calculate_width(pos)+5)
                ])),
                (neg && $.make('div', { className: 'NB-statistics-facet-neg' }, [
                    $.make('div', { className: 'NB-statistics-facet-bar' }).css('width', calculate_width(neg)),
                    $.make('div', { className: 'NB-statistics-facet-count' }, Inflector.pluralize(' dislike', neg, true)).css('margin-right', calculate_width(neg)+5)
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
            $history = $.make('div', { className: 'NB-history-empty' }, "Nothing recorded.");
        } else {
            $history = _.map(fetches, function(fetch) {
                var feed_ok = _.contains([200, 304], fetch.status_code) || !fetch.status_code;
                var status_class = feed_ok ? ' NB-ok ' : ' NB-errorcode ';
                return $.make('div', { className: 'NB-history-fetch' + status_class, title: feed_ok ? '' : fetch.exception }, [
                    $.make('div', { className: 'NB-history-fetch-date' }, fetch.fetch_date || fetch.push_date),
                    $.make('div', { className: 'NB-history-fetch-message' }, [
                        fetch.message,
                        (fetch.status_code && $.make('div', { className: 'NB-history-fetch-code' }, ' ('+fetch.status_code+')'))
                    ])
                ]);
            });
        }

        return $history;
    },
    
    make_chart_count: function(data) {
        var labels = _.map(data['story_count_history'], function(date) {
            var date_matched = date[0].match(/(\d{4})-(\d{1,2})/);
            var date = (new Date(parseInt(date_matched[1], 10), parseInt(date_matched[2],10)-1));
            return NEWSBLUR.utils.shortMonthNames[date.getMonth()] + " " + date.getUTCFullYear();
        });
        if (labels.length > 16) {
            var cut_size = Math.round(labels.length / 16.0);
            labels = _.map(labels, function(label, c) {
                if ((c % cut_size) == 0) return label;
                return "";
            });
        }
        var values = _.map(data['story_count_history'], function(date) {
            return date[1];
        });
        var points = {
            labels: labels,
            datasets: [
                {
                    fillColor : "rgba(151,187,205,0.5)",
                    strokeColor : "rgba(151,187,205,1)",
                    pointColor : "rgba(151,187,205,1)",
                    pointStrokeColor : "#fff",
                    data : values
                }
            ]
        };
        var $plot = $(".NB-statistics-history-count-chart");
        var width = $plot.width();
        var height = $plot.height();
        $plot.attr('width', width);
        $plot.attr('height', height);
        var myLine = new Chart($plot.get(0).getContext("2d")).Line(points, {
            scaleLabel : "<%= Math.round(value) %>",
			showTooltips: false,
			scaleBeginAtZero: true
        });
    },
    
    make_chart_hours: function(data) {
        var max_count = _.max(data.story_hours_history);
        var $chart = $.make('table', [
            $.make('tr', { className: 'NB-statistics-history-chart-hours-row' }, [
                _.map(_.range(24), function(hour) {
                    var count = data.story_hours_history[hour] || 0;
                    var opacity = 1 - (count * 1.0 / max_count);
                    return $.make('td', { style: "background-color: rgba(255, 255, 255, " + opacity + ");" });
                })
            ]),
            $.make('tr', { className: 'NB-statistics-history-chart-hours-text-row' }, [
                _.compact(_.map(_.range(24), function(hour, count) {
                    var am = hour < 12;
                    if (hour == 0) hour = 12;
                    var hour_name = am ? (hour + "am") : ((hour > 12 ? hour - 12 : hour) + "pm");
                    if (hour % 3 == 0) {
                        return $.make('td', { colSpan: 3 }, hour_name);
                    }
                }))
            ])
        ]);
        
        $(".NB-statistics-history-hours-chart", this.$modal).html($chart);
    },
    
    make_chart_days: function(data) {
        var labels = NEWSBLUR.utils.dayNames;
        var values = _.map(_.range(7), function(day) {
            return data['story_days_history'][day] || 0;
        });
        var points = {
            labels: labels,
            datasets: [
                {
                    fillColor : "rgba(151,187,205,0.5)",
                    strokeColor : "rgba(151,187,205,1)",
                    pointColor : "rgba(151,187,205,1)",
                    pointStrokeColor : "#fff",
                    data : values
                }
            ]
        };
        var $plot = $(".NB-statistics-history-days-chart");
        var width = $plot.width();
        var height = $plot.height();
        $plot.attr('width', width);
        $plot.attr('height', height);

        var myLine = new Chart($plot.get(0).getContext("2d")).Radar(points, {
            scaleShowLabelBackdrop: false,
			showTooltips: false,
			scaleFontSize: 16
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