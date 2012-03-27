import urllib
import urllib2

class StatHat:

        def http_post(self, path, data):
                pdata = urllib.urlencode(data)
                req = urllib2.Request('http://api.stathat.com' + path, pdata)
                resp = urllib2.urlopen(req)
                return resp.read()

        def post_value(self, user_key, stat_key, value):
                return self.http_post('/v', {'key': stat_key, 'ukey': user_key, 'value': value})

        def post_count(self, user_key, stat_key, count):
                return self.http_post('/c', {'key': stat_key, 'ukey': user_key, 'count': count})

        def ez_post_value(self, email, stat_name, value):
                return self.http_post('/ez', {'email': email, 'stat': stat_name, 'value': value})

        def ez_post_count(self, email, stat_name, count):
                return self.http_post('/ez', {'email': email, 'stat': stat_name, 'count': count})

