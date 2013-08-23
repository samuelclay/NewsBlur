NEWSBLUR.utils = {
    
    service_name: function(service) {
        switch (service) {
            case 'twitter':
            return 'Twitter';
            case 'facebook':
            return 'Facebook';
            case 'appdotnet':
            return 'App.net';
        }
    },
    
    compute_story_score: function(story) {
      var score = 0;
      var intelligence = story.get('intelligence');
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
        
        var r = parseInt(color.substr(0, 2), 16);
        var g = parseInt(color.substr(2, 2), 16);
        var b = parseInt(color.substr(4, 2), 16);
        
        if (feed.is_light()) {
            return [
                '0 1px 0 ',
                'rgb(',
                [r+35, g+35, b+35].join(','),
                ')'
            ].join('');
        } else {
            return [
                '0 1px 0 ',
                'rgb(',
                [
                    parseInt(r*(6/8), 10),
                    parseInt(g*(6/8), 10),
                    parseInt(b*(6/8), 10)
                ].join(','),
                ')'
            ].join('');
        }
    }, function(feed) {
        return "" + feed.id;
    }),
    
    generate_gradient: _.memoize(function(feed, type) {
        if (!feed) return '';
        var color = feed.get('favicon_color');
        if (!color) return '';
    
        var r = parseInt(color.substr(0, 2), 16);
        var g = parseInt(color.substr(2, 2), 16);
        var b = parseInt(color.substr(4, 2), 16);
        
        if (type == 'border') {
            return [
                (type == 'border' ? '1px solid ' : '') + 'rgb(',
                [
                    parseInt(r*(6/8), 10),
                    parseInt(g*(6/8), 10),
                    parseInt(b*(6/8), 10)
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
                    r+35,
                    g+35,
                    b+35,
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
                    r+35,
                    g+35,
                    b+35
                ].join(','),
                ') 100%)'
            ].join('');
        }
    }, function(feed, type) {
        return "" + feed.id + '-' + type;
    }),
  
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
    
    make_folders: function(selected_folder_title, options) {
        options = options || {};
        var folders = NEWSBLUR.assets.get_folders();
        var $options = $.make('select', { className: 'NB-folders', name: options.name });
        
        var $option = $.make('option', { value: '' }, options.toplevel || "Top Level");
        $options.append($option);

        $options = this.make_folder_options($options, folders, '&nbsp;&nbsp;&nbsp;', selected_folder_title);
        
        return $options;
    },

    make_folder_options: function($options, items, depth, selected_folder_title) {
        var self = this;
        items.each(function(item) {
            if (item.is_folder()) {
                var $option = $.make('option', { 
                    value: item.get('folder_title')
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
            'washingtonpost.com',
            'stackoverflow.com',
            'stackexchange.com',
            'twitter.com',
            'rankexploits'
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
    }
    

  
};