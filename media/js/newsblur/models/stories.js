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
    
    active_story: null,
    
    initialize: function() {
        this.bind('change', this.detect_selected_story);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    deselect: function() {
        this.each(function(story) {
            story.set('selected', false);
        });
    },
    
    // ==================
    // = Model Managers =
    // ==================
    
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
    },
    
    // ===========
    // = Getters =
    // ===========
    
    get_next_story: function() {
        if (!this.active_story) {
            return this.at(0);
        }
        
        var current_index = this.indexOf(this.active_story);
        return this.at(current_index+1);
    },
    
    get_previous_story: function() {
        if (!this.active_story) {
            return this.at(0);
        }
        
        var current_index = this.indexOf(this.active_story);
        return this.at(current_index-1);
    },
    
    // ==========
    // = Events =
    // ==========
    
    detect_selected_story: function() {
        this.active_story = this.detect(function(story) {
            return story.get('selected');
        });
    }
    
});