NEWSBLUR.Models.Comment = Backbone.Model.extend({
    
    urlRoot: '/social/comment',
    
    initialize: function() {
        this.bind('change:replies', this.changes_replies);
        this.bind('change:comments', this.strip_html_in_comments);
        this.changes_replies();
    },
    
    changes_replies: function() {
        if (this.get('replies')) {
            this.replies = new NEWSBLUR.Collections.CommentReplies(this.get('replies'));
        }
    },
    
    strip_html_in_comments: function() {
        this.attributes['comments'] = this.get('comments').replace(/<\/?[^>]+(>|$)/g, "");
    }
    
});

NEWSBLUR.Collections.Comments = Backbone.Collection.extend({
    
    url: '/social/comments',
    
    model: NEWSBLUR.Models.Comment
    
});

NEWSBLUR.Models.CommentReply = Backbone.Model.extend({
    
    
    
});

NEWSBLUR.Collections.CommentReplies = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.CommentReply
    
});