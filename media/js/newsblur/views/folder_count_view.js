NEWSBLUR.Views.FolderCount = Backbone.View.extend({
    
    className: 'feed_counts_floater',
    
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