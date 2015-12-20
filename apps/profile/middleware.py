import datetime
import re
import random
import time
import redis
from utils import log as logging
from django.http import HttpResponse
from django.conf import settings
from django.db import connection
from django.template import Template, Context
from apps.statistics.rstats import round_time
from utils import json_functions as json

class LastSeenMiddleware(object):
    def process_response(self, request, response):
        if ((request.path == '/' or
             request.path.startswith('/reader/refresh_feeds') or
             request.path.startswith('/reader/load_feeds') or
             request.path.startswith('/reader/feeds'))
            and hasattr(request, 'user')
            and request.user.is_authenticated()): 
            hour_ago = datetime.datetime.utcnow() - datetime.timedelta(minutes=60)
            ip = request.META.get('HTTP_X_FORWARDED_FOR', None) or request.META['REMOTE_ADDR']
            # SUBSCRIBER_EXPIRE = datetime.datetime.utcnow() - datetime.timedelta(days=settings.SUBSCRIBER_EXPIRE)
            if request.user.profile.last_seen_on < hour_ago:
                logging.user(request, "~FG~BBRepeat visitor: ~SB%s (%s)" % (
                    request.user.profile.last_seen_on, ip))
                from apps.profile.tasks import CleanupUser
                CleanupUser.delay(user_id=request.user.pk)
            elif settings.DEBUG:
                logging.user(request, "~FG~BBRepeat visitor (ignored): ~SB%s (%s)" % (
                    request.user.profile.last_seen_on, ip))

            request.user.profile.last_seen_on = datetime.datetime.utcnow()
            request.user.profile.last_seen_ip = ip[-15:]
            request.user.profile.save()
        
        return response
        
class DBProfilerMiddleware:
    def process_request(self, request): 
        setattr(request, 'activated_segments', [])
        if ((request.path.startswith('/reader/feed') or
             request.path.startswith('/reader/river')) and
            random.random() < .01):
            request.activated_segments.append('db_profiler')
            connection.use_debug_cursor = True

    def process_celery(self): 
        setattr(self, 'activated_segments', [])        
        if random.random() < .01:
            self.activated_segments.append('db_profiler')
            connection.use_debug_cursor = True
            return self
    
    def process_exception(self, request, exception):
        if hasattr(request, 'sql_times_elapsed'):
            self._save_times(request.sql_times_elapsed)

    def process_response(self, request, response):
        if hasattr(request, 'sql_times_elapsed'):
            self._save_times(request.sql_times_elapsed)
        return response
    
    def process_celery_finished(self):
        middleware = SQLLogToConsoleMiddleware()
        middleware.process_celery(self)
        if hasattr(self, 'sql_times_elapsed'):
            logging.debug(" ---> ~FGProfiling~FB task: %s" % self.sql_times_elapsed)
            self._save_times(self.sql_times_elapsed, 'task_')
    
    def _save_times(self, db_times, prefix=""):
        if not db_times: return
        
        r = redis.Redis(connection_pool=settings.REDIS_STATISTICS_POOL)
        pipe = r.pipeline()
        minute = round_time(round_to=60)
        for db, duration in db_times.items():
            key = "DB:%s%s:%s" % (prefix, db, minute.strftime('%s'))
            pipe.incr("%s:c" % key)
            pipe.expireat("%s:c" % key, (minute + datetime.timedelta(days=2)).strftime("%s"))
            if duration:
                pipe.incrbyfloat("%s:t" % key, duration)
                pipe.expireat("%s:t" % key, (minute + datetime.timedelta(days=2)).strftime("%s"))
        pipe.execute()


class SQLLogToConsoleMiddleware:
    def activated(self, request):
        return (settings.DEBUG_QUERIES or 
                (hasattr(request, 'activated_segments') and
                 'db_profiler' in request.activated_segments))

    def process_response(self, request, response): 
        if not self.activated(request): return response
        if connection.queries:
            time_elapsed = sum([float(q['time']) for q in connection.queries])
            queries = connection.queries
            for query in queries:
                if query.get('mongo'):
                    query['sql'] = "~FM%s: %s" % (query['mongo']['collection'], query['mongo']['query'])
                elif query.get('redis'):
                    query['sql'] = "~FC%s" % (query['redis']['query'])
                else:
                    query['sql'] = re.sub(r'SELECT (.*?) FROM', 'SELECT * FROM', query['sql'])
                    query['sql'] = re.sub(r'SELECT', '~FYSELECT', query['sql'])
                    query['sql'] = re.sub(r'INSERT', '~FGINSERT', query['sql'])
                    query['sql'] = re.sub(r'UPDATE', '~FY~SBUPDATE', query['sql'])
                    query['sql'] = re.sub(r'DELETE', '~FR~SBDELETE', query['sql'])
            t = Template("{% for sql in sqllog %}{% if not forloop.first %}                  {% endif %}[{{forloop.counter}}] ~FC{{sql.time}}s~FW: {{sql.sql|safe}}{% if not forloop.last %}\n{% endif %}{% endfor %}")
            if settings.DEBUG:
                logging.debug(t.render(Context({
                    'sqllog': queries,
                    'count': len(queries),
                    'time': time_elapsed,
                })))
            times_elapsed = {
                'sql': sum([float(q['time']) 
                           for q in queries if not q.get('mongo') and 
                                               not q.get('redis')]),
                'mongo': sum([float(q['time']) for q in queries if q.get('mongo')]),
                'redis': sum([float(q['time']) for q in queries if q.get('redis')]),
            }
            setattr(request, 'sql_times_elapsed', times_elapsed)
        return response
        
    def process_celery(self, profiler):
        self.process_response(profiler, None)

SIMPSONS_QUOTES = [
    ("Homer", "D'oh."),
    ("Ralph", "Me fail English? That's unpossible."),
    ("Lionel Hutz", "This is the greatest case of false advertising I've seen since I sued the movie \"The Never Ending Story.\""),
    ("Sideshow Bob", "No children have ever meddled with the Republican Party and lived to tell about it."),
    ("Troy McClure", "Don't kid yourself, Jimmy. If a cow ever got the chance, he'd eat you and everyone you care about!"),
    ("Comic Book Guy", "The Internet King? I wonder if he could provide faster nudity..."),
    ("Homer", "Oh, so they have Internet on computers now!"),
    ("Ned Flanders", "I've done everything the Bible says - even the stuff that contradicts the other stuff!"),
    ("Comic Book Guy", "Your questions have become more redundant and annoying than the last three \"Highlander\" movies."),
    ("Chief Wiggum", "Uh, no, you got the wrong number. This is 9-1...2."),
    ("Sideshow Bob", "I'll be back. You can't keep the Democrats out of the White House forever, and when they get in, I'm back on the streets, with all my criminal buddies."),
    ("Homer", "When I held that gun in my hand, I felt a surge of power...like God must feel when he's holding a gun."),
    ("Nelson", "Dad didn't leave... When he comes back from the store, he's going to wave those pop-tarts right in your face!"),
    ("Milhouse", "Remember the time he ate my goldfish? And you lied and said I never had goldfish. Then why did I have the bowl, Bart? *Why did I have the bowl?*"),
    ("Lionel Hutz", "Well, he's kind of had it in for me ever since I accidentally ran over his dog. Actually, replace \"accidentally\" with \"repeatedly\" and replace \"dog\" with \"son.\""),
    ("Comic Book Guy", "Last night's \"Itchy and Scratchy Show\" was, without a doubt, the worst episode *ever.* Rest assured, I was on the Internet within minutes, registering my disgust throughout the world."),
    ("Homer", "I'm normally not a praying man, but if you're up there, please save me, Superman."),
    ("Homer", "Save me, Jeebus."),
    ("Mayor Quimby", "I stand by my racial slur."),
    ("Comic Book Guy", "Oh, loneliness and cheeseburgers are a dangerous mix."),
    ("Homer", "You don't like your job, you don't strike. You go in every day and do it really half-assed. That's the American way."),
    ("Chief Wiggum", "Fat Tony is a cancer on this fair city! He is the cancer and I am the...uh...what cures cancer?"),
    ("Homer", "Bart, with $10,000 we'd be millionaires! We could buy all kinds of useful things like...love!"),
    ("Homer", "Fame was like a drug. But what was even more like a drug were the drugs."),
    ("Homer", "Books are useless! I only ever read one book, \"To Kill A Mockingbird,\" and it gave me absolutely no insight on how to kill mockingbirds! Sure it taught me not to judge a man by the color of his skin...but what good does *that* do me?"),
    ("Chief Wiggum", "Can't you people take the law into your own hands? I mean, we can't be policing the entire city!"),
    ("Homer", "Weaseling out of things is important to learn. It's what separates us from the animals...except the weasel."),
    ("Reverend Lovejoy", "Marge, just about everything's a sin. [holds up a Bible] Y'ever sat down and read this thing? Technically we're not supposed to go to the bathroom."),
    ("Homer", "You know, the one with all the well meaning rules that don't work out in real life, uh, Christianity."),
    ("Smithers", "Uh, no, they're saying \"Boo-urns, Boo-urns.\""),
    ("Hans Moleman", "I was saying \"Boo-urns.\""),
    ("Homer", "Kids, you tried your best and you failed miserably. The lesson is, never try."),
    ("Homer", "Here's to alcohol, the cause of - and solution to - all life's problems."),
    ("Homer", "When will I learn? The answers to life's problems aren't at the bottom of a bottle, they're on TV!"),
    ("Chief Wiggum", "I hope this has taught you kids a lesson: kids never learn."),
    ("Homer", "How is education supposed to make me feel smarter? Besides, every time I learn something new, it pushes some old stuff out of my brain. Remember when I took that home winemaking course, and I forgot how to drive?"),
    ("Homer", "Homer no function beer well without."),
    ("Duffman", "Duffman can't breathe! OH NO!"),
    ("Grandpa Simpson", "Dear Mr. President, There are too many states nowadays. Please, eliminate three. P.S. I am not a crackpot."),
    ("Homer", "Old people don't need companionship. They need to be isolated and studied so it can be determined what nutrients they have that might be extracted for our personal use."),
    ("Troy McClure", "Hi. I'm Troy McClure. You may remember me from such self-help tapes as \"Smoke Yourself Thin\" and \"Get Some Confidence, Stupid!\""),
    ("Homer", "A woman is a lot like a refrigerator. Six feet tall, 300 pounds...it makes ice."),
    ("Homer", "Son, a woman is like a beer. They smell good, they look good, you'd step over your own mother just to get one! But you can't stop at one. You wanna drink another woman!"),
    ("Homer", "Facts are meaningless. You could use facts to prove anything that's even remotely true!"),
    ("Mr Burns", "I'll keep it short and sweet - Family. Religion. Friendship. These are the three demons you must slay if you wish to succeed in business."),
    ("Kent Brockman", "...And the fluffy kitten played with that ball of string all through the night. On a lighter note, a Kwik-E-Mart clerk was brutally murdered last night."),
    ("Ralph", "Mrs. Krabappel and Principal Skinner were in the closet making babies and I saw one of the babies and then the baby looked at me."),
    ("Apu", "Please do not offer my god a peanut."),
    ("Homer", "You don't win friends with salad."),
    ("Mr Burns", "I don't like being outdoors, Smithers. For one thing, there's too many fat children."),
    ("Sideshow Bob", "Attempted murder? Now honestly, what is that? Do they give a Nobel Prize for attempted chemistry?"),
    ("Chief Wiggum", "They only come out in the night. Or in this case, the day."),
    ("Mr Burns", "Whoa, slow down there, maestro. There's a *New* Mexico?"),
    ("Homer", "He didn't give you gay, did he? Did he?!"),
    ("Comic Book Guy", "But, Aquaman, you cannot marry a woman without gills. You're from two different worlds... Oh, I've wasted my life."),
    ("Homer", "Marge, it takes two to lie. One to lie and one to listen."),
    ("Superintendent Chalmers", "I've had it with this school, Skinner. Low test scores, class after class of ugly, ugly children..."),
    ("Mr Burns", "What good is money if it can't inspire terror in your fellow man?"),
    ("Homer", "Oh, everything looks bad if you remember it."),
    ("Ralph", "Slow down, Bart! My legs don't know how to be as long as yours."),
    ("Homer", "Donuts. Is there anything they can't do?"),
    ("Frink", "Brace yourselves gentlemen. According to the gas chromatograph, the secret ingredient is... Love!? Who's been screwing with this thing?"),
    ("Apu", "Yes! I am a citizen! Now which way to the welfare office? I'm kidding, I'm kidding. I work, I work."),
    ("Milhouse", "We started out like Romeo and Juliet, but it ended up in tragedy."),
    ("Mr Burns", "A lifetime of working with nuclear power has left me with a healthy green glow...and left me as impotent as a Nevada boxing commissioner."),
    ("Homer", "Kids, kids. I'm not going to die. That only happens to bad people."),
    ("Milhouse", "Look out, Itchy! He's Irish!"),
    ("Homer", "I'm going to the back seat of my car, with the woman I love, and I won't be back for ten minutes!"),
    ("Smithers", "I'm allergic to bee stings. They cause me to, uh, die."),
    ("Barney", "Aaah! Natural light! Get it off me! Get it off me!"),
    ("Principal Skinner", "That's why I love elementary school, Edna. The children believe anything you tell them."),
    ("Sideshow Bob", "Your guilty consciences may make you vote Democratic, but secretly you all yearn for a Republican president to lower taxes, brutalize criminals, and rule you like a king!"),
    ("Barney", "Jesus must be spinning in his grave!"),
    ("Superintendent Chalmers", "\"Thank the Lord\"? That sounded like a prayer. A prayer in a public school. God has no place within these walls, just like facts don't have a place within an organized religion."),
    ("Mr Burns", "[answering the phone] Ahoy hoy?"),
    ("Comic Book Guy", "Oh, a *sarcasm* detector. Oh, that's a *really* useful invention!"),
    ("Marge", "Our differences are only skin deep, but our sames go down to the bone."),
    ("Homer", "What's the point of going out? We're just going to wind up back here anyway."),
    ("Marge", "Get ready, skanks! It's time for the truth train!"),
    ("Bill Gates", "I didn't get rich by signing checks."),
    ("Principal Skinner", "Fire can be our friend; whether it's toasting marshmallows or raining down on Charlie."),
    ("Homer", "Oh, I'm in no condition to drive. Wait a minute. I don't have to listen to myself. I'm drunk."),
    ("Homer", "And here I am using my own lungs like a sucker."),
    ("Comic Book Guy", "Human contact: the final frontier."),
    ("Homer", "I hope I didn't brain my damage."),
    ("Krusty the Clown", "And now, in the spirit of the season: start shopping. And for every dollar of Krusty merchandise you buy, I will be nice to a sick kid. For legal purposes, sick kids may include hookers with a cold."),
    ("Homer", "I'm a Spalding Gray in a Rick Dees world."),
    ("Dr Nick", "Inflammable means flammable? What a country."),
    ("Homer", "Beer. Now there's a temporary solution."),
    ("Comic Book Guy", "Stan Lee never left. I'm afraid his mind is no longer in mint condition."),
    ("Nelson", "Shoplifting is a victimless crime. Like punching someone in the dark."),
    ("Krusty the Clown", "Kids, we need to talk for a moment about Krusty Brand Chew Goo Gum Like Substance. We all knew it contained spider eggs, but the hantavirus? That came out of left field. So if you're experiencing numbness and/or comas, send five dollars to antidote, PO box..."),
    ("Milhouse", "I can't go to juvie. They use guys like me as currency."),
    ("Homer", "Son, when you participate in sporting events, it's not whether you win or lose: it's how drunk you get."),
    ("Homer", "I like my beer cold, my TV loud and my homosexuals flaming."),
    ("Apu", "Thank you, steal again."),
    ("Homer", "Marge, you being a cop makes you the man! Which makes me the woman - and I have no interest in that, besides occasionally wearing the underwear, which as we discussed, is strictly a comfort thing."),
    ("Ed Begley Jr", "I prefer a vehicle that doesn't hurt Mother Earth. It's a go-cart, powered by my own sense of self-satisfaction."),
    ("Bart", "I didn't think it was physically possible, but this both sucks *and* blows."),
    ("Homer", "How could you?! Haven't you learned anything from that guy who gives those sermons at church? Captain Whatshisname? We live in a society of laws! Why do you think I took you to all those Police Academy movies? For fun? Well, I didn't hear anybody laughing, did you? Except at that guy who made sound effects. Makes sound effects and laughs. Where was I? Oh yeah! Stay out of my booze."),
    ("Homer", "Lisa, vampires are make-believe, like elves, gremlins, and Eskimos."),
]

class SimpsonsMiddleware:
    def process_response(self, request, response):
        quote = random.choice(SIMPSONS_QUOTES)
        source = quote[0].replace(' ', '-')
        response["X-%s" % source] = quote[1]

        return response
        
class ServerHostnameMiddleware:
    def process_response(self, request, response):
        response["X-gunicorn-server"] = settings.SERVER_NAME

        return response

class TimingMiddleware:
    def process_request(self, request):
        setattr(request, 'start_time', time.time())

BANNED_USER_AGENTS = (
    'feed reader-background',
    'missing',
)

class UserAgentBanMiddleware:
    def process_request(self, request):
        user_agent = request.environ.get('HTTP_USER_AGENT', 'missing').lower()
        
        if 'profile' in request.path: return
        if 'haproxy' in request.path: return
        if 'dbcheck' in request.path: return
        if 'account' in request.path: return
        if 'push' in request.path: return
        if getattr(settings, 'TEST_DEBUG'): return
        
        if any(ua in user_agent for ua in BANNED_USER_AGENTS):
            data = {
                'error': 'User agent banned: %s' % user_agent,
                'code': -1
            }
            logging.user(request, "~FB~SN~BBBanned UA: ~SB%s / %s (%s)" % (user_agent, request.path, request.META))
            
            return HttpResponse(json.encode(data), status=403, mimetype='text/json')

