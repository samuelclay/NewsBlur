from celery.task import Task
from apps.social.models import MSharedStory, MSocialProfile, MSocialServices
from utils import log as logging


class PostToService(Task):
    
    def run(self, shared_story_id, service):
        try:
            shared_story = MSharedStory.objects.get(id=shared_story_id)
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
        
class EmailCommentReplies(Task):
    
    def run(self, shared_story_id, reply_id):
        shared_story = MSharedStory.objects.get(id=shared_story_id)
        shared_story.send_emails_for_new_reply(reply_id)
        
class EmailStoryReshares(Task):
    
    def run(self, shared_story_id):
        shared_story = MSharedStory.objects.get(id=shared_story_id)
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
        shared = MSharedStory.share_popular_stories(interactive=False)
        if not shared:
            shared = MSharedStory.share_popular_stories(interactive=False, days=2)
            
        