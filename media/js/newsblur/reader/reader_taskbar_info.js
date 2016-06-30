NEWSBLUR.Views.ReaderTaskbarInfo = Backbone.View.extend({
    
    className: 'NB-taskbar-info',
    
    initialize: function() {
        _.bindAll(this, 'show_stories_error');
    },
    
    render: function() {
        NEWSBLUR.reader.$s.$story_taskbar.append(this.$el);
        return this;
    },
    
    center: function(force) {
        var count_width = this.$el.width();
        var left_buttons_offset = $('.NB-taskbar-view').outerWidth(true);
        var right_buttons_offset = $(".NB-taskbar-options-container").position().left;
        var usable_space = right_buttons_offset - left_buttons_offset;
        var left = (usable_space / 2) - (count_width / 2) + left_buttons_offset;
        // console.log(["Taskbar info center", count_width, left, left_buttons_offset, right_buttons_offset, usable_space]);
        
        if (!force && count_width + 12 > usable_space) {
            this.$el.hide();
        } else {
            this.$el.show();
        }
        
        this.$el.css({'left': left});
    },
    
    // =================
    // = Story loading =
    // =================
    
    show_stories_progress_bar: function(feeds_loading, message) {
        message = message || "Fetching stories";
        if (NEWSBLUR.app.story_unread_counter) {
            NEWSBLUR.app.story_unread_counter.remove();
        }
        
        var $progress = $.make('div', { className: 'NB-river-progress' }, [
            $.make('div', { className: 'NB-river-progress-text' }),
            $.make('div', { className: 'NB-river-progress-bar' })
        ]).css({'opacity': 0});
        
        this.$el.html($progress);
        this.center();
        
        $progress.animate({'opacity': 1}, {'duration': 500, 'queue': false});
        
        var $bar = $('.NB-river-progress-bar', $progress);
        var unreads;
        if (feeds_loading) unreads = feeds_loading;
        else unreads = NEWSBLUR.reader.get_total_unread_count(false) / 10;
        NEWSBLUR.reader.animate_progress_bar($bar, unreads / 10);
        
        $('.NB-river-progress-text', $progress).text(message);
    },
    
    hide_stories_progress_bar: function(callback) {
        var $progress = this.$('.NB-river-progress');
        $progress.stop().animate({'opacity': 0}, {
          'duration': 250, 
          'queue': false, 
          'complete': function() {
            $progress.remove();
            if (callback) callback();
          }
        });
    },
    
    show_stories_error: function(data, message) {
        NEWSBLUR.log(["show_stories_error", data]);
        this.hide_stories_progress_bar();
        
        NEWSBLUR.app.original_tab_view.iframe_not_busting();
        
        if (!message || message == 'error') {
            message = "Oh no! <br> There was an error!";
        }
        
        if (data && data.status) {
            if (data.status == 502) {
                message = "NewsBlur is down right now. <br> Try again soon.";
            } else if (data.status == 503) {
                message = "NewsBlur is in maintenance mode. <br> Try again soon.";
                this.show_maintenance_page();
            } else if (data.status == 429) {
                message = "You're being rate limited.<br> Try again soon, but not too soon.";
            }
            NEWSBLUR.assets.flags['no_more_stories'] = true;
            NEWSBLUR.app.story_titles.end_loading();
            NEWSBLUR.app.story_list.end_loading();
        }

        var type = data.proxied_https ? 'proxy' : 'feed';
        var $error = $.make('div', { className: 'NB-feed-error NB-feed-error-type-'+type }, [
            $.make('div', { className: 'NB-feed-error-icon' }),
            $.make('div', { className: 'NB-feed-error-text' }, message)
        ]).css({'opacity': 0});
        
        this.$el.html($error);
        this.center(true);
        
        if (NEWSBLUR.app.story_unread_counter) {
            NEWSBLUR.app.story_unread_counter.remove();
        }
        
        $error.animate({'opacity': 1}, {'duration': 500, 'queue': false});
    },
    
    hide_stories_error: function() {
        var $error = this.$('.NB-feed-error');
        $error.animate({'opacity': 0}, {
          'duration': 250, 
          'queue': false, 
          'complete': function() {
            $error.remove();
          }
        });
    },
    
    show_maintenance_page: function() {
        NEWSBLUR.reader.switch_taskbar_view('page', {skip_save_type: 'maintenance'});
    }
    
});