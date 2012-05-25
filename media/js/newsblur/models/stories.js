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
    },
    
    has_modifications: function() {
        if (this.get('story_content').indexOf('<ins') != -1) {
            return true;
        } else if (NEWSBLUR.assets.preference('hide_story_changes') && 
                   this.get('story_content').indexOf('<del') != -1) {
            return true;
        }
        return false;
    }
    
});

NEWSBLUR.Collections.Stories = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Story,
   
    read_stories: [],
    
    deselect: function() {
        this.each(function(story) {
            story.set('selected', false);
        });
    },
    
    visible: function() {
        var unread_score = NEWSBLUR.assets.preference('unread_view');
        
        return this.select(function(story) {
            return story.score() >= unread_view;
        });
    },
    
    hidden: function() {
        var unread_score = NEWSBLUR.assets.preference('unread_view');
        
        return this.select(function(story) {
            return story.score() < unread_view;
        });
    }
    
});