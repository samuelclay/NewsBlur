from utils import json_functions as json
from django.test.client import Client
from django.test import TestCase
from django.core import management
from django.core.urlresolvers import reverse
from django.conf import settings
from apps.rss_feeds.models import Feed, MStory
from mongoengine.connection import connect, disconnect


class FeedTest(TestCase):
    fixtures = ['rss_feeds.json']

    def setUp(self):
        disconnect()
        settings.MONGODB = connect('test_newsblur')
        self.client = Client()

    def tearDown(self):
        settings.MONGODB.drop_database('test_newsblur')

    def test_load_feeds__gawker(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'gawker1.json', verbosity=0)

        feed = Feed.objects.get(feed_link__contains='gawker')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 0)

        feed.update(force=True)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 38)

        management.call_command('loaddata', 'gawker2.json', verbosity=0)

        feed.update(force=True)

        # Test: 1 changed char in content
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 38)

        url = reverse('load-single-feed', kwargs=dict(feed_id=1))
        response = self.client.get(url)
        feed = json.decode(response.content)
        self.assertEquals(len(feed['stories']), 6)

    def test_load_feeds__gothamist(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'gothamist_aug_2009_1.json', verbosity=0)
        feed = Feed.objects.get(feed_link__contains='gothamist')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 0)

        feed.update(force=True)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 42)

        url = reverse('load-single-feed', kwargs=dict(feed_id=4))
        response = self.client.get(url)
        content = json.decode(response.content)
        self.assertEquals(len(content['stories']), 6)

        management.call_command('loaddata', 'gothamist_aug_2009_2.json', verbosity=0)
        feed.update(force=True)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 42)

        url = reverse('load-single-feed', kwargs=dict(feed_id=4))
        response = self.client.get(url)
        # print [c['story_title'] for c in json.decode(response.content)]
        content = json.decode(response.content)
        # Test: 1 changed char in title
        self.assertEquals(len(content['stories']), 6)

    def test_load_feeds__slashdot(self):
        self.client.login(username='conesus', password='test')

        old_story_guid = "tag:google.com,2005:reader/item/4528442633bc7b2b"

        management.call_command('loaddata', 'slashdot1.json', verbosity=0)

        feed = Feed.objects.get(feed_link__contains='slashdot')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 0)

        management.call_command('refresh_feed', force=1, feed=5, single_threaded=True, daemonize=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 38)

        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        self.assertEquals(content['feeds']['5']['nt'], 38)

        self.client.post(reverse('mark-story-as-read'), {'story_id': old_story_guid, 'feed_id': 5})

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEquals(content['feeds']['5']['nt'], 37)

        management.call_command('loaddata', 'slashdot2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=5, single_threaded=True, daemonize=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 38)

        url = reverse('load-single-feed', kwargs=dict(feed_id=5))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEquals(len(feed['stories']), 6)

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEquals(content['feeds']['5']['nt'], 37)

    def test_load_feeds__motherjones(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'motherjones1.json', verbosity=0)

        feed = Feed.objects.get(feed_link__contains='motherjones')
        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 0)

        management.call_command('refresh_feed', force=1, feed=feed.pk, single_threaded=True, daemonize=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 10)

        response = self.client.get(reverse('load-feeds'))
        content = json.decode(response.content)
        self.assertEquals(content['feeds'][str(feed.pk)]['nt'], 10)

        self.client.post(reverse('mark-story-as-read'), {'story_id': stories[0].story_guid, 'feed_id': feed.pk})

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEquals(content['feeds'][str(feed.pk)]['nt'], 9)

        management.call_command('loaddata', 'motherjones2.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=feed.pk, single_threaded=True, daemonize=False)

        stories = MStory.objects(story_feed_id=feed.pk)
        self.assertEquals(stories.count(), 10)

        url = reverse('load-single-feed', kwargs=dict(feed_id=feed.pk))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEquals(len(feed['stories']), 6)

        response = self.client.get(reverse('refresh-feeds'))
        content = json.decode(response.content)
        self.assertEquals(content['feeds'][str(feed['feed_id'])]['nt'], 9)

    def test_load_feeds__brokelyn__invalid_xml(self):
        self.client.login(username='conesus', password='test')

        management.call_command('loaddata', 'brokelyn.json', verbosity=0)
        management.call_command('refresh_feed', force=1, feed=6, single_threaded=True, daemonize=False)

        url = reverse('load-single-feed', kwargs=dict(feed_id=6))
        response = self.client.get(url)

        # pprint([c['story_title'] for c in json.decode(response.content)])
        feed = json.decode(response.content)

        # Test: 1 changed char in title
        self.assertEquals(len(feed['stories']), 6)

    def test_all_feeds(self):
        pass
