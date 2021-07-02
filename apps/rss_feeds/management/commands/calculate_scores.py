from django.core.management.base import BaseCommand
from apps.reader.models import UserSubscription
from django.conf import settings
from django.contrib.auth.models import User
import os
import errno
import re
import datetime

class Command(BaseCommand):

    def add_arguments(self, parser):
        parser.add_argument("-a", "--all", dest="all", action="store_true", help="All feeds, need it or not (can be combined with a user)"),
        parser.add_argument("-s", "--silent", dest="silent", default=False, action="store_true", help="Inverse verbosity."),
        parser.add_argument("-u", "--user", dest="user", nargs=1, help="Specify user id or username"),
        parser.add_argument("-d", "--daemon", dest="daemonize", action="store_true"),
        parser.add_argument("-D", "--days", dest="days", nargs=1, default=1, type='int'),
        parser.add_argument("-O", "--offset", dest="offset", nargs=1, default=0, type='int'),

    def handle(self, *args, **options):
        settings.LOG_TO_STREAM = True
        if options['daemonize']:
            daemonize()

        if options['user']:
            if re.match(r"([0-9]+)", options['user']):
                users = User.objects.filter(pk=int(options['user']))
            else:
                users = User.objects.filter(username=options['user'])
        else:
            users = User.objects.filter(profile__last_seen_on__gte=datetime.datetime.now()-datetime.timedelta(days=options['days'])).order_by('pk')
        
        user_count = users.count()
        for i, u in enumerate(users):
            if i < options['offset']: continue
            if options['all']:
                usersubs = UserSubscription.objects.filter(user=u, active=True)
            else:
                usersubs = UserSubscription.objects.filter(user=u, needs_unread_recalc=True)
            print((" ---> %s has %s feeds (%s/%s)" % (u.username, usersubs.count(), i+1, user_count)))
            for sub in usersubs:
                try:
                    sub.calculate_feed_scores(silent=options['silent'])
                except Exception as e:
                    print((" ***> Exception: %s" % e))
                    continue
        
def daemonize():
    """
    Detach from the terminal and continue as a daemon.
    """
    # swiped from twisted/scripts/twistd.py
    # See http://www.erlenstar.demon.co.uk/unix/faq_toc.html#TOC16
    if os.fork():   # launch child and...
        os._exit(0) # kill off parent
    os.setsid()
    if os.fork():   # launch child and...
        os._exit(0) # kill off parent again.
    os.umask(0o77)
    null = os.open("/dev/null", os.O_RDWR)
    for i in range(3):
        try:
            os.dup2(null, i)
        except OSError as e:
            if e.errno != errno.EBADF:
                raise
    os.close(null)