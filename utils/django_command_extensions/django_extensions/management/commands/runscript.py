from django.core.management.base import BaseCommand
from django.core.management.color import no_style
from optparse import make_option
import sys
import os

try:
    set
except NameError:
    from sets import Set as set   # Python 2.3 fallback

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option('--fixtures', action='store_true', dest='infixtures', default=False,
            help='Only look in app.fixtures subdir'),
        make_option('--noscripts', action='store_true', dest='noscripts', default=False,
            help='Look in app.scripts subdir'),
    )
    help = 'Runs a script in django context.'
    args = "script [script ...]"

    def handle(self, *scripts, **options):
        from django.db.models import get_apps

        subdirs = []

        if not options.get('noscripts'):
            subdirs.append('scripts')
        if options.get('infixtures'):
            subdirs.append('fixtures')
        verbosity = int(options.get('verbosity', 1))
        show_traceback = options.get('traceback', False)

        if len(subdirs) < 1:
            print "No subdirs to run left."
            return

        if len(scripts) < 1:
            print "Script name required."
            return

        def run_script(name):
            if verbosity > 1:
                print "check for %s" % name
            try:
                t = __import__(name, [], [], [" "])

                if verbosity > 0:
                    print "Found script %s ..." %name
                if hasattr(t, "run"):
                    if verbosity > 1:
                        print "found run() in %s. executing..." % name
                    # TODO: add arguments to run
                    try:
                        t.run()
                    except Exception, e:
                        if verbosity > 0:
                            print "Exception while running run() in %s" %name
                        if show_traceback:
                            raise
                else:
                    if verbosity > 1:
                        print "no run() function found."
                    
            except ImportError:
                pass


        for app in get_apps():
            app_name = app.__name__.split(".")[:-1] # + ['fixtures']

            for subdir in subdirs:
                for script in scripts:
                    run_script(".".join(app_name + [subdir, script]))

        # try app.DIR.script import
        for script in scripts:
            sa = script.split(".")
            for subdir in subdirs:
                nn = ".".join(sa[:-1] + [subdir, sa[-1]])
                run_script(nn)

            # try direct import
            if script.find(".") != -1:
                run_script(script)



# Backwards compatibility for Django r9110
if not [opt for opt in Command.option_list if opt.dest=='verbosity']:
    Command.option_list += (
	make_option('--verbosity', '-v', action="store", dest="verbosity",
	    default='1', type='choice', choices=['0', '1', '2'],
	    help="Verbosity level; 0=minimal output, 1=normal output, 2=all output"),
    )
