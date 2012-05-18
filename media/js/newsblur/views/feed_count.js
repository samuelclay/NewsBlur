NEWSBLUR.Views.FeedCount = Backbone.View.extend({
    
    render: function() {
        $(this.el).html(this.render_to_string());
        return this;
    },
    
    render_to_string: function() {
        var feed = this.model;
        var unread_class = "";
        if (feed.get('ps')) {
            unread_class += ' unread_positive';
        }
        if (feed.get('nt')) {
            unread_class += ' unread_neutral';
        }
        if (feed.get("ng")) {
            unread_class += ' unread_negative';
        }
        
        var $floater = _.template('\
        <div class="feed_counts_floater <%= unread_class %>">\
          <span class="unread_count unread_count_positive <% if (feed.get("ps")) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= feed.get("ps") %>\
          </span>\
          <span class="unread_count unread_count_neutral <% if (feed.get("nt")) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= feed.get("nt") %>\
          </span>\
          <span class="unread_count unread_count_negative <% if (feed.get("ng")) { %>unread_count_full<% } else { %>unread_count_empty<% } %>">\
            <%= feed.get("ng") %>\
          </span>\
        </div>\
        ', {
          feed         : feed,
          unread_class : unread_class
        });
        
        return $floater;
    }
    
});