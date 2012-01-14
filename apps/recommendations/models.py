from django.db import models
from django.contrib.auth.models import User
from apps.rss_feeds.models import Feed

class RecommendedFeed(models.Model):
    feed          = models.ForeignKey(Feed, related_name='recommendations')
    user          = models.ForeignKey(User, related_name='recommendations')
    description   = models.TextField(null=True, blank=True)
    is_public     = models.BooleanField(default=False)
    created_date  = models.DateField(auto_now_add=True)
    approved_date = models.DateField(null=True)
    declined_date = models.DateField(null=True)
    twitter       = models.CharField(max_length=50, null=True, blank=True)
    
    def __unicode__(self):
        return "%s (%s)" % (self.feed, self.approved_date or self.created_date)
        
    class Meta:
        ordering = ['-approved_date', '-created_date']


class RecommendedFeedUserFeedback(models.Model):
    recommendation = models.ForeignKey(RecommendedFeed, related_name='feedback')
    user           = models.ForeignKey(User, related_name='feed_feedback')
    score          = models.IntegerField(default=0)
    created_date   = models.DateField(auto_now_add=True)