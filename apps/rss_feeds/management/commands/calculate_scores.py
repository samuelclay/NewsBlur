from django.core.management.base import BaseCommand
from apps.reader.models import UserSubscription
from django.conf import settings
from optparse import make_option
from django.contrib.auth.models import User
import os
import errno
import re
import datetime

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option("-a", "--all", dest="all", action="store_true", help="All feeds, need it or not (can be combined with a user)"),
        make_option("-s", "--silent", dest="silent", default=False, action="store_true", help="Inverse verbosity."),
        make_option("-u", "--user", dest="user", nargs=1, help="Specify user id or username"),
        make_option("-d", "--daemon", dest="daemonize", action="store_true"),
        make_option("-D", "--days", dest="days", nargs=1, default=1, type='int'),
        make_option("-O", "--offset", dest="offset", nargs=1, default=0, type='int'),
    )

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
            print " ---> %s has %s feeds (%s/%s)" % (u.username, usersubs.count(), i+1, user_count)
            for sub in usersubs:
                try:
                    sub.calculate_feed_scores(silent=options['silent'])
                except Exception, e:
                    print " ***> Exception: %s" % e
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
    os.umask(077)
    null = os.open("/dev/null", os.O_RDWR)
    for i in range(3):
        try:
            os.dup2(null, i)
        except OSError, e:
            if e.errno != errno.EBADF:
                raise
    os.close(null)