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
        var color = feed.favicon_color;
        if (!color) return '';
    
        var r = parseInt(color.substr(0, 2), 16);
        var g = parseInt(color.substr(2, 2), 16);
        var b = parseInt(color.substr(4, 2), 16);
    
        if (type == 'border') {
            return [
                '1px solid rgb(',
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
    },
  
    is_feed_floater_gradient_light: function(feed) {
        if (!feed) return false;
        var color = feed.favicon_color;
        if (!color) return false;
    
        var r = parseInt(color.substr(0, 2), 16) / 255.0;
        var g = parseInt(color.substr(2, 2), 16) / 255.0;
        var b = parseInt(color.substr(4, 2), 16) / 255.0;

        return $.textColor({r: r, g: g, b: b}) != 'white';
    }
  
};