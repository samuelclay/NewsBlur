NEWSBLUR.Views.StoryCommentsView = Backbone.View.extend({
    
    className: 'NB-feed-story-comments',
    
    events: {
        "click .NB-story-comments-public-teaser": "load_public_story_comments"

    },
    
    open_social_profile_modal: function(e) {
        var user_id = this.$('.NB-story-share-profile').data('user_id');
        $(e.currentTarget).tipsy('hide');
        this.open_social_profile_modal(user_id);
    },
    
    render: function() {
        var self = this;
        var $el = this.$el;
        
        if (this.model.get('share_count')) {
            this.$el.html(this.template({
                story: this.model
            }));
        }
        
        if (this.model.get('share_count')) {
            var $share_count_public = this.$('.NB-story-share-profiles-public');
            _.each(this.model.get('shared_by_public'), function(user_id) { 
                var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id);
                $share_count_public.append($thumb);
            });
            var $share_count_friends = this.$('.NB-story-share-profiles-friends');
            _.each(this.model.get('share_count_friends'), function(user_id) { 
                var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id);
                $share_count_friends.append($thumb);
            });
        }
        
        if (this.model.get('comment_count_friends')) {
            this.model.comments.each(_.bind(function(comment) {
                var $comment = new NEWSBLUR.Views.StoryComment({model: comment, story: this.model}).render().el;
                $el.append($comment);
            }, this));
        }
        
        if (this.model.get('comment_count_public')) {
            var $public_teaser = $.make('div', { className: 'NB-story-comments-public-teaser-wrapper' }, [
                $.make('div', { className: 'NB-story-comments-public-teaser' }, [
                    'There ',
                    Inflector.pluralize('is', this.model.get('comment_count_public')),
                    ' ',
                    $.make('b', this.model.get('comment_count_public')),
                    ' public ',
                    Inflector.pluralize('comment', this.model.get('comment_count_public'))
                ])
            ]);
            $el.append($public_teaser);
        }
        
        return this;
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
                        <div class="NB-story-share-profiles NB-story-share-profiles-public"><div>\
                    <% } %>\
                    <% if (story.get("share_count_friends")) { %>\
                        <div class="NB-story-share-profiles NB-story-share-profiles-friends"><div>\
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
            console.log(["comments", comments]);
            var $comments = $.make('div', { className: 'NB-story-comments-public' });
            var public_comments = comments.select(_.bind(function(comment) {
                return !_.contains(following_user_ids, comment.get('user_id'));
            }, this));
            console.log(["public_comments", public_comments]);
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
            // this.fetch_story_locations_in_feed_view();
        }, this));
    }
    
});
