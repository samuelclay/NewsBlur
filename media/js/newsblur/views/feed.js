NEWSBLUR.Views.Feed = Backbone.View.extend({
    
    render: function() {
        var feed = this.model;
        var unread_class = '';
        var exception_class = '';
        if (feed.is_social() && !feed.get('feed_title')) {
            var profile = NEWSBLUR.assets.user_profiles.get(feed.get('user_id')) || {};
            feed.set('feed_title', profile.feed_title);
        }
        if (feed.get('ps')) {
            unread_class += ' unread_positive';
        }
        if (feed.get('nt')) {
            unread_class += ' unread_neutral';
        }
        if (feed.get('ng')) {
            unread_class += ' unread_negative';
        }
        if (feed.get('has_exception') && feed.get('exception_type') == 'feed') {
            exception_class += ' NB-feed-exception';
        }
        if (feed.get('not_yet_fetched') && !feed.get('has_exception')) {
            exception_class += ' NB-feed-unfetched';
        }
        if (!feed.get('active') && !feed.get('subscription_user_id')) {
            exception_class += ' NB-feed-inactive';
        }
        if (feed.get('subscription_user_id') && !feed.get('shared_stories_count')) {
            unread_class += ' NB-feed-inactive';
        }
        var $feed = _.template('\
        <<%= list_type %> class="feed <%= unread_class %> <%= exception_class %> <% if (toplevel) { %>NB-toplevel<% } %>" data-id="<%= feed.id %>">\
          <div class="feed_counts">\
            <%= feed_counts_floater %>\
          </div>\
          <img class="feed_favicon" src="<%= $.favicon(feed, empty_on_missing) %>">\
          <span class="feed_title">\
            <%= feed.get("feed_title") %>\
            <% if (type == "story") { %>\
              <span class="NB-feedbar-train-feed" title="Train Intelligence"></span>\
              <span class="NB-feedbar-statistics" title="Statistics"></span>\
            <% } %>\
          </span>\
          <% if (type == "story") { %>\
            <div class="NB-feedbar-last-updated">\
              <span class="NB-feedbar-last-updated-label">Updated:</span>\
              <span class="NB-feedbar-last-updated-date">\
                <% if (feed.get("updated")) { %>\
                  <%= feed.get("updated") %> ago\
                <% } else { %>\
                  Loading...\
                <% } %>\
              </span>\
            </div>\
            <div class="NB-feedbar-mark-feed-read">Mark All as Read</div>\
          <% } %>\
          <div class="NB-feed-exception-icon"></div>\
          <div class="NB-feed-unfetched-icon"></div>\
          <div class="NB-feedlist-manage-icon"></div>\
        </<%= list_type %>>\
        ', {
          feed                : feed,
          type                : this.options.type,
          feed_counts_floater : new NEWSBLUR.Views.FeedCount({model: feed}).render_to_string(),
          unread_class        : unread_class,
          exception_class     : exception_class,
          toplevel            : this.options.depth == 0,
          list_type           : this.options.type == 'feed' ? 'li' : 'div',
          empty_on_missing    : !NEWSBLUR.reader.flags['favicons_downloaded'] && 
                                !NEWSBLUR.reader.flags['showing_feed_in_tryfeed_view'] &&
                                !NEWSBLUR.reader.flags['showing_social_feed_in_tryfeed_view']
        });
        
        this.setElement($feed);
        return this;
    }

});