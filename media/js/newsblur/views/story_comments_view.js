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
            this.render_shares_friends();
            this.render_comments_public();
            this.$el.toggleClass('NB-hidden', (!this.model.get('comment_count') && 
                                               !this.model.get('share_count_friends')));
        }

        return this;
    },
    
    destroy: function() {
        this.remove();
    },
    
    render_teaser: function() {
        if (!this.model.get('share_count')) return;
        
        var $comments_friends = this.$('.NB-story-share-profiles-comments-friends');
        var $comments_public = this.$('.NB-story-share-profiles-comments-public');
        _.each(this.model.get('commented_by_friends'), function(user_id) { 
            var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id).render().el;
            $comments_friends.append($thumb);
        });
        _.each(this.model.get('commented_by_public'), function(user_id) { 
            var $thumb = NEWSBLUR.Views.ProfileThumb.create(user_id).render().el;
            $comments_public.append($thumb);
        });
        if (!this.model.friend_comments.length && !this.model.public_comments.length && !this.model.friend_shares.length) {
            this.$el.hide();
        }
        
        var $shares_friends = this.$('.NB-story-share-profiles-shares-friends');
        var $shares_public = this.$('.NB-story-share-profiles-shares-public');
        var comment_user_ids = this.model.get('comment_user_ids');
        _.each(this.model.get('shared_by_friends'), function(user_id) { 
            if (_.contains(comment_user_ids, user_id)) return;
            var profile_thumb = NEWSBLUR.Views.ProfileThumb.create(user_id);
            if (!profile_thumb) return;
            var $thumb = profile_thumb.render().el;
            $shares_friends.append($thumb);
        });
        _.each(this.model.get('shared_by_public'), function(user_id) { 
            if (_.contains(comment_user_ids, user_id)) return;
            var profile_thumb = NEWSBLUR.Views.ProfileThumb.create(user_id);
            if (!profile_thumb) return;
            var $thumb = profile_thumb.render().el;
            $shares_public.append($thumb);
        });
    },
    
    render_comments_friends: function() {
        if (!this.model.get('comment_count_friends') || !this.model.get('comment_count')) return;
        
        var $header = $.make('div', { 
            className: 'NB-story-comments-public-header-wrapper' 
        }, $.make('div', { 
            className: 'NB-story-comments-public-header NB-module-header' 
        }, [
            Inflector.pluralize(' comment', this.model.get('comment_count_friends'), true)
        ]));
        
        this.$el.append($header);
        
        this.model.friend_comments.each(_.bind(function(comment) {
            var $comment = new NEWSBLUR.Views.StoryComment({
                model: comment, 
                story: this.model,
                friend_comment: true
            }).render().el;
            this.$el.append($comment);
        }, this));
    },

    render_shares_friends: function() {
        var shares_without_comments = this.model.get('shared_by_friends');
        if (shares_without_comments.length <= 0) return;
        
        var $header = $.make('div', { 
            className: 'NB-story-comments-public-header-wrapper' 
        }, $.make('div', { 
            className: 'NB-story-comments-public-header NB-module-header' 
        }, [
            Inflector.pluralize(' share', shares_without_comments.length, true)
        ]));
        
        this.$el.append($header);
        
        this.model.friend_shares.each(_.bind(function(comment) {
            var $comment = new NEWSBLUR.Views.StoryComment({
                model: comment,
                story: this.model,
                friend_share: true
            }).render().el;
            this.$el.append($comment);
        }, this));
    },
    
    render_comments_public: function() {
        if (!this.model.get('comment_count_public') || !this.model.get('comment_count')) return;
        
        if (NEWSBLUR.assets.preference('hide_public_comments')) {
            var $public_teaser = $.make('div', { className: 'NB-story-comments-public-teaser-wrapper' }, [
                $.make('div', { className: 'NB-story-comments-public-teaser NB-module-header' }, [
                    $.make('div', { className: 'NB-story-comments-expand-icon' }),
                    'There ',
                    Inflector.pluralize('is', this.model.get('comment_count_public')),
                    ' ',
                    $.make('b', this.model.get('comment_count_public')),
                    ' public ',
                    Inflector.pluralize('comment', this.model.get('comment_count_public'))
                ])
            ]);
            this.$el.append($public_teaser);
        } else {
            var $header = $.make('div', { 
                className: 'NB-story-comments-public-header-wrapper' 
            }, $.make('div', { 
                className: 'NB-story-comments-public-header NB-module-header' 
            }, Inflector.pluralize(' public comment', this.model.get('comment_count_public'), true)));
        
            this.$el.append($header);
        
            this.model.public_comments.each(_.bind(function(comment) {
                var $comment = new NEWSBLUR.Views.StoryComment({
                    model: comment, 
                    story: this.model,
                    public_comment: true
                }).render().el;
                this.$el.append($comment);
            }, this));
        }
    },
    
    template: _.template('\
        <div class="NB-story-comments-shares-teaser-wrapper NB-feed-story-shares">\
            <div class="NB-story-comments-shares-teaser">\
                <% if (story.get("comment_count")) { %>\
                    <div class="NB-story-comments-label">\
                        <b><%= story.get("comment_count") %></b>\
                        <%= Inflector.pluralize("comment", story.get("comment_count")) %>\
                        <% if (story.get("reply_count")) { %>\
                            and \
                            <%= story.get("reply_count") %>\
                            <%= Inflector.pluralize("reply", story.get("reply_count")) %>\
                        <% } %>\
                    </div>\
                    <div class="NB-story-share-profiles NB-story-share-profiles-comments">\
                        <div class="NB-story-share-profiles-comments-friends"></div>\
                        <div class="NB-story-share-profiles-comments-public"></div>\
                    </div>\
                <% } %>\
                <div class="NB-right">\
                    <div class="NB-story-share-label">\
                        Shared by\
                        <b><%= story.get("share_count") %></b>\
                        <%= Inflector.pluralize("person", story.get("share_count")) %>\
                    </div>\
                    <div class="NB-story-share-profiles NB-story-share-profiles-shares">\
                        <div class="NB-story-share-profiles-shares-friends"></div>\
                        <div class="NB-story-share-profiles-shares-public"></div>\
                    </div>\
                </div>\
            </div>\
        </div>\
    '),
    
    // ==========
    // = Events =
    // ==========
    
    load_public_story_comments: function() {
        var following_user_ids = NEWSBLUR.assets.user_profile.get('following_user_ids');
        this.$(".NB-story-comments-expand-icon").addClass("NB-loading");
        
        NEWSBLUR.assets.load_public_story_comments(this.model.id, this.model.get('story_feed_id'), _.bind(function(comments) {
            this.$(".NB-story-comments-expand-icon").addClass("NB-loading");
            var $comments = $.make('div', { className: 'NB-story-comments-public' });
            var public_comments = comments.select(_.bind(function(comment) {
                return !_.contains(following_user_ids, comment.get('user_id'));
            }, this));
            var $header = $.make('div', { 
                className: 'NB-story-comments-public-header-wrapper' 
            }, $.make('div', { 
                className: 'NB-story-comments-public-header NB-module-header' 
            }, Inflector.pluralize(' public comment', public_comments.length, true))).prependTo($comments);

            _.each(public_comments, _.bind(function(comment) {
                var $comment = new NEWSBLUR.Views.StoryComment({
                    model: comment, 
                    story: this.model,
                    public_comment: true
                }).render().el;
                $comments.append($comment);
            }, this));
            
            this.$('.NB-story-comments-public-teaser-wrapper').replaceWith($comments);
            NEWSBLUR.app.story_list.fetch_story_locations_in_feed_view();
        }, this));
    }
    
});
