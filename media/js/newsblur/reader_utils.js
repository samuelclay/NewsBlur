NEWSBLUR.utils = {

  compute_story_score: function(story) {
    var score = 0;
    var score_max = Math.max(story.intelligence['title'],
                             story.intelligence['author'],
                             story.intelligence['tags']);
    var score_min = Math.min(story.intelligence['title'],
                             story.intelligence['author'],
                             story.intelligence['tags']);
    if (score_max > 0) score = score_max;
    else if (score_min < 0) score = score_min;
    
    if (score == 0) score = story.intelligence['feed'];
    
    return score;
  }
  
};