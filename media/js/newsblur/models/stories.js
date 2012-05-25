NEWSBLUR.Models.Story = Backbone.Model.extend({
    
    score: function() {
        if (NEWSBLUR.reader.active_feed == 'starred') {
            return 1;
        } else {
            return NEWSBLUR.utils.compute_story_score(this);
        }
    },
    
    score_name: function(score) {
        score = !_.isUndefined(score) ? score : this.score();
        var score_name = 'neutral';
        if (score > 0) score_name = 'positive';
        if (score < 0) score_name = 'negative';
        return score_name;
    }
    
});

NEWSBLUR.Collections.Stories = Backbone.Collection.extend({
    
   model: NEWSBLUR.Models.Story
    
});