import json
import requests

# To add
# - Identity Delegation
# - Streams (in dev by app.net)
# - Filters (in dev by app.net)

class Appdotnet:
    ''' Once access has been given, you don't have to pass through the
    client_id, client_secret, redirect_uri, or scope. These are just
    to get the authentication token.

    Once authenticated, you can initialise appdotnet with only the
    access token: ie

    api = Appdotnet(access_token='<insert token here>')
    '''

    def __init__(self, client_id=None, client_secret=None, redirect_uri=None,
                 scope=None, access_token=None):
        #for server authentication flow
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.scope = scope

        self.access_token = access_token

        self.api_anchor = "alpha.app.net" #for when the versions change
        #anchors currently different
        self.public_api_anchor = "alpha-api.app.net"

        #scopes provided by app.net API
        self.allowed_scopes = ['stream', 'email', 'write_post',
                               'follow', 'messages','export']

    def generateAuthUrl(self):
        url = "https://" + self.api_anchor + "/oauth/authenticate?client_id="+\
                self.client_id + "&response_type=code&adnview=appstore&redirect_uri=" +\
                self.redirect_uri + "&scope="

        for scope in self.scope:
            if scope in self.allowed_scopes:
                url += scope + " "

        return url

    def getAuthResponse(self, code):
        #generate POST request
        url = "https://alpha.app.net/oauth/access_token"
        post_data = {'client_id':self.client_id,
        'client_secret':self.client_secret,
        'grant_type':'authorization_code',
        'redirect_uri':self.redirect_uri,
        'code':code}

        r = requests.post(url,data=post_data)

        return r.text

    '''
    API Calls
    '''

    #GET REQUESTS
    def getRequest(self, url, getParameters=None):
        if not getParameters:
            getParameters = {}
        #access token
        url = url + "?access_token=" + self.access_token

        #if there are any extra get parameters aside from the access_token, append to the url
        if getParameters != {}:
            for key, value in getParameters.iteritems():
                if not value: continue
                url = url + "&" + key + "=" + unicode(value)
        print url
        r = requests.get(url)
        if r.status_code == requests.codes.ok:
            return r.text
        else:
            j = json.loads(r.text)
            resp = {'error_code': r.status_code,
                        'message' : j['error']['message']}
            return json.dumps(resp)


    def getUser(self, user_id):
        url = "https://%s/stream/0/users/%s" % (self.public_api_anchor,
                                                user_id)
        return self.getRequest(url)

    def getUserPosts(self, user_id):
        url = "https://%s/stream/0/users/%s/posts" % (self.public_api_anchor,
                                                      user_id)
        return self.getRequest(url)

    def getUserStars(self, user_id):
        url = "https://%s/stream/0/users/%s/stars" % (self.public_api_anchor,
                                                      user_id)
        return self.getRequest(url)

    def getGlobalStream(self):
        url = "https://%s/stream/0/posts/stream/global" % self.public_api_anchor
        return self.getRequest(url)

    def getUserStream(self):
        url = "https://%s/stream/0/posts/stream" % self.public_api_anchor
        return self.getRequest(url)

    def getUserMentions(self, user_id):
        url = "https://%s/stream/0/users/%s/mentions" % (self.public_api_anchor,user_id)
        return self.getRequest(url)

    def getPost(self, post_id):
        url = "https://%s/stream/0/posts/%s" % (self.public_api_anchor,post_id)
        return self.getRequest(url)

    def getReposters(self, post_id):
        url ="https://%s/stream/0/posts/%s/reposters" % (self.public_api_anchor,post_id)
        return self.getRequest(url)

    def getStars(self, post_id):
        url ="https://%s/stream/0/posts/%s/stars" % (self.public_api_anchor,post_id)
        return self.getRequest(url)

    def getPostReplies(self, post_id):
        url = "https://%s/stream/0/posts/%s/replies" % (self.public_api_anchor,post_id)
        return self.getRequest(url)

    def getPostsByTag(self, tag):
        url = "https://%s/stream/0/posts/tag/%s" % (self.public_api_anchor, tag)
        return self.getRequest(url)

    def getUserFollowing(self, user_id, since_id=None, before_id=None):
        url = "https://%s/stream/0/users/%s/following" % (self.public_api_anchor, user_id)
        return self.getRequest(url, getParameters={
            'since_id': since_id,
            'before_id': before_id,
        })

    def getUserFollowingIds(self, user_id, since_id=None, before_id=None):
        url = "https://%s/stream/0/users/%s/following/ids" % (self.public_api_anchor, user_id)
        return self.getRequest(url, getParameters={
            'since_id': since_id,
            'before_id': before_id,
        })

    def getUserFollowers(self, user_id):
        url = "https://%s/stream/0/users/%s/followers" % (self.public_api_anchor, user_id)
        return self.getRequest(url)

    def getMutedUsers(self):
        url = "https://%s/stream/0/users/me/muted" % self.public_api_anchor
        return self.getRequest(url)

    def searchUsers(self,q):
        url = "https://%s/stream/0/users/search" % (self.public_api_anchor)
        return self.getRequest(url,getParameters={'q':q})

    def getCurrentToken(self):
        url = "https://%s/stream/0/token" % self.public_api_anchor
        return self.getRequest(url)

    #POST REQUESTS
    def postRequest(self, url, data=None, headers=None):
        if not data:
            data = {}

        if not headers:
            headers = {}

        headers['Authorization'] = 'Bearer %s' % self.access_token
        url = url
        r  = requests.post(url,data=json.dumps(data),headers=headers)
        if r.status_code == requests.codes.ok:
            return r.text
        else:
            try:
                j = json.loads(r.text)
                resp = {'error_code': r.status_code,
                            'message' : j['error']['message']}
                return resp
            except: #generic error
                print r.text
                return "{'error':'There was an error'}"


    def followUser(self,user_id):
        url = "https://%s/stream/0/users/%s/follow" % (self.public_api_anchor, user_id)
        return self.postRequest(url)

    def repostPost(self,post_id):
        url = "https://%s/stream/0/posts/%s/repost" % (self.public_api_anchor, post_id)
        return self.postRequest(url)

    def starPost(self,post_id):
        url = "https://%s/stream/0/posts/%s/star" % (self.public_api_anchor, post_id)
        return self.postRequest(url)

    def muteUser(self,user_id):
        url = "https://%s/stream/0/users/%s/mute" % (self.public_api_anchor, user_id)
        return self.postRequest(url)

    #requires: text
    #optional: reply_to, annotations, links
    def createPost(self, text, reply_to = None, annotations=None, links=None):
        url = "https://%s/stream/0/posts" % self.public_api_anchor
        if annotations != None:
            url = url + "?include_annotations=1"

        data = {'text':text}
        if reply_to != None:
            data['reply_to'] = reply_to
        if annotations != None:
            data['annotations'] = annotations
        if links != None:
            data['links'] = links

        return self.postRequest(url,data,headers={'content-type':'application/json'})

    #DELETE request
    def deleteRequest(self, url):
        url = url + "?access_token=" + self.access_token
        r = requests.delete(url)
        if r.status_code == requests.codes.ok:
            return r.text
        else:
            try:
                j = json.loads(r.text)
                resp = {'error_code': r.status_code,
                            'message' : j['error']['message']}
                return resp
            except: #generic error
                print r.text
                return "{'error':'There was an error'}"

    def deletePost(self, post_id):
        url = "https://%s/stream/0/posts/%s" % (self.public_api_anchor,post_id)
        return self.deleteRequest(url)

    def unrepostPost(self, post_id):
        url = "https://%s/stream/0/posts/%s/repost" % (self.public_api_anchor,post_id)
        return self.deleteRequest(url)

    def unstarPost(self, post_id):
        url = "https://%s/stream/0/posts/%s/star" % (self.public_api_anchor,post_id)
        return self.deleteRequest(url)

    def unfollowUser(self, user_id):
        url = "https://%s/stream/0/users/%s/follow" % (self.public_api_anchor,user_id)
        return self.deleteRequest(url)

    def unmuteUser(self, user_id):
        url = "https://%s/stream/0/users/%s/mute" % (self.public_api_anchor,user_id)
        return self.deleteRequest(url)
