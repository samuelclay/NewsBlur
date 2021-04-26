import redis
from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.core import management
from django.urls import reverse
from django.conf import settings
from apps.rss_feeds.models import Feed, MStory
from mongoengine.connection import connect, disconnect


class Test_Feed(TestCase):

    fixtures = ['initial_data.json']

    def setUp(self):
        disconnect()
        settings.MONGODB = connect('test_newsblur')
        settings.REDIS_STORY_HASH_POOL = redis.ConnectionPool(host=settings.REDIS_STORY['host'], port=6379, db=10)
        settings.REDIS_FEED_READ_POOL = redis.ConnectionPool(host=settings.REDIS_SESSIONS['host'], port=6379, db=10)

        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        r.delete('RS:1')
        r.delete('lRS:1')
        r.delete('RS:1:766')
        r.delete('zF:766')
        r.delete('F:766')
        
        self.client = Client()

    def tearDown(self):
        settings.MONGODB.drop_database('test_newsblur')

    def test_load_feeds__gawker(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'gawker1.json', verbosity=0, skip_checks=False)

        feed = Feed.objects.get(pk=10)
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 0)

        feed.update(force=True)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 38)

        management.call_command('loaddata', 'gawker2.json', verbosity=0, skip_checks=False)

        feed.update(force=True)

        # Test: 1 changed char in content
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 38)

        url = reverse('load-single-feed', kwargs=dict(feed_id=10))
        response = self.client.get(url)
        feed = json.decode(response.content)
        self.assertEqual(len(feed['stories']), 6)

    def test_load_feeds__gothamist(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'gothamist_aug_2009_1.json', verbosity=0, skip_checks=False)
        feed = Feed.objects.get(feed_link__contains='gothamist')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 0)

        feed.update(force=True)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 42)

        url = reverse('load-single-feed', kwargs=dict(feed_id=4))
        response = self.client.get(url)
        content = json.decode(response.content)
        self.assertEqual(len(content['stories']), 6)

        management.call_command('loaddata', 'gothamist_aug_2009_2.json', verbosity=0, skip_checks=False)
        feed.update(force=True)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 42)

        url = reverse('load-single-feed', kwargs=dict(feed_id=4))
        response = self.client.get(url)
        # print [c['story_title'] for c in json.decode(response.content)]
        content = json.decode(response.content)
        # Test: 1 changed char in title
        self.assertEqual(len(content['stories']), 6)

    def test_load_feeds__slashdot(self):
        self.client.login(username='conesus', password='test')

        old_story_guid = "tag:google.com,2005:reader/item/4528442633bc7b2b"

        management.call_command('loaddata', 'slashdot1.json', verbosity=0, skip_checks=False)

        feed = Feed.objects.get(feed_link__contains='slashdot')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 0)

        management.call_command('refresh_feed', force=1, feed=5, daemonize=False, skip_checks=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 38)

        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds']['5']['nt'], 38)

        self.client.post(reverse('mark-story-as-read'), {'story_id': old_story_guid, 'feed_id': 5})

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds']['5']['nt'], 37)

        management.call_command('loaddata', 'slashdot2.json', verbosity=0, skip_checks=False)
        management.call_command('refresh_feed', force=1, feed=5, daemonize=False, skip_checks=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 38)

        url = reverse('load-single-feed', kwargs=dict(feed_id=5))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEqual(len(feed['stories']), 6)

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds']['5']['nt'], 37)

    def test_load_feeds__motherjones(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'motherjones1.json', verbosity=0, skip_checks=False)

        feed = Feed.objects.get(feed_link__contains='motherjones')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 0)

        management.call_command('refresh_feed', force=1, feed=feed.pk, daemonize=False, skip_checks=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 10)

        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds'][str(feed.pk)]['nt'], 10)

        self.client.post(reverse('mark-story-as-read'), {'story_id': stories[0].story_guid, 'feed_id': feed.pk})

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds'][str(feed.pk)]['nt'], 9)

        management.call_command('loaddata', 'motherjones2.json', verbosity=0, skip_checks=False)
        management.call_command('refresh_feed', force=1, feed=feed.pk, daemonize=False, skip_checks=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 10)

        url = reverse('load-single-feed', kwargs=dict(feed_id=feed.pk))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEqual(len(feed['stories']), 6)

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds'][str(feed['feed_id'])]['nt'], 9)

    def test_load_feeds__google(self):
        # Freezegun the date to 2017-04-30
        
        self.client.login(username='conesus', password='test')
        old_story_guid = "blog.google:443/topics/inside-google/google-earths-incredible-3d-imagery-explained/"
        management.call_command('loaddata', 'google1.json', verbosity=1, skip_checks=False)
        print((Feed.objects.all()))
        feed = Feed.objects.get(pk=766)
        print((" Testing test_load_feeds__google: %s" % feed))
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 0)

        management.call_command('refresh_feed', force=False, feed=766, daemonize=False, skip_checks=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 20)

        response = self.client.get(reverse('load-feeds')+"?update_counts=true")
        content = json.decode(response.content)
        self.assertEqual(content['feeds']['766']['nt'], 20)

        old_story = MStory.objects.get(story_feed_id=feed.pk, story_guid__contains=old_story_guid)
        self.client.post(reverse('mark-story-hashes-as-read'), {'story_hash': old_story.story_hash})

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds']['766']['nt'], 19)

        management.call_command('loaddata', 'google2.json', verbosity=1, skip_checks=False)
        management.call_command('refresh_feed', force=False, feed=766, daemonize=False, skip_checks=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEqual(stories.count(), 20)

        url = reverse('load-single-feed', kwargs=dict(feed_id=766))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEqual(len(feed['stories']), 6)

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEqual(content['feeds']['766']['nt'], 19)
        
    def test_load_feeds__brokelyn__invalid_xml(self):
        BROKELYN_FEED_ID = 16
        self.client.login(username='conesus', password='test')
        management.call_command('loaddata', 'brokelyn.json', verbosity=0)
        self.assertEquals(Feed.objects.get(pk=BROKELYN_FEED_ID).pk, BROKELYN_FEED_ID)
        management.call_command('refresh_feed', force=1, feed=BROKELYN_FEED_ID, daemonize=False)

        management.call_command('loaddata', 'brokelyn.json', verbosity=0, skip_checks=False)
        management.call_command('refresh_feed', force=1, feed=16, daemonize=False, skip_checks=False)

        url = reverse('load-single-feed', kwargs=dict(feed_id=BROKELYN_FEED_ID))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEqual(len(feed['stories']), 6)

    def test_all_feeds(self):
        pass
