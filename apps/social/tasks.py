from celery.task import Task
from apps.social.models import MSharedStory, MSocialProfile


class PostToService(Task):
    
    def run(self, shared_story_id, service):
        try:
            shared_story = MSharedStory.objects.get(id=shared_story_id)
            shared_story.post_to_service(service)
        except MSharedStory.DoesNotExist:
            print "Story not found (%s). Can't post to: %s" % (shared_story_id, service)
            
class EmailNewFollower(Task):
    
    def run(self, follower_user_id, followee_user_id):
        user_profile = MSocialProfile.objects.get(user_id=followee_user_id)
        user_profile.send_email_for_new_follower(follower_user_id)
        
class EmailCommentReplies(Task):
    
    def run(self, shared_story_id, reply_user_id):
        shared_story = MSharedStory.objects.get(id=shared_story_id)
        shared_story.send_emails_for_new_reply(reply_user_id)
        
