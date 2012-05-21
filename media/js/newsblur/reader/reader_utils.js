NEWSBLUR.utils = {

    compute_story_score: function(story) {
      var score = 0;
      var score_max = Math.max(story.intelligence['title'],
                               story.intelligence['author'],
                               story.intelligence['tags']);
      var score_min = Math.min(story.intelligence['title'],
                               story.intelligence['author'],
                               story.intelligence['tags']);
      if (score_max > 0) score = score_max;
      else if (score_min < 0) score = score_min;
    
      if (score == 0) score = story.intelligence['feed'];
    
      return score;
    },
  
    generate_gradient: function(feed, type) {
        if (!feed) return '';
        var color = feed.get('favicon_color');
        if (!color) return '';
    
        var r = parseInt(color.substr(0, 2), 16);
        var g = parseInt(color.substr(2, 2), 16);
        var b = parseInt(color.substr(4, 2), 16);
        
        if (type == 'border' || (type == 'shadow' && !this.is_feed_floater_gradient_light(feed))) {
            return [
                (type == 'border' ? '1px solid ' : '') + 'rgb(',
                [
                    parseInt(r*(6/8), 10),
                    parseInt(g*(6/8), 10),
                    parseInt(b*(6/8), 10)
                ].join(','),
                ')'
            ].join('');
        } else if (type == 'shadow') {
            return [
                'rgb(',
                [r+35, g+35, b+35].join(','),
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
    },
  
    is_feed_floater_gradient_light: function(feed) {
        if (!feed) return false;
        var is_light = feed.get('is_light');
        console.log(["is_feed_floater_gradient_light", is_light]);
        if (!_.isUndefined(is_light)) {
            return is_light;
        }
        var color = feed.get('favicon_color');
        if (!color) return false;
    
        var r = parseInt(color.substr(0, 2), 16) / 255.0;
        var g = parseInt(color.substr(2, 2), 16) / 255.0;
        var b = parseInt(color.substr(4, 2), 16) / 255.0;

        is_light = $.textColor({r: r, g: g, b: b}) != 'white';
        feed.set('is_light', is_light, {silent: true});
        
        return is_light;
    },
    
    is_feed_social: function(feed_id) {
        return _.string.include(feed_id, 'social:');
    },
    
    make_folders: function(model) {
        var folders = model.get_folders();
        var $options = $.make('select', { className: 'NB-folders'});
        
        var $option = $.make('option', { value: '' }, "Top Level");
        $options.append($option);

        $options = this.make_folder_options($options, folders, '&nbsp;&nbsp;&nbsp;');
        
        return $options;
    },

    make_folder_options: function($options, items, depth) {
        for (var i in items) {
            var item = items[i];
            if (typeof item == "object") {
                for (var o in item) {
                    var folder = item[o];
                    var $option = $.make('option', { value: o }, depth + ' ' + o);
                    $options.append($option);
                    $options = this.make_folder_options($options, folder, depth+'&nbsp;&nbsp;&nbsp;');
                }
            }
        }
    
        return $options;
    },
    
    is_url_iframe_buster: function(url) {
        // Also change in rss_feeds/models.py.
        var BROKEN_URLS = [
            'nytimes.com',
            'stackoverflow.com',
            'stackexchange.com',
            'twitter.com'
        ];
        return _.any(BROKEN_URLS, function(broken_url) {
            return _.string.contains(url, broken_url);
        });
    }
  
};