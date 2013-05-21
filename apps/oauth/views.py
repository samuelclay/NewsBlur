import urllib
import urlparse
from django.contrib.auth.decorators import login_required
from django.core.urlresolvers import reverse
from django.contrib.auth.models import User
from django.contrib.sites.models import Site
from django.http import HttpResponseForbidden, HttpResponseRedirect
from django.conf import settings
from apps.social.models import MSocialServices
from apps.social.tasks import SyncTwitterFriends, SyncFacebookFriends, SyncAppdotnetFriends
from utils import log as logging
from utils.user_functions import ajax_login_required
from utils.view_functions import render_to
from utils import json_functions as json
from vendor import facebook
from vendor import tweepy
from vendor import appdotnet

@login_required
@render_to('social/social_connect.xhtml')
def twitter_connect(request):
    twitter_consumer_key = settings.TWITTER_CONSUMER_KEY
    twitter_consumer_secret = settings.TWITTER_CONSUMER_SECRET
    
    oauth_token = request.REQUEST.get('oauth_token')
    oauth_verifier = request.REQUEST.get('oauth_verifier')
    denied = request.REQUEST.get('denied')
    if denied:
        logging.user(request, "~BB~FRDenied Twitter connect")
        return {'error': 'Denied! Try connecting again.'}
    elif oauth_token and oauth_verifier:
        try:
            auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
            auth.set_request_token(oauth_token, oauth_verifier)
            access_token = auth.get_access_token(oauth_verifier)
            api = tweepy.API(auth)
            twitter_user = api.me()
        except (tweepy.TweepError, IOError):
            logging.user(request, "~BB~FRFailed Twitter connect")
            return dict(error="Twitter has returned an error. Try connecting again.")

        # Be sure that two people aren't using the same Twitter account.
        existing_user = MSocialServices.objects.filter(twitter_uid=unicode(twitter_user.id))
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed Twitter connect, another user: %s" % user.username)
                return dict(error=("Another user (%s, %s) has "
                                   "already connected with those Twitter credentials."
                                   % (user.username, user.email or "no email")))
            except User.DoesNotExist:
                existing_user.delete()

        social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
        social_services.twitter_uid = unicode(twitter_user.id)
        social_services.twitter_access_key = access_token.key
        social_services.twitter_access_secret = access_token.secret
        social_services.syncing_twitter = True
        social_services.save()

        SyncTwitterFriends.delay(user_id=request.user.pk)
        
        logging.user(request, "~BB~FRFinishing Twitter connect")
        return {}
    else:
        # Start the OAuth process
        auth = tweepy.OAuthHandler(twitter_consumer_key, twitter_consumer_secret)
        auth_url = auth.get_authorization_url()
        logging.user(request, "~BB~FRStarting Twitter connect")
        return {'next': auth_url}


@login_required
@render_to('social/social_connect.xhtml')
def facebook_connect(request):
    facebook_app_id = settings.FACEBOOK_APP_ID
    facebook_secret = settings.FACEBOOK_SECRET
    
    args = {
        "client_id": facebook_app_id,
        "redirect_uri": "http://" + Site.objects.get_current().domain + reverse('facebook-connect'),
        "scope": "offline_access,user_website,publish_actions",
        "display": "popup",
    }

    verification_code = request.REQUEST.get('code')
    if verification_code:
        args["client_secret"] = facebook_secret
        args["code"] = verification_code
        uri = "https://graph.facebook.com/oauth/access_token?" + \
                urllib.urlencode(args)
        response_text = urllib.urlopen(uri).read()
        response = urlparse.parse_qs(response_text)

        if "access_token" not in response:
            logging.user(request, "~BB~FRFailed Facebook connect")
            return dict(error="Facebook has returned an error. Try connecting again.")

        access_token = response["access_token"][-1]

        # Get the user's profile.
        graph = facebook.GraphAPI(access_token)
        profile = graph.get_object("me")
        uid = profile["id"]

        # Be sure that two people aren't using the same Facebook account.
        existing_user = MSocialServices.objects.filter(facebook_uid=uid)
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed FB connect, another user: %s" % user.username)
                return dict(error=("Another user (%s, %s) has "
                                   "already connected with those Facebook credentials."
                                   % (user.username, user.email or "no email")))
            except User.DoesNotExist:
                existing_user.delete()

        social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
        social_services.facebook_uid = uid
        social_services.facebook_access_token = access_token
        social_services.syncing_facebook = True
        social_services.save()
        
        SyncFacebookFriends.delay(user_id=request.user.pk)
        
        logging.user(request, "~BB~FRFinishing Facebook connect")
        return {}
    elif request.REQUEST.get('error'):
        logging.user(request, "~BB~FRFailed Facebook connect")
        return {'error': '%s... Try connecting again.' % request.REQUEST.get('error')}
    else:
        # Start the OAuth process
        logging.user(request, "~BB~FRStarting Facebook connect")
        url = "https://www.facebook.com/dialog/oauth?" + urllib.urlencode(args)
        return {'next': url}

@login_required
@render_to('social/social_connect.xhtml')
def appdotnet_connect(request):
    domain = Site.objects.get_current().domain
    args = {
        "client_id": settings.APPDOTNET_CLIENTID,
        "client_secret": settings.APPDOTNET_SECRET,
        "redirect_uri": "http://" + domain +
                                    reverse('appdotnet-connect'),
        "scope": ["email", "write_post", "follow"],
    }

    oauth_code = request.REQUEST.get('code')
    denied = request.REQUEST.get('denied')
    if denied:
        logging.user(request, "~BB~FRDenied App.net connect")
        return {'error': 'Denied! Try connecting again.'}
    elif oauth_code:
        try:
            adn_auth = appdotnet.Appdotnet(**args)
            response = adn_auth.getAuthResponse(oauth_code)
            adn_resp = json.decode(response)
            access_token = adn_resp['access_token']
            adn_userid = adn_resp['user_id']
        except (IOError):
            logging.user(request, "~BB~FRFailed App.net connect")
            return dict(error="App.net has returned an error. Try connecting again.")

        # Be sure that two people aren't using the same Twitter account.
        existing_user = MSocialServices.objects.filter(appdotnet_uid=unicode(adn_userid))
        if existing_user and existing_user[0].user_id != request.user.pk:
            try:
                user = User.objects.get(pk=existing_user[0].user_id)
                logging.user(request, "~BB~FRFailed App.net connect, another user: %s" % user.username)
                return dict(error=("Another user (%s, %s) has "
                                   "already connected with those App.net credentials."
                                   % (user.username, user.email or "no email")))
            except User.DoesNotExist:
                existing_user.delete()
        
        social_services, _ = MSocialServices.objects.get_or_create(user_id=request.user.pk)
        social_services.appdotnet_uid = unicode(adn_userid)
        social_services.appdotnet_access_token = access_token
        social_services.syncing_appdotnet = True
        social_services.save()
        
        # SyncAppdotnetFriends.delay(user_id=request.user.pk)
        # XXX TODO: Remove below and uncomment above. Only for www->dev.
        social_services.sync_appdotnet_friends()
        
        logging.user(request, "~BB~FRFinishing App.net connect")
        return {}
    else:
        # Start the OAuth process
        adn_auth = appdotnet.Appdotnet(**args)
        auth_url = adn_auth.generateAuthUrl()
        logging.user(request, "~BB~FRStarting App.net connect")
        return {'next': auth_url}

@ajax_login_required
def twitter_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting Twitter")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_twitter()
    
    return HttpResponseRedirect(reverse('load-user-friends'))

@ajax_login_required
def facebook_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting Facebook")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_facebook()
    
    return HttpResponseRedirect(reverse('load-user-friends'))
    
@ajax_login_required
def appdotnet_disconnect(request):
    logging.user(request, "~BB~FRDisconnecting App.net")
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    social_services.disconnect_appdotnet()
    
    return HttpResponseRedirect(reverse('load-user-friends'))
    
@ajax_login_required
@json.json_view
def follow_twitter_account(request):
    username = request.POST['username']
    code = 1
    message = "OK"
    
    logging.user(request, "~BB~FR~SKFollowing Twitter: %s" % username)
    
    if username not in ['samuelclay', 'newsblur']:
        return HttpResponseForbidden()
    
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    try:
        api = social_services.twitter_api()
        api.create_friendship(username)
    except tweepy.TweepError, e:
        code = -1
        message = e
        
    return {'code': code, 'message': message}
    
@ajax_login_required
@json.json_view
def unfollow_twitter_account(request):
    username = request.POST['username']
    code = 1
    message = "OK"
    
    logging.user(request, "~BB~FRUnfollowing Twitter: %s" % username)
        
    if username not in ['samuelclay', 'newsblur']:
        return HttpResponseForbidden()
    
    social_services = MSocialServices.objects.get(user_id=request.user.pk)
    try:
        api = social_services.twitter_api()
        api.destroy_friendship(username)
    except tweepy.TweepError, e:
        code = -1
        message = e
    
    return {'code': code, 'message': message}
