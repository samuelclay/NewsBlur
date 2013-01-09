NEWSBLUR.Views.FolderCount = Backbone.View.extend({
    
    className: 'feed_counts_floater',
    
    initialize: function() {
        _.bindAll(this, 'render');
        if (!this.options.stale) {
            this.collection.bind('change:counts', this.render);
        }
    },

    // ==========
    // = Render =
    // ==========
    
    render: function() {
        var unread_class = "";
        var counts = this.collection.unread_counts();

        if (counts['ps']) {
            unread_class += ' unread_positive';
        }
        if (counts['nt']) {
            unread_class += ' unread_neutral';
        }
        if (counts['ng']) {
            unread_class += ' unread_negative';
        }
        
        this.$el.html(this.template({
          ps           : counts['ps'],
          nt           : counts['nt'],
          ng           : counts['ng'],
          unread_class : unread_class
        }));
        
        return this;
    },
    
    template: _.template('\
        <div class="<%= unread_class %>">\
          <span class="unread_count unread_count_positive <% if (ps) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= ps %>\
          </span>\
          <span class="unread_count unread_count_neutral <% if (nt) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= nt %>\
          </span>\
          <span class="unread_count unread_count_negative <% if (ng) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= ng %>\
          </span>\
        </div>\
    '),
    
    // ===========
    // = Actions =
    // ===========
    
    center: function() {
        var i_width = this.$el.width();
        var o_width = NEWSBLUR.reader.$s.$story_taskbar.width();
        var left = (o_width / 2.0) - (i_width / 2.0);
        var view_taskbar_width = $('.taskbar_nav_view').width();
        var story_buttons_offset = $(".taskbar_nav_story").position().left;
        
        if (i_width + 12 > (story_buttons_offset - view_taskbar_width)) {
            this.$el.hide();
        }

        if (left < view_taskbar_width + 12) {
            left += view_taskbar_width - left + 12;
        }

        this.$el.css({'left': left});
    },
    
    flash: function() {
        var $floater = this.$el;
        
        if (!NEWSBLUR.assets.preference('animations')) return;
        
        _.defer(function() {
            $floater.animate({'opacity': 1}, {'duration': 250, 'queue': false});
            _.delay(function() {
                $floater.animate({'opacity': .2}, {'duration': 250, 'queue': false});
            }, 400);
        });        
    }
    
});