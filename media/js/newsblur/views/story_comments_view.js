NEWSBLUR.Views.StoryCommentsView = Backbone.View.extend({
    
    className: 'NB-feed-story-comments',
    
    events: {
        "click .NB-story-comments-public-teaser": "load_public_story_comments"

    },
    
    render: function() {
        var self = this;
        var $el = this.$el;
        
        if (this.model.get('share_count')) {
            this.$el.html(this.template({
                story: this.model
            }));
            this.render_teaser();
            this.render_comments_friends();
            this.render_comments_public();
        }

        return this;
    },
    
    render_teaser: function() {
        if (!this.model.get('share_count')) return;
        
        var $share_count_public = this.$('.NB-story-share-profiles-public');
        _.each(this.model.get('shared_by_public'), function(user_id) { 
            var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id).render().el;
            $share_count_public.append($thumb);
        });
        var $share_count_friends = this.$('.NB-story-share-profiles-friends');
        _.each(this.model.get('shared_by_friends'), function(user_id) { 
            var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id).render().el;
            $share_count_friends.append($thumb);
        });
    },
    
    render_comments_friends: function() {
        if (!this.model.get('comment_count_friends') || !this.model.get('comment_count')) return;
        
        this.model.friend_comments.each(_.bind(function(comment) {
            var $comment = new NEWSBLUR.Views.StoryComment({model: comment, story: this.model}).render().el;
            this.$el.append($comment);
        }, this));
    },
    
    render_comments_public: function() {
        if (!this.model.get('comment_count_public') || !this.model.get('comment_count')) return;

        var $header = $.make('div', { 
            className: 'NB-story-comments-public-header-wrapper' 
        }, $.make('div', { 
            className: 'NB-story-comments-public-header' 
        }, Inflector.pluralize(' public comment', this.model.get('comment_count_public'), true)));
        
        this.$el.append($header);
        
        this.model.public_comments.each(_.bind(function(comment) {
            var $comment = new NEWSBLUR.Views.StoryComment({model: comment, story: this.model}).render().el;
            this.$el.append($comment);
        }, this));
        
        // var $public_teaser = $.make('div', { className: 'NB-story-comments-public-teaser-wrapper' }, [
        //     $.make('div', { className: 'NB-story-comments-public-teaser' }, [
        //         'There ',
        //         Inflector.pluralize('is', this.model.get('comment_count_public')),
        //         ' ',
        //         $.make('b', this.model.get('comment_count_public')),
        //         ' public ',
        //         Inflector.pluralize('comment', this.model.get('comment_count_public'))
        //     ])
        // ]);
        // this.$el.append($public_teaser);
    },
    
    template: _.template('\
        <div class="NB-story-comments-shares-teaser-wrapper">\
            <div class="NB-story-comments-shares-teaser">\
                <% if (story.get("share_count")) { %>\
                    <div class="NB-right">\
                        Shared by \
                        <b><%= story.get("share_count") %></b>\
                        <%= Inflector.pluralize("person", story.get("share_count")) %>\
                    </div>\
                    <% if (story.get("share_count_public")) { %>\
                        <div class="NB-story-share-profiles NB-story-share-profiles-public"></div>\
                    <% } %>\
                <% } %>\
                <% if (story.get("share_count")) { %>\
                    <% if (story.get("share_count_friends")) { %>\
                        <div class="NB-story-share-label">Shared by: </div>\
                    <% } %>\
                    <% if (story.get("share_count_friends")) { %>\
                        <div class="NB-story-share-profiles NB-story-share-profiles-friends"></div>\
                    <% } %>\
                <% } %>\
            </div>\
        </div>\
    '),
    
    // ==========
    // = Events =
    // ==========
    
    load_public_story_comments: function() {
        var following_user_ids = NEWSBLUR.assets.user_profile.get('following_user_ids');
        NEWSBLUR.assets.load_public_story_comments(this.model.id, this.model.get('story_feed_id'), _.bind(function(comments) {
            var $comments = $.make('div', { className: 'NB-story-comments-public' });
            var public_comments = comments.select(_.bind(function(comment) {
                return !_.contains(following_user_ids, comment.get('user_id'));
            }, this));
            var $header = $.make('div', { 
                className: 'NB-story-comments-public-header-wrapper' 
            }, $.make('div', { 
                className: 'NB-story-comments-public-header' 
            }, Inflector.pluralize(' public comment', public_comments.length, true))).prependTo($comments);

            _.each(public_comments, _.bind(function(comment) {
                var $comment = new NEWSBLUR.Views.StoryComment({model: comment, story: this.model}).render().el;
                $comments.append($comment);
            }, this));
            
            this.$('.NB-story-comments-public-teaser-wrapper').replaceWith($comments);
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }, this));
    }
    
});
