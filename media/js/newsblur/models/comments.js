NEWSBLUR.Models.Comment = Backbone.Model.extend({
    
    initialize: function() {
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