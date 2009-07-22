from django.core.management.base import BaseCommand, CommandError
from optparse import make_option
import os
import sys

def null_technical_500_response(request, exc_type, exc_value, tb):
    raise exc_type, exc_value, tb

class Command(BaseCommand):
    option_list = BaseCommand.option_list + (
        make_option('--noreload', action='store_false', dest='use_reloader', default=True,
            help='Tells Django to NOT use the auto-reloader.'),
        make_option('--browser', action='store_true', dest='open_browser',
            help='Tells Django to open a browser.'),
        make_option('--adminmedia', dest='admin_media_path', default='',
            help='Specifies the directory from which to serve admin media.'),
    )
    help = "Starts a lightweight Web server for development."
    args = '[optional port number, or ipaddr:port]'

    # Validation is called explicitly each time the server is reloaded.
    requires_model_validation = False

    def handle(self, addrport='', *args, **options):
        import django
        from django.core.servers.basehttp import run, AdminMediaHandler, WSGIServerException
        from django.core.handlers.wsgi import WSGIHandler
        try:
            from werkzeug import run_simple, DebuggedApplication
        except:
            raise CommandError("Werkzeug is required to use runserver_plus.  Please visit http://werkzeug.pocoo.org/download")

        # usurp django's handler
        from django.views import debug
        debug.technical_500_response = null_technical_500_response

        if args:
            raise CommandError('Usage is runserver %s' % self.args)
        if not addrport:
            addr = ''
            port = '8000'
        else:
            try:
                addr, port = addrport.split(':')
            except ValueError:
                addr, port = '', addrport
        if not addr:
            addr = '127.0.0.1'

        if not port.isdigit():
            raise CommandError("%r is not a valid port number." % port)

        use_reloader = options.get('use_reloader', True)
        open_browser = options.get('open_browser', False)
        admin_media_path = options.get('admin_media_path', '')
        shutdown_message = options.get('shutdown_message', '')
        quit_command = (sys.platform == 'win32') and 'CTRL-BREAK' or 'CONTROL-C'

        def inner_run():
            from django.conf import settings
            print "Validating models..."
            self.validate(display_num_errors=True)
            print "\nDjango version %s, using settings %r" % (django.get_version(), settings.SETTINGS_MODULE)
            print "Development server is running at http://%s:%s/" % (addr, port)
            print "Using the Werkzeug debugger (http://werkzeug.pocoo.org/)"
            print "Quit the server with %s." % quit_command
            path = admin_media_path or django.__path__[0] + '/contrib/admin/media'
            handler = AdminMediaHandler(WSGIHandler(), path)
            if open_browser:
                import webbrowser
                url = "http://%s:%s/" % (addr, port)
                webbrowser.open(url)
            run_simple(addr, int(port), DebuggedApplication(handler, True), 
                       use_reloader=use_reloader, use_debugger=True)            
        inner_run()
