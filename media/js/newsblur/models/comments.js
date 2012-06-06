NEWSBLUR.Models.Comment = Backbone.Model.extend({
    
    initialize: function() {
        this.bind('change:replies', this.changes_replies);
        this.changes_replies();
    },
    
    changes_replies: function() {
        if (this.get('replies')) {
            this.replies = new NEWSBLUR.Collections.CommentReplies(this.get('replies'));
        }
    }
    
});

NEWSBLUR.Collections.Comments = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Comment
    
});

NEWSBLUR.Models.CommentReply = Backbone.Model.extend({
    
    
    
});

NEWSBLUR.Collections.CommentReplies = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.CommentReply
    
});