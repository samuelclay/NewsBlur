#!/usr/bin/env python
from config import *

import cgi, sys, os, urlparse, sys, re, urllib
import cgitb
cgitb.enable()

import codecs
ENCODING='UTF-8'
sys.stdout = codecs.getwriter(ENCODING)(sys.stdout)

# Used for CGI parameters
decUTF8 = codecs.getdecoder('utf-8')
decW1252 = codecs.getdecoder('windows-1252')

if PYDIR not in sys.path:
    sys.path.insert(0, PYDIR)

if WEBDIR not in sys.path:
    sys.path.insert(0, WEBDIR)

if SRCDIR not in sys.path:
    sys.path.insert(0, SRCDIR)
import feedvalidator
from feedvalidator.logging import FEEDTYPEDISPLAY, VALIDFEEDGRAPHIC

from feedvalidator.logging import Info, Warning, Error, ValidationFailure
from feedvalidator.logging import TYPE_ATOM_ENTRY, TYPE_OPENSEARCH, TYPE_XRD

def applyTemplate(templateFile, params={}):
    params['CSSURL'] = CSSURL
    fsock = open(os.path.join(WEBDIR, 'templates', templateFile))
    data = fsock.read() % params
    fsock.close()
    return data.encode('utf-8')

def sanitizeURL(url):
    # Allow feed: URIs, as described by draft-obasanjo-feed-URI-scheme-02
    if url.lower().startswith('feed:'):
      url = url[5:]
      if url.startswith('//'):
        url = 'http:' + url

    if not url.split(':')[0].lower() in ['http','https']:
        url = 'http://%s' % url
    url = url.strip()

    # strip user and password
    url = re.sub(r'^(\w*://)[-+.\w]*(:[-+.\w]+)?@', r'\1' ,url)

    return url

def escapeURL(url):
    parts = list(urlparse.urlparse(url))
    safe = ['/', '/:@', '/', '/', '/?&=;', '/']
    for i in range(0,len(parts)):
      parts[i] = urllib.quote(urllib.unquote(parts[i]),safe[i])
    url = cgi.escape(urlparse.urlunparse(parts))
    try:
      return url.decode('idna')
    except:
      return url

import feedvalidator.formatter.text_html

def buildCodeListing(events, rawdata, url):
    # print feed
    codelines = []
    linenum = 1
    linesWithErrors = [e.params.get('line', 0) for e in events]
    for line in rawdata.split('\n'):
        line = feedvalidator.formatter.text_html.escapeAndMark(line)
        if not line: line = '&nbsp;'
        linetype = linenum in linesWithErrors and "b" or "a"
        codelines.append(applyTemplate('code_listing_line.tmpl', {"line":line, "linenum":linenum, "linetype":linetype}).decode('utf-8'))
        linenum += 1
    codelisting = "".join(codelines)
    return applyTemplate('code_listing.tmpl', {"codelisting":codelisting, "url":escapeURL(url)})

def yieldEventList(output):
  errors, warnings = output.getErrors(), output.getWarnings()

  yield output.header()
  for o in output.getErrors():
    yield o.encode('utf-8')
  if errors and warnings:
    yield output.footer()
    if len(warnings) == 1:
      yield applyTemplate('andwarn1.tmpl')
    else:
      yield applyTemplate('andwarn2.tmpl')
    yield output.header()
  for o in output.getWarnings():
    yield o.encode('utf-8')
  yield output.footer()

from feedvalidator.formatter.text_html import Formatter

def postvalidate(url, events, rawdata, feedType, autofind=1):
    """returns dictionary including 'url', 'events', 'rawdata', 'output', 'specialCase', 'feedType'"""
    # filter based on compatibility level
    from feedvalidator import compatibility
    filterFunc = compatibility.AA # hardcoded for now
    events = filterFunc(events)

    specialCase = None
    formattedOutput = Formatter(events, rawdata)
    if formattedOutput:
        # check for special cases
        specialCase = compatibility.analyze(events, rawdata)
        if (specialCase == 'html') and autofind:
            try:
                try:
                    import feedfinder
                    class NotARobot:
                        base=url
                        def get(self, url):
                            if url == self.base: return rawdata
                            sock=urllib.urlopen(url)
                            data=sock.read()
                            sock.close()
                            return data
                    feedfinder._gatekeeper = NotARobot()
                    rssurls = feedfinder.getFeeds(url)
                except:
                    rssurls = [url]
                if rssurls:
                    url = rssurls[0]
                    params = feedvalidator.validateURL(url, firstOccurrenceOnly=1, wantRawData=1)
                    events = params['loggedEvents']
                    rawdata = params['rawdata']
                    feedType = params['feedType']
                    return postvalidate(url, events, rawdata, feedType, autofind=0)
            except:
                pass

    return {"url":url, "events":events, "rawdata":rawdata, "output":formattedOutput, "specialCase":specialCase, "feedType":feedType}

def checker_app(environ, start_response):

    method = environ['REQUEST_METHOD'].lower()
    contentType = environ.get('CONTENT_TYPE', None)
    output_option = ''

    if (method == 'get') or (contentType and cgi.parse_header(contentType)[0].lower() == 'application/x-www-form-urlencoded'):
        fs = cgi.FieldStorage(fp=environ.get('wsgi.input',None), environ=environ)
        url = fs.getvalue("url") or ''
        try:
          if url: url = url.decode('utf-8').encode('idna')
        except:
          pass
        manual = fs.getvalue("manual") or 0
        rawdata = fs.getvalue("rawdata") or ''
        output_option = fs.getvalue("output") or ''

        # XXX Should use 'charset'
        try:
            rawdata = decUTF8(rawdata)[0]
        except UnicodeError:
            rawdata = decW1252(rawdata)[0]

        rawdata = rawdata[:feedvalidator.MAXDATALENGTH].replace('\r\n', '\n').replace('\r', '\n')
    else:
        url = None
        manual = None
        rawdata = None

    if (output_option == "soap12"):
        # SOAP
        try:
            if ((method == 'post') and (not rawdata)):
                params = feedvalidator.validateStream(sys.stdin, contentType=contentType)
            elif rawdata :
                params = feedvalidator.validateString(rawdata, firstOccurrenceOnly=1)
            elif url:
                url = sanitizeURL(url)
                params = feedvalidator.validateURL(url, firstOccurrenceOnly=1, wantRawData=1)

            events = params['loggedEvents']
            feedType = params['feedType']

            # filter based on compatibility level
            from feedvalidator import compatibility
            filterFunc = compatibility.AA # hardcoded for now
            events = filterFunc(events)

            events_error = list()
            events_warn = list()
            events_info = list()


            # format as xml
            from feedvalidator.formatter.text_xml import Formatter as xmlformat
            output = xmlformat(events)

            for event in events:
                if isinstance(event,Error): events_error.append(output.format(event))
                if isinstance(event,Warning): events_warn.append(output.format(event))
                if isinstance(event,Info): events_info.append(output.format(event))
            if len(events_error) > 0:
                validation_bool = "false"
            else:
                validation_bool = "true"

            from datetime import datetime
            right_now = datetime.now()
            validationtime = str( right_now.isoformat())

            body = applyTemplate('soap.tmpl', {
              'errorlist':"\n".join( events_error), 'errorcount': str(len(events_error)),
              'warninglist':"\n".join( events_warn), 'warningcount': str(len(events_warn)),
              'infolist':"\n".join( events_info), 'infocount': str(len(events_info)),
              'home_url': HOMEURL, 'url': url, 'date_time': validationtime, 'validation_bool': validation_bool
              })
            start_response('200 OK', [('Content-type', 'application/soap+xml; charset=' + ENCODING)])
            yield body

        except:
            import traceback
            tb = ''.join(apply(traceback.format_exception, sys.exc_info()))

            from feedvalidator.formatter.text_xml import xmlEncode
            start_response('500 Internal Error', [('Content-type', 'text/xml; charset=' + ENCODING)])

            yield applyTemplate('fault.tmpl', {'code':sys.exc_info()[0],
              'string':sys.exc_info()[1], 'traceback':xmlEncode(tb)})

    else:
        start_response('200 OK', [('Content-type', 'text/html; charset=' + ENCODING)])

        if url or rawdata:
            # validate
            goon = 0
            if rawdata:
                # validate raw data (from text form)
                try:
                    params = feedvalidator.validateString(rawdata, firstOccurrenceOnly=1)
                    events = params['loggedEvents']
                    feedType = params['feedType']
                    goon = 1
                except ValidationFailure, vfv:
                    yield applyTemplate('header.tmpl', {'title':'Feed Validator Results: %s' % escapeURL(url)})
                    yield applyTemplate('manual.tmpl', {'rawdata':escapeURL(url)})
                    output = Formatter([vfv.event], None)
                    for item in yieldEventList(output):
                        yield item
                    yield applyTemplate('error.tmpl')
                except:
                    yield applyTemplate('header.tmpl', {'title':'Feed Validator Results: %s' % escapeURL(url)})
                    yield applyTemplate('manual.tmpl', {'rawdata':escapeURL(url)})
                    yield applyTemplate('error.tmpl')
            else:
                url = sanitizeURL(url)
                try:
                    params = feedvalidator.validateURL(url, firstOccurrenceOnly=1, wantRawData=1)
                    events = params['loggedEvents']
                    rawdata = params['rawdata']
                    feedType = params['feedType']
                    goon = 1
                except ValidationFailure, vfv:
                    yield applyTemplate('header.tmpl', {'title':'Feed Validator Results: %s' % escapeURL(url)})
                    yield applyTemplate('index.tmpl', {'value':escapeURL(url)})
                    output = Formatter([vfv.event], None)
                    for item in yieldEventList(output):
                        yield item
                    yield applyTemplate('error.tmpl')
                except:
                    yield applyTemplate('header.tmpl', {'title':'Feed Validator Results: %s' % escapeURL(url)})
                    yield applyTemplate('index.tmpl', {'value':escapeURL(url)})
                    yield applyTemplate('error.tmpl')
            if goon:
                # post-validate (will do RSS autodiscovery if needed)
                validationData = postvalidate(url, events, rawdata, feedType)

                # write output header
                url = validationData['url']
                feedType = validationData['feedType']
                rawdata = validationData['rawdata']
                yield applyTemplate('header.tmpl', {'title':'Feed Validator Results: %s' % escapeURL(url)})
                if manual:
                    yield applyTemplate('manual.tmpl', {'rawdata':cgi.escape(rawdata)})
                else:
                    yield applyTemplate('index.tmpl', {'value':escapeURL(url)})

                output = validationData.get('output', None)

                # print special case, if any
                specialCase = validationData.get('specialCase', None)
                if specialCase:
                    yield applyTemplate('%s.tmpl' % specialCase)

                msc = output.mostSeriousClass()

                # Explain the overall verdict
                if msc == Error:
                    from feedvalidator.logging import ObsoleteNamespace
                    if len(output.getErrors())==1 and \
                        isinstance(output.data[0],ObsoleteNamespace):
                        yield applyTemplate('notsupported.tmpl')
                    else:
                        yield applyTemplate('invalid.tmpl')
                elif msc == Warning:
                    yield applyTemplate('warning.tmpl')
                elif msc == Info:
                    yield applyTemplate('info.tmpl')

                # Print any issues, whether or not the overall feed is valid
                if output:
                    for item in yieldEventList(output):
                        yield item

                    # print code listing
                    yield buildCodeListing(validationData['events'], validationData['rawdata'], url)

                # As long as there were no errors, show that the feed is valid
                if msc != Error:
                    # valid
                    htmlUrl = escapeURL(urllib.quote(url))
                    try:
                      htmlUrl = htmlUrl.encode('idna')
                    except:
                      pass
                    docType = 'feed'
                    if feedType == TYPE_ATOM_ENTRY: docType = 'entry'
                    if feedType == TYPE_XRD: docType = 'document'
                    if feedType == TYPE_OPENSEARCH: docType = 'description document'
                    yield applyTemplate('valid.tmpl', {"url":htmlUrl, "srcUrl":htmlUrl, "feedType":FEEDTYPEDISPLAY[feedType], "graphic":VALIDFEEDGRAPHIC[feedType], "HOMEURL":HOMEURL, "docType":docType})
        else:
            # nothing to validate, just write basic form
            yield applyTemplate('header.tmpl', {'title':'Feed Validator for Atom and RSS'})
            if manual:
                yield applyTemplate('manual.tmpl', {'rawdata':''})
            else:
                yield applyTemplate('index.tmpl', {'value':'http://'})
            yield applyTemplate('special.tmpl', {})

        yield applyTemplate('navbar.tmpl')
        yield applyTemplate('footer.tmpl')

if __name__ == "__main__":
    if len(sys.argv)==1 or not sys.argv[1].isdigit():
        def start_response(status, headers):
            print 'Status: %s\r\n' % status,
            for header,value in headers:
                print '%s: %s\r\n' % (header, value),
            print
        for output in checker_app(os.environ, start_response):
            print output.decode('utf-8')
    else:
        # export HTTP_HOST=http://feedvalidator.org/
        # export SCRIPT_NAME=check.cgi
        # export SCRIPT_FILENAME=/home/rubys/svn/feedvalidator/check.cgi
        import fcgi
        port=int(sys.argv[1])
        fcgi.WSGIServer(checker_app, bindAddress=("127.0.0.1", port)).run()
