from bson.objectid import ObjectId
from celery.task import Task
from apps.social.models import MSharedStory, MSocialProfile, MSocialServices, MSocialSubscription
from django.contrib.auth.models import User
from utils import log as logging


class PostToService(Task):
    
    def run(self, shared_story_id, service):
        try:
            shared_story = MSharedStory.objects.get(id=ObjectId(shared_story_id))
            shared_story.post_to_service(service)
        except MSharedStory.DoesNotExist:
            logging.debug(" ---> Shared story not found (%s). Can't post to: %s" % (shared_story_id, service))
            
class EmailNewFollower(Task):
    
    def run(self, follower_user_id, followee_user_id):
        user_profile = MSocialProfile.get_user(followee_user_id)
        user_profile.send_email_for_new_follower(follower_user_id)
                    
class EmailFollowRequest(Task):
    
    def run(self, follower_user_id, followee_user_id):
        user_profile = MSocialProfile.get_user(followee_user_id)
        user_profile.send_email_for_follow_request(follower_user_id)
          
class EmailFirstShare(Task):
    
    def run(self, user_id):
        user = User.objects.get(pk=user_id)
        user.profile.send_first_share_to_blurblog_email()
        
class EmailCommentReplies(Task):
    
    def run(self, shared_story_id, reply_id):
        shared_story = MSharedStory.objects.get(id=ObjectId(shared_story_id))
        shared_story.send_emails_for_new_reply(ObjectId(reply_id))
        
class EmailStoryReshares(Task):
    
    def run(self, shared_story_id):
        shared_story = MSharedStory.objects.get(id=ObjectId(shared_story_id))
        shared_story.send_email_for_reshare()
        
class SyncTwitterFriends(Task):
    
    def run(self, user_id):
        social_services = MSocialServices.objects.get(user_id=user_id)
        social_services.sync_twitter_friends()

class SyncFacebookFriends(Task):
    
    def run(self, user_id):
        social_services = MSocialServices.objects.get(user_id=user_id)
        social_services.sync_facebook_friends()
                
class SharePopularStories(Task):
    name = 'share-popular-stories'

    def run(self, **kwargs):
        logging.debug(" ---> Sharing popular stories...")
        MSharedStory.share_popular_stories(interactive=False)
            
class CleanSocialSpam(Task):
    name = 'clean-social-spam'

    def run(self, **kwargs):
        logging.debug(" ---> Finding social spammers...")
        MSharedStory.count_potential_spammers(destroy=True)
            

class UpdateRecalcForSubscription(Task):

    def run(self, subscription_user_id, shared_story_id):
        user = User.objects.get(pk=subscription_user_id)
        socialsubs = MSocialSubscription.objects.filter(subscription_user_id=subscription_user_id)
        try:
            shared_story = MSharedStory.objects.get(id=ObjectId(shared_story_id))
        except MSharedStory.DoesNotExist:
            return

        logging.debug(" ---> ~FM~SNFlipping unread recalc for ~SB%s~SN subscriptions to ~SB%s's blurblog~SN" % (
            socialsubs.count(),
            user.username
        ))
        for socialsub in socialsubs:
            socialsub.needs_unread_recalc = True
            socialsub.save()
        
        shared_story.publish_update_to_subscribers()
