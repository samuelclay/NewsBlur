NEWSBLUR.Views.StoryCommentReply = Backbone.View.extend({
    
    className: "NB-story-comment-reply",
    
    events: {
        "click .NB-user-avatar": "open_social_profile_modal",
        "click .NB-story-comment-username": "open_social_profile_modal",
        "click .NB-story-comment-reply-edit-button": "edit_reply"
    },
    
    render: function() {
        var $reply = $(this.template({
            reply: this.model,
            user: NEWSBLUR.assets.get_user(this.model.get('user_id')),
            current_user_id: NEWSBLUR.Globals.user_id
        }));
        
        this.$el.html($reply);
        
        return this;
    },
    
    template: _.template('\
        <img class="NB-user-avatar NB-story-comment-reply-photo" src="<%= user.get("photo_url") %>" />\
        <div class="NB-story-comment-username NB-story-comment-reply-username"><%= user.get("username") %></div>\
        <div class="NB-story-comment-date NB-story-comment-reply-date"><%= reply.get("publish_date") %> ago</div>\
        <% if (reply.get("user_id") == current_user_id) { %>\
            <div class="NB-story-comment-edit-button NB-story-comment-reply-edit-button">\
                <div class="NB-story-comment-edit-button-wrapper">edit</div>\
            </div>\
        <% } %>\
        <div class="NB-story-comment-reply-content"><%= reply.get("comments") %></div>\
    '),
    
    // ==========
    // = Events =
    // ==========
    
    open_social_profile_modal: function(e) {
        e.stopPropagation();
        NEWSBLUR.reader.open_social_profile_modal(this.model.get('user_id'));
    },
    
    edit_reply: function() {
        this.options.comment.open_reply({is_editing: true, reply: this.model, $reply: this.$el});
    }

    
});