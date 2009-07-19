import datetime
import inspect
import logging
import os
import re
import sys
import time
import urlparse

try:
    import pygments
    import pygments.lexers
    import pygments.formatters
    import pygments.styles
except ImportError:
    pygments = None

import django
from django.conf import settings
from django.contrib import admin
from django.db import connection
from django.shortcuts import render_to_response
from django.template import loader
from django.utils.cache import add_never_cache_headers
from django.utils.html import escape
try:
    from django.utils.encoding import smart_str
except ImportError:
    # Older versions of Django don't have smart_str, but because they don't
    # require Unicode, we can simply fake it with an identify function.
    smart_str = lambda s: s
try:
    from django.utils.safestring import mark_safe
except ImportError:
    # Older versions of Django don't have mark_safe, so we have to escape
    # manually when required.
    mark_safe = None
from django.utils.functional import curry

from djangologging import SUPPRESS_OUTPUT_ATTR, getLevelNames
from djangologging.handlers import ThreadBufferedHandler


""" Regex to find the closing head element in a (X)HTML document. """
close_head_re = re.compile("(</head>)", re.M | re.I)

""" Regex to find the closing body element in a (X)HTML document. """
close_body_re = re.compile("(</body>)", re.M | re.I)


# Initialise and register the handler
handler = ThreadBufferedHandler()
logging.root.setLevel(logging.NOTSET)
logging.root.addHandler(handler)

# Because this logging module isn't registered within INSTALLED_APPS, we have
# to use (or work out) an absolute file path to the templates and add it to 
# TEMPLATE_DIRS.
try:
    template_path = settings.LOGGING_TEMPLATE_DIR
except AttributeError:
    template_path = os.path.join(os.path.dirname(__file__), 'templates')
settings.TEMPLATE_DIRS = (template_path,) + tuple(settings.TEMPLATE_DIRS)

try:
    intercept_redirects = settings.LOGGING_INTERCEPT_REDIRECTS
except AttributeError:
    intercept_redirects = False

try:
    logging_output_enabled = settings.LOGGING_OUTPUT_ENABLED
except AttributeError:
    logging_output_enabled = settings.DEBUG

try:
    logging_show_metrics = settings.LOGGING_SHOW_METRICS
except AttributeError:
    logging_show_metrics = True

try:
    logging_show_hints = settings.LOGGING_SHOW_HINTS
except AttributeError:
    logging_show_hints = True

try:
    logging_log_sql = settings.LOGGING_LOG_SQL
except AttributeError:
    logging_log_sql = False

try:
    logging_rewrite_content_types = settings.LOGGING_REWRITE_CONTENT_TYPES
except AttributeError:
    logging_rewrite_content_types = ('text/html',)

_django_path = os.path.realpath(os.path.dirname(django.__file__))
_admin_path = os.path.realpath(os.path.dirname(admin.__file__))
_logging_path = os.path.realpath(os.path.dirname(logging.__file__))
_djangologging_path = os.path.realpath(os.path.dirname(__file__))

def get_meaningful_frame():
    """
    Try to find the meaningful frame, rather than just using one from
    the innards of the Django or logging code.
    """
    frame = inspect.currentframe().f_back
    while frame.f_back:
        filename = os.path.realpath(frame.f_code.co_filename)
        if not (filename.startswith(_django_path) or \
               filename.startswith(_logging_path) or \
               filename.startswith(_djangologging_path)) or \
               filename.startswith(_admin_path):
            break
        frame = frame.f_back
    return frame

if logging_log_sql:
    # Define a new logging level called SQL
    logging.SQL = logging.DEBUG + 1
    logging.addLevelName(logging.SQL, 'SQL')
    
    # Define a custom function for creating log records
    def make_sql_record(frame, original_makeRecord, sqltime, self, *args, **kwargs):
        args = list(args)
        len_args = len(args)
        if len_args > 2:
            args[2] = frame.f_code.co_filename
        else:
            kwargs['fn'] = frame.f_code.co_filename
        if len_args > 3:
            args[3] = frame.f_lineno
        else:
            kwargs['lno'] = frame.f_lineno
        if len_args > 7:
            args[7] = frame.f_code.co_name
        elif 'func' in kwargs:
            kwargs['func'] = frame.f_code.co_name
        rv = original_makeRecord(self, *args, **kwargs)
        rv.__dict__['sqltime'] = '%d' % sqltime
        return rv
    
    class SqlLoggingList(list):
        def append(self, object):
            frame = get_meaningful_frame()

            sqltime = float(object['time']) * 1000

            # Temporarily use make_sql_record for creating log records
            original_makeRecord = logging.Logger.makeRecord
            logging.Logger.makeRecord = curry(make_sql_record, frame, original_makeRecord, sqltime)
            logging.getLogger().log(logging.SQL, object['sql'])
            logging.Logger.makeRecord = original_makeRecord
            list.append(self, object)


_makeRecord = logging.Logger.makeRecord
def enhanced_make_record(self, *args, **kwargs):
    """Enahnced makeRecord that captures the source code and local variables of
    the code logging a message.""" 
    rv = _makeRecord(self, *args, **kwargs)
    frame = get_meaningful_frame()
    
    source_lines = inspect.getsourcelines(frame)
    lineno = frame.f_lineno - source_lines[1]
    show = 5
    start, stop = max(0, lineno - show), lineno + show + 1
    rv.__dict__['source_lines'] = python_to_html(''.join(source_lines[0][start:stop]), source_lines[1] + start, [lineno - start + 1])
    rv.__dict__['local_variables'] = frame.f_locals.items()
    return rv

logging.Logger.makeRecord = enhanced_make_record


_redirect_statuses = {
    301: 'Moved Permanently',
    302: 'Found',
    303: 'See Other',
    307: 'Temporary Redirect'}


def format_time(record):
    time = datetime.datetime.fromtimestamp(record.created)
    return '%s,%03d' % (time.strftime('%H:%M:%S'), record.msecs)

def sql_to_html(sql):
    if pygments:
        try:
            lexer = {
                'mysql': pygments.lexers.MySqlLexer,
                }[settings.DATABASE_ENGINE]
        except KeyError:
            lexer = pygments.lexers.SqlLexer
        html = pygments.highlight(sql, lexer(),
            pygments.formatters.HtmlFormatter(cssclass='sql_highlight'))
        
        # Add some line breaks in appropriate places
        html = html.replace('<span class="k">', '<br /><span class="k">')
        html = re.sub(r'(<pre>\s*)<br />', r'\1', html)
        html = re.sub(r'(<span class="k">[^<>]+</span>\s*)<br />(<span class="k">)', r'\1\2', html)
        html = re.sub(r'<br />(<span class="k">(IN|LIKE)</span>)', r'\1', html)
        
        # Add a space after commas to help with wrapping
        html = re.sub(r'<span class="p">,</span>', '<span class="p">, </span>', html)
    
    else:
        html = '<div class="sql_highlight"><pre>%s</pre></div>' % escape(sql)
    
    if mark_safe:
        html = mark_safe(html)
    return html

def python_to_html(python, linenostart=1, hl_lines=()):
    if pygments:
        html = pygments.highlight(python,
            pygments.lexers.PythonLexer(),
            pygments.formatters.HtmlFormatter(
                linenos='inline', linenostart=linenostart, hl_lines=hl_lines
                ))
    
    else:
        lines = python.split('\n')
        mx = len(str(linenostart + len(lines)))
        python = '\n'.join(['%*d %s' % (mx, i+1, l) for i, l in enumerate(lines)])
        html = '<pre>%s</pre>' % escape(python)
    
    if mark_safe:
        html = mark_safe(html)
    return html
    
        

class LoggingMiddleware(object):
    """
    Middleware that appends the messages logged during the request to the
    response (if the response is HTML).
    """

    def process_request(self, request):
        handler.clear_records()
        if logging_log_sql:
            connection.queries = SqlLoggingList(connection.queries)
        request.logging_start_time = time.time()

    def process_response(self, request, response):

        if logging_output_enabled and \
                request.META.get('REMOTE_ADDR') in settings.INTERNAL_IPS and \
                not getattr(response, SUPPRESS_OUTPUT_ATTR, False):

            if intercept_redirects and \
                    response.status_code in _redirect_statuses and \
                    len(handler.get_records()):
                response = self._handle_redirect(request, response)

            for content_type in logging_rewrite_content_types:
                if response['Content-Type'].startswith(content_type):
                    self._rewrite_html(request, response)
                    add_never_cache_headers(response)
                    break

        return response

    def _get_and_clear_records(self):
            records = handler.get_records()
            handler.clear_records()
            for record in records:
                record.formatted_timestamp = format_time(record)
                message = record.getMessage()
                if record.levelname == 'SQL':
                    record.formatted_message = sql_to_html(message)
                else:
                    record.formatted_message = escape(message)
            return records

    def _rewrite_html(self, request, response):
        if not hasattr(request, 'logging_start_time'):
            return
        hints = {
            'pygments': logging_log_sql and not pygments,
            }
        context = {
            'records': self._get_and_clear_records(),
            'levels': getLevelNames(),
            'elapsed_time': (time.time() - request.logging_start_time) * 1000, # milliseconds
            'query_count': -1,
            'logging_log_sql': logging_log_sql,
            'logging_show_metrics': logging_show_metrics,
            'logging_show_hints': logging_show_hints,
            'hints': dict(filter(lambda (k, v): v, hints.items())),
            }
        if settings.DEBUG and logging_show_metrics:
            context['query_count'] = len(connection.queries)
            if context['query_count'] and context['elapsed_time']:
                context['query_time'] = sum(map(lambda q: float(q['time']) * 1000, connection.queries))
                context['query_percentage'] = context['query_time'] / context['elapsed_time'] * 100

        header = smart_str(loader.render_to_string('logging.css'))
        footer = smart_str(loader.render_to_string('logging.html', context))

        if close_head_re.search(response.content) and close_body_re.search(response.content):
            def safe_prepend(prependant):
                def _prepend(match):
                    return '%s%s' % (prependant, match.group(0)) 
                return _prepend
            response.content = close_head_re.sub(safe_prepend(header), response.content)
            response.content = close_body_re.sub(safe_prepend(footer), response.content)
        else:
            # Despite a Content-Type of text/html, the content doesn't seem to
            # be sensible HTML, so just append the log to the end of the
            # response and hope for the best!
            response.write(footer)

    def _handle_redirect(self, request, response):
        if hasattr(request, 'build_absolute_url'):
            location = request.build_absolute_uri(response['Location'])
        else:
            # Construct the URL manually in older versions of Django
            request_protocol = request.is_secure() and 'https' or 'http'
            request_url = '%s://%s%s' % (request_protocol,
                request.META.get('HTTP_HOST'), request.path)
            location = urlparse.urljoin(request_url, response['Location'])
        data = {
            'location': location,
            'status_code': response.status_code,
            'status_name': _redirect_statuses[response.status_code]}
        response = render_to_response('redirect.html', data)
        add_never_cache_headers(response)
        return response


class SuppressLoggingOnAjaxRequestsMiddleware(object):
    """Suppress and log messages from being outputted to the browser on
    requests that are made from AJAX. This relies on the
    X-Requested-With header being set, which all the most popular libraries
    seem to do."""
    def process_response(self, request, response):
        if request.META.get('HTTP_X_REQUESTED_WITH', '').lower() == 'xmlhttprequest':
            setattr(response, SUPPRESS_OUTPUT_ATTR, True)

        return response