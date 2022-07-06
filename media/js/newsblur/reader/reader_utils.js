NEWSBLUR.utils = {
    
    service_name: function(service) {
        switch (service) {
            case 'twitter':
            return 'Twitter';
            case 'facebook':
            return 'Facebook';
        }
    },
    
    compute_story_score: function(story) {
      var score = 0;
      var intelligence = story.get('intelligence');
      if (!intelligence) return score;
      var score_max = Math.max(intelligence['title'],
                               intelligence['author'],
                               intelligence['tags']);
      var score_min = Math.min(intelligence['title'],
                               intelligence['author'],
                               intelligence['tags']);
      if (score_max > 0) score = score_max;
      else if (score_min < 0) score = score_min;
    
      if (score == 0) score = intelligence['feed'];
    
      return score;
    },
    
    generate_shadow: _.memoize(function(feed) {
        if (!feed) return '';
        var color = feed.get('favicon_color');
        
        if (!color) {
            return '0 1px 0 #222';
        }
        
        var r, g, b;
        if (feed.is_light()) {
            color = feed.get('favicon_fade');
        } else {
            color = feed.get('favicon_border');
        }
        r = parseInt(color.substr(0, 2), 16);
        g = parseInt(color.substr(2, 2), 16);
        b = parseInt(color.substr(4, 2), 16);
        return [
            '0 1px 0 ',
            'rgb(',
            [r, g, b].join(','),
            ')'
        ].join('');
    }, function(feed) {
        return "" + feed.id;
    }),
    
    generate_gradient: _.memoize(function(feed, type) {
        if (!feed) return '';
        var color = feed.get('favicon_color');
        var colorFade = feed.get('favicon_fade');
        var colorBorder = feed.get('favicon_border');
        if (!color) return '';
    
        var r = parseInt(color.substr(0, 2), 16);
        var g = parseInt(color.substr(2, 2), 16);
        var b = parseInt(color.substr(4, 2), 16);
        var rF = parseInt(colorFade.substr(0, 2), 16);
        var gF = parseInt(colorFade.substr(2, 2), 16);
        var bF = parseInt(colorFade.substr(4, 2), 16);
        
        if (type == 'border') {
            r = parseInt(colorBorder.substr(0, 2), 16);
            g = parseInt(colorBorder.substr(2, 2), 16);
            b = parseInt(colorBorder.substr(4, 2), 16);
            return [
                (type == 'border' ? '1px solid ' : '') + 'rgb(',
                [
                    r,
                    g,
                    b
                ].join(','),
                ')'
            ].join('');
        } else if (type == 'webkit') {
            return [
                '-webkit-gradient(',
                'linear,',
                'left bottom,',
                'left top,',
                'color-stop(0, rgba(',
                [
                    r,
                    g,
                    b,
                    255
                ].join(','),
                ')),',
                'color-stop(1, rgba(',
                [
                    rF,
                    gF,
                    bF,
                    255
                ].join(','),
                ')))'
            ].join('');
        } else if (type == 'moz') {
            return [
                '-moz-linear-gradient(',
                'center bottom,',
                'rgb(',
                [
                    r,
                    g,
                    b
                ].join(','),
                ') 0%,',
                'rgb(',
                [
                    rF,
                    gF,
                    bF
                ].join(','),
                ') 100%)'
            ].join('');
        }
    }, function(feed, type) {
        return "" + feed.id + '-' + type;
    }),
    
    attach_loading_gradient: function($elem, percentage) {
        $elem.css('background', '-moz-linear-gradient(left,  #b1d2f9 0%, #b1d2f9 '+percentage+'%, #fcfcfc '+percentage+'%, #fcfcfc 100%)'); // FF3.6+
        $elem.css('background', '-webkit-gradient(linear, left top, right top, color-stop(0%,#b1d2f9), color-stop('+percentage+'%,#b1d2f9), color-stop('+percentage+'%,#fcfcfc), color-stop(100%,#fcfcfc))'); // Chrome,Safari4+
        $elem.css('background', '-webkit-linear-gradient(left,  #b1d2f9 0%,#b1d2f9 '+percentage+'%,#fcfcfc '+percentage+'%,#fcfcfc 100%)'); // Chrome10+,Safari5.1+
        $elem.css('background', 'linear-gradient(to right,  #b1d2f9 0%,#b1d2f9 '+percentage+'%,#fcfcfc '+percentage+'%,#fcfcfc 100%)');
        $elem.css("filter", "progid:DXImageTransform.Microsoft.gradient( startColorstr='#b1d2f9', endColorstr='#fcfcfc',GradientType=1 )");
    },
    
    is_feed_social: function(feed_id) {
        return _.string.include(feed_id, 'social:');
    },
    
    monthNames: ['January','February','March','April','May','June','July','August','September','October','November','December'],
    shortMonthNames: ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
    dayNames: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
    
    format_date: function(date) {
        var dayOfWeek = date.getDay();
        var month = date.getMonth();
        var year = date.getUTCFullYear();
        var day = date.getDate();

        return this.dayNames[dayOfWeek] + ", " + this.monthNames[month] + " " + day + ", " + year;
    },

    make_feed_chooser: function (options) {
        options = options || {};
        var $chooser = $.make('select', { name: 'feed', className: 'NB-modal-feed-chooser' });
        var $folders_optgroup = $.make('optgroup', { label: "Folders" });
        var $feeds_optgroup = $.make('optgroup', { label: "Sites" });
        var $social_feeds_optgroup = $.make('optgroup', { label: "Blurblogs" });
        var $saved_searches_optgroup = $.make('optgroup', { label: "Saved Searches" });
        var $starred_feeds_optgroup = $.make('optgroup', { label: "Saved Tags" });
        var current_feed_id = options.feed_id;
        var selected_feed_prefix = '';

        var make_feed_option = function(feed) {
            if (!feed.get('feed_title')) return;
            if (!feed.get('active')) return;
            var prefix = 'feed:';
            if (feed.is_starred()) prefix = '';
            else if (feed.is_social()) prefix = '';
            else if (feed.is_search()) prefix = '';

            var $option = $.make('option', { value: prefix + feed.id }, feed.get('feed_title'));
            $option.appendTo(feed.is_starred() ? $starred_feeds_optgroup : 
                             feed.is_social() ? $social_feeds_optgroup : 
                             feed.is_search() ? $saved_searches_optgroup : 
                             $feeds_optgroup);
            
            if (feed.id == current_feed_id) {
                // console.log('Selecting feed id in feed chooser', feed, current_feed_id);
                $option.attr('selected', true);
                $chooser.val(prefix + feed.id);
                selected_feed_prefix = prefix;
            }
        };
        
        this.feeds = NEWSBLUR.assets.get_feeds();
        this.feeds.each(make_feed_option);
        
        if (!options.skip_social) {
            this.social_feeds = NEWSBLUR.assets.get_social_feeds();
            this.social_feeds.each(make_feed_option);
        }

        if (!options.skip_searches) {
            this.search_feeds = NEWSBLUR.assets.get_search_feeds();
            this.search_feeds.each(make_feed_option);
        }
        
        if (!options.skip_starred) {
            this.starred_feeds = NEWSBLUR.assets.get_starred_feeds();
            this.starred_feeds.each(make_feed_option);
        }
        
        if (options.include_folders) {
            var $folders = NEWSBLUR.utils.make_folders(options.feed_id, options.toplevel, options.name, options.include_special_folders);
            $('option', $folders).each(function () {
                $(this).appendTo($folders_optgroup);
            });
        }

        $('option', $feeds_optgroup).tsort();
        $('option', $social_feeds_optgroup).tsort();
        $('option', $starred_feeds_optgroup).tsort();
        $('option', $saved_searches_optgroup).tsort();
        // $('option[value^=river]', $folders_optgroup).tsort();
        
        if (options.include_folders) {
            $chooser.append($folders_optgroup);
        }
        $chooser.append($feeds_optgroup);
        if (!options.skip_social) {
            $chooser.append($social_feeds_optgroup);
        }
        if (!options.skip_searches) {
            $chooser.append($saved_searches_optgroup);
        }
        if (!options.skip_starred) {
            $chooser.append($starred_feeds_optgroup);
        }

        if (options.feed_id) {
            $chooser.val(selected_feed_prefix + options.feed_id);
        }

        return $chooser;
    },
    
    make_folders: function (selected_folder_title, toplevel, select_name, include_special_folders) {
        // console.log('make_folders', selected_folder_title);
        var folders = NEWSBLUR.assets.get_folders();
        var $options = $.make('select', { className: 'NB-folders', name: select_name });
        
        if (include_special_folders) {
            var $option = $.make('option', { value: 'river:global' }, "Global Shared Stories");
            $options.append($option);
            if (selected_folder_title == "river:global") {
                $option.attr('selected', true);
            }
            
            var $option = $.make('option', { value: 'river:blurblogs' }, "All Shared Stories");
            $options.append($option);    
            if (selected_folder_title == "river:blurblogs") {
                $option.attr('selected', true);
            }

            var $option = $.make('option', { value: 'river:infrequent' }, "Infrequent Site Stories");
            $options.append($option);    
            if (selected_folder_title == "river:infrequent") {
                $option.attr('selected', true);
            }
        }

        var $option = $.make('option', { value: 'river:' }, toplevel || "Top Level");
        $options.append($option);
        if (selected_folder_title == "river:") {
            $option.attr('selected', true);
        }

        $options = this.make_folder_options($options, folders, '&nbsp;&nbsp;&nbsp;', selected_folder_title);
        
        return $options;
    },

    make_folder_options: function($options, items, depth, selected_folder_title) {
        var self = this;
        items.each(function(item) {
            if (item.is_folder()) {
                var $option = $.make('option', { 
                    value: 'river:'+item.get('folder_title')
                }, depth + ' ' + item.get('folder_title'));
                $options.append($option);
                if (item.get('folder_title') == selected_folder_title) {
                    $option.attr('selected', true);
                }
                $options = self.make_folder_options($options, item.folders, depth+'&nbsp;&nbsp;&nbsp;', selected_folder_title);
            }
        });
    
        return $options;
    },
    
    is_url_iframe_buster: function(url) {
        // Also change in utils/page_importer.py.
        var BROKEN_URLS = [
            'nytimes.com',
            'github.com',
            'medium.com',
            'washingtonpost.com',
            'stackoverflow.com',
            'stackexchange.com',
            'twitter.com',
            'rankexploits',
            'gamespot.com',
            'royalroad.com'
        ];
        return _.any(BROKEN_URLS, function(broken_url) {
            return _.string.contains(url, broken_url);
        });
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
    
    days_back_to_timestamp: function(days_back) {
        if (days_back > 365) {
            // It's a timestamp, not the number of days back
            return days_back;
        }
        
        days_back = days_back || 0;
        var now = Math.round((new Date()).getTime() / 1000);

        return now - (days_back * 60*60*24);
    }
    

  
};
