NEWSBLUR.utils = {

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
    
    make_folders: function(model, selected_folder_title) {
        var folders = model.get_folders();
        var $options = $.make('select', { className: 'NB-folders'});
        
        var $option = $.make('option', { value: '' }, "Top Level");
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
            'washingtonpost.com',
            'stackoverflow.com',
            'stackexchange.com',
            'twitter.com',
            'rankexploits'
        ];
        return _.any(BROKEN_URLS, function(broken_url) {
            return _.string.contains(url, broken_url);
        });
    }
  
};