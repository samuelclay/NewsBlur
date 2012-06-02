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
                $share_count_friends.append($thumb);
            });
            var $share_count_friends = this.$('.NB-story-share-profiles-friends');
            _.each(this.model.get('share_count_friends'), function(user_id) { 
                var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id);
                $share_count_friends.append($thumb);
            });
        }
        
        if (story.get('comment_count_friends')) {
            _.each(story.get('comments'), _.bind(function(comment) {
                var $comment = new NEWSBLUR.Views.StoryComment({model: comment, story: this.model});
                $el.append($comment);
            }, this));
        }
        
        if (story.get('comment_count_public')) {
            var $public_teaser = $.make('div', { className: 'NB-story-comments-public-teaser-wrapper' }, [
                $.make('div', { className: 'NB-story-comments-public-teaser' }, [
                    'There ',
                    Inflector.pluralize('is', story.get('comment_count_public')),
                    ' ',
                    $.make('b', story.get('comment_count_public')),
                    ' public ',
                    Inflector.pluralize('comment', story.get('comment_count_public'))
                ])
            ]);
            $el.append($public_teaser);
        }
        
        return $comments;
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
    
    load_public_story_comments: function(story_id) {
        var story = this.model.get_story(story_id);
        this.model.load_public_story_comments(story_id, story.get('story_feed_id'), _.bind(function(data) {
            var $comments = $.make('div', { className: 'NB-story-comments-public' });
            var comments = _.select(data.comments, _.bind(function(comment) {
                return !_.contains(this.model.user_profile.get('following_user_ids'), comment.user_id);
            }, this));
            var $header = $.make('div', { 
                className: 'NB-story-comments-public-header-wrapper' 
            }, $.make('div', { 
                className: 'NB-story-comments-public-header' 
            }, Inflector.pluralize(' public comment', comments.length, true))).prependTo($comments);
            _.each(comments, _.bind(function(comment) {
                var $comment = new NEWSBLUR.Views.StoryComment({model: comment, story: this.model});
                $comments.append($comment);
            }, this));
            
            var $story = this.find_story_in_feed_view(story_id);
            $('.NB-story-comments-public-teaser-wrapper', $story).replaceWith($comments);
            // this.fetch_story_locations_in_feed_view();
        }, this));
    }
    
});
