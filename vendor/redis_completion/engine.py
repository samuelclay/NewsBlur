try:
    import simplejson as json
except ImportError:
    import json
import re
from redis import Redis

from redis_completion.stop_words import STOP_WORDS as _STOP_WORDS


# aggressive stop words will be better when the length of the document is longer
AGGRESSIVE_STOP_WORDS = _STOP_WORDS

# default stop words should work fine for titles and things like that
DEFAULT_STOP_WORDS = set(['a', 'an', 'of', 'the'])


class RedisEngine(object):
    """
    References
    ----------

    http://antirez.com/post/autocomplete-with-redis.html
    http://stackoverflow.com/questions/1958005/redis-autocomplete/1966188#1966188
    http://patshaughnessy.net/2011/11/29/two-ways-of-using-redis-to-build-a-nosql-autocomplete-search-index
    """
    def __init__(self, prefix='ac', stop_words=None, cache_timeout=300, **conn_kwargs):
        self.prefix = prefix
        self.stop_words = (stop_words is None) and DEFAULT_STOP_WORDS or stop_words

        self.conn_kwargs = conn_kwargs
        self.client = self.get_client()

        self.cache_timeout = cache_timeout

        self.boost_key = '%s:b' % self.prefix
        self.data_key = '%s:d' % self.prefix
        self.title_key = '%s:t' % self.prefix
        self.search_key = lambda k: '%s:s:%s' % (self.prefix, k)
        self.cache_key = lambda pk, bk: '%s:c:%s:%s' % (self.prefix, pk, bk)

        self.kcombine = lambda _id, _type: str(_id)
        self.ksplit = lambda k: k

    def get_client(self):
        return Redis(**self.conn_kwargs)

    def score_key(self, k, max_size=20):
        k_len = len(k)
        a = ord('a') - 2
        score = 0

        for i in range(max_size):
            if i < k_len:
                c = (ord(k[i]) - a)
                if c < 2 or c > 27:
                    c = 1
            else:
                c = 1
            score += c*(27**(max_size-i))
        return score

    def clean_phrase(self, phrase):
        phrase = re.sub('[^a-z0-9_\-\s]', '', phrase.lower())
        return [w for w in phrase.split() if w not in self.stop_words]

    def create_key(self, phrase):
        return ' '.join(self.clean_phrase(phrase))

    def autocomplete_keys(self, w):
        for i in range(1, len(w)):
            yield w[:i]
        yield w

    def flush(self, everything=False, batch_size=1000):
        if everything:
            return self.client.flushdb()

        # this could be expensive :-(
        keys = self.client.keys('%s:*' % self.prefix)

        # batch keys
        for i in range(0, len(keys), batch_size):
            self.client.delete(*keys[i:i+batch_size])

    def store(self, obj_id, title=None, data=None, obj_type=None, check_exist=True):
        if title is None:
            title = obj_id
        if data is None:
            data = title

        title_score = self.score_key(self.create_key(title))

        combined_id = self.kcombine(obj_id, obj_type or '')

        if check_exist and self.exists(obj_id, obj_type):
            stored_title = self.client.hget(self.title_key, combined_id)

            # if the stored title is the same, we can simply update the data key
            # since everything else will have stayed the same
            if stored_title == title:
                self.client.hset(self.data_key, combined_id, data)
                return
            else:
                self.remove(obj_id, obj_type)

        pipe = self.client.pipeline()
        pipe.hset(self.data_key, combined_id, data)
        pipe.hset(self.title_key, combined_id, title)

        for word in self.clean_phrase(title):
            for partial_key in self.autocomplete_keys(word):
                pipe.zadd(self.search_key(partial_key), combined_id, title_score)

        pipe.execute()

    def store_json(self, obj_id, title, data_dict, obj_type=None):
        return self.store(obj_id, title, json.dumps(data_dict), obj_type)

    def remove(self, obj_id, obj_type=None):
        obj_id = self.kcombine(obj_id, obj_type or '')
        title = self.client.hget(self.title_key, obj_id) or ''
        keys = []

        for word in self.clean_phrase(title):
            for partial_key in self.autocomplete_keys(word):
                key = self.search_key(partial_key)
                if not self.client.zrange(key, 1, 2):
                    self.client.delete(key)
                else:
                    self.client.zrem(key, obj_id)

        self.client.hdel(self.data_key, obj_id)
        self.client.hdel(self.title_key, obj_id)
        self.client.hdel(self.boost_key, obj_id)

    def boost(self, obj_id, multiplier=1.1, negative=False):
        # take the existing boost for this item and increase it by the multiplier
        current = self.client.hget(self.boost_key, obj_id)
        current_f = float(current or 1.0)
        if negative:
            multiplier = 1 / multiplier
        self.client.hset(self.boost_key, obj_id, current_f * multiplier)

    def exists(self, obj_id, obj_type=None):
        obj_id = self.kcombine(obj_id, obj_type or '')
        return self.client.hexists(self.data_key, obj_id)

    def get_cache_key(self, phrases, boosts):
        if boosts:
            boost_key = '|'.join('%s:%s' % (k, v) for k, v in sorted(boosts.items()))
        else:
            boost_key = ''
        phrase_key = '|'.join(phrases)
        return self.cache_key(phrase_key, boost_key)

    def _process_ids(self, id_list, limit, filters, mappers):
        ct = 0
        data = []

        for raw_id in id_list:
            # raw_data = self.client.hget(self.data_key, raw_id)
            raw_data = raw_id
            if not raw_data:
                continue

            if mappers:
                for m in mappers:
                    raw_data = m(raw_data)

            if filters:
                passes = True
                for f in filters:
                    if not f(raw_data):
                        passes = False
                        break

                if not passes:
                    continue

            data.append(raw_data)
            ct += 1
            if limit and ct == limit:
                break

        return data

    def search(self, phrase, limit=None, filters=None, mappers=None, boosts=None, autoboost=False):
        cleaned = self.clean_phrase(phrase)
        if not cleaned:
            return []

        if autoboost:
            boosts = boosts or {}
            stored = self.client.hgetall(self.boost_key)
            for obj_id in stored:
                if obj_id not in boosts:
                    boosts[obj_id] = float(stored[obj_id])

        if len(cleaned) == 1 and not boosts:
            new_key = self.search_key(cleaned[0])
        else:
            new_key = self.get_cache_key(cleaned, boosts)
            if not self.client.exists(new_key):
                # zinterstore also takes {k1: wt1, k2: wt2}
                self.client.zinterstore(new_key, map(self.search_key, cleaned))
                self.client.expire(new_key, self.cache_timeout)

        if boosts:
            pipe = self.client.pipeline()
            for raw_id, score in self.client.zrange(new_key, 0, -1, withscores=True):
                orig_score = score
                for part in self.ksplit(raw_id):
                    if part and part in boosts:
                        score *= 1 / boosts[part]
                if orig_score != score:
                    pipe.zadd(new_key, raw_id, score)
            pipe.execute()

        id_list = self.client.zrange(new_key, 0, -1)
        # return id_list
        return self._process_ids(id_list, limit, filters, mappers)

    def search_json(self, phrase, limit=None, filters=None, mappers=None, boosts=None, autoboost=False):
        if not mappers:
            mappers = []
        mappers.insert(0, json.loads)
        return self.search(phrase, limit, filters, mappers, boosts, autoboost)
