"""$Id: __init__.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

import socket
if hasattr(socket, 'setdefaulttimeout'):
  socket.setdefaulttimeout(10)
  Timeout = socket.timeout
else:
  import timeoutsocket
  timeoutsocket.setDefaultSocketTimeout(10)
  Timeout = timeoutsocket.Timeout

import urllib2
import logging
from logging import *
from xml.sax import SAXException
from xml.sax.xmlreader import InputSource
import re
import xmlEncoding
import mediaTypes
from httplib import BadStatusLine

MAXDATALENGTH = 200000

def _validate(aString, firstOccurrenceOnly, loggedEvents, base, encoding, selfURIs=None):
  """validate RSS from string, returns validator object"""
  from xml.sax import make_parser, handler
  from base import SAXDispatcher
  from exceptions import UnicodeError
  from cStringIO import StringIO

  # By now, aString should be Unicode
  source = InputSource()
  source.setByteStream(StringIO(xmlEncoding.asUTF8(aString)))

  validator = SAXDispatcher(base, selfURIs or [base], encoding)
  validator.setFirstOccurrenceOnly(firstOccurrenceOnly)

  validator.loggedEvents += loggedEvents

  # experimental RSS-Profile draft 1.06 support
  validator.setLiterals(re.findall('&#x26;(\w+);',aString))

  xmlver = re.match("^<\?\s*xml\s+version\s*=\s*['\"]([-a-zA-Z0-9_.:]*)['\"]",aString)
  if xmlver and xmlver.group(1)<>'1.0':
    validator.log(logging.BadXmlVersion({"version":xmlver.group(1)}))

  try:
    from xml.sax.expatreader import ExpatParser
    class fake_dtd_parser(ExpatParser):
      def reset(self):
        ExpatParser.reset(self)
        self._parser.UseForeignDTD(1)
    parser = fake_dtd_parser()
  except:
    parser = make_parser()

  parser.setFeature(handler.feature_namespaces, 1)
  parser.setContentHandler(validator)
  parser.setErrorHandler(validator)
  parser.setEntityResolver(validator)
  if hasattr(parser, '_ns_stack'):
    # work around bug in built-in SAX parser (doesn't recognize xml: namespace)
    # PyXML doesn't have this problem, and it doesn't have _ns_stack either
    parser._ns_stack.append({'http://www.w3.org/XML/1998/namespace':'xml'})

  def xmlvalidate(log):
    import libxml2
    from StringIO import StringIO
    from random import random

    prefix="...%s..." % str(random()).replace('0.','')
    msg=[]
    libxml2.registerErrorHandler(lambda msg,str: msg.append(str), msg)

    input = libxml2.inputBuffer(StringIO(xmlEncoding.asUTF8(aString)))
    reader = input.newTextReader(prefix)
    reader.SetParserProp(libxml2.PARSER_VALIDATE, 1)
    ret = reader.Read()
    while ret == 1: ret = reader.Read()

    msg=''.join(msg)
    for line in msg.splitlines():
      if line.startswith(prefix): log(line.split(':',4)[-1].strip())
  validator.xmlvalidator=xmlvalidate

  try:
    parser.parse(source)
  except SAXException:
    pass
  except UnicodeError:
    import sys
    exctype, value = sys.exc_info()[:2]
    validator.log(logging.UnicodeError({"exception":value}))

  if validator.getFeedType() == TYPE_RSS1:
    try:
      from rdflib.syntax.parsers.RDFXMLHandler import RDFXMLHandler

      class Handler(RDFXMLHandler):
        ns_prefix_map = {}
        prefix_ns_map = {}
        def add(self, triple): pass
        def __init__(self, dispatcher):
          RDFXMLHandler.__init__(self, self)
          self.dispatcher=dispatcher
        def error(self, message):
          self.dispatcher.log(InvalidRDF({"message": message}))
    
      source.getByteStream().reset()
      parser.reset()
      parser.setContentHandler(Handler(parser.getContentHandler()))
      parser.setErrorHandler(handler.ErrorHandler())
      parser.parse(source)
    except:
      pass

  return validator

def validateStream(aFile, firstOccurrenceOnly=0, contentType=None, base=""):
  loggedEvents = []

  if contentType:
    (mediaType, charset) = mediaTypes.checkValid(contentType, loggedEvents)
  else:
    (mediaType, charset) = (None, None)

  rawdata = aFile.read(MAXDATALENGTH)
  if aFile.read(1):
    raise ValidationFailure(logging.ValidatorLimit({'limit': 'feed length > ' + str(MAXDATALENGTH) + ' bytes'}))

  encoding, rawdata = xmlEncoding.decode(mediaType, charset, rawdata, loggedEvents, fallback='utf-8')

  validator = _validate(rawdata, firstOccurrenceOnly, loggedEvents, base, encoding)

  if mediaType and validator.feedType:
    mediaTypes.checkAgainstFeedType(mediaType, validator.feedType, validator.loggedEvents)

  return {"feedType":validator.feedType, "loggedEvents":validator.loggedEvents}

def validateString(aString, firstOccurrenceOnly=0, fallback=None, base=""):
  loggedEvents = []
  if type(aString) != unicode:
    encoding, aString = xmlEncoding.decode("", None, aString, loggedEvents, fallback)
  else:
    encoding = "utf-8" # setting a sane (?) default

  if aString is not None:
    validator = _validate(aString, firstOccurrenceOnly, loggedEvents, base, encoding)
    return {"feedType":validator.feedType, "loggedEvents":validator.loggedEvents}
  else:
    return {"loggedEvents": loggedEvents}

def validateURL(url, firstOccurrenceOnly=1, wantRawData=0):
  """validate RSS from URL, returns events list, or (events, rawdata) tuple"""
  loggedEvents = []
  request = urllib2.Request(url)
  request.add_header("Accept-encoding", "gzip, deflate")
  request.add_header("User-Agent", "FeedValidator/1.3")
  usock = None
  try:
    try:
      usock = urllib2.urlopen(request)
      rawdata = usock.read(MAXDATALENGTH)
      if usock.read(1):
        raise ValidationFailure(logging.ValidatorLimit({'limit': 'feed length > ' + str(MAXDATALENGTH) + ' bytes'}))
  
      # check for temporary redirects
      if usock.geturl()<>request.get_full_url():
        from httplib import HTTPConnection
        spliturl=url.split('/',3)
        if spliturl[0]=="http:":
          conn=HTTPConnection(spliturl[2])
          conn.request("GET",'/'+spliturl[3].split("#",1)[0])
          resp=conn.getresponse()
          if resp.status<>301:
            loggedEvents.append(TempRedirect({}))
  
    except BadStatusLine, status:
      raise ValidationFailure(logging.HttpError({'status': status.__class__}))
  
    except urllib2.HTTPError, status:
      rawdata = status.read()
      lastline = rawdata.strip().split('\n')[-1].strip()
      if lastline in ['</rss>','</feed>','</rdf:RDF>']:
        loggedEvents.append(logging.HttpError({'status': status}))
        usock = status
      else:
        raise ValidationFailure(logging.HttpError({'status': status}))
    except urllib2.URLError, x:
      raise ValidationFailure(logging.HttpError({'status': x.reason}))
    except Timeout, x:
      raise ValidationFailure(logging.IOError({"message": 'Server timed out', "exception":x}))
  
    if usock.headers.get('content-encoding', None) == None:
      loggedEvents.append(Uncompressed({}))
  
    if usock.headers.get('content-encoding', None) == 'gzip':
      import gzip, StringIO
      try:
        rawdata = gzip.GzipFile(fileobj=StringIO.StringIO(rawdata)).read()
      except:
        import sys
        exctype, value = sys.exc_info()[:2]
        event=logging.IOError({"message": 'Server response declares Content-Encoding: gzip', "exception":value})
        raise ValidationFailure(event)
  
    if usock.headers.get('content-encoding', None) == 'deflate':
      import zlib
      try:
        rawdata = zlib.decompress(rawdata, -zlib.MAX_WBITS)
      except:
        import sys
        exctype, value = sys.exc_info()[:2]
        event=logging.IOError({"message": 'Server response declares Content-Encoding: deflate', "exception":value})
        raise ValidationFailure(event)
  
    mediaType = None
    charset = None
  
    # Is the Content-Type correct?
    contentType = usock.headers.get('content-type', None)
    if contentType:
      (mediaType, charset) = mediaTypes.checkValid(contentType, loggedEvents)
  
    # Check for malformed HTTP headers
    for (h, v) in usock.headers.items():
      if (h.find(' ') >= 0):
        loggedEvents.append(HttpProtocolError({'header': h}))
  
    selfURIs = [request.get_full_url()]
    baseURI = usock.geturl()
    if not baseURI in selfURIs: selfURIs.append(baseURI)
  
    # Get baseURI from content-location and/or redirect information
    if usock.headers.get('content-location', None):
      from urlparse import urljoin
      baseURI=urljoin(baseURI,usock.headers.get('content-location', ""))
    elif usock.headers.get('location', None):
      from urlparse import urljoin
      baseURI=urljoin(baseURI,usock.headers.get('location', ""))
  
    if not baseURI in selfURIs: selfURIs.append(baseURI)
    usock.close()
    usock = None
  
    mediaTypes.contentSniffing(mediaType, rawdata, loggedEvents)
    
    encoding, rawdata = xmlEncoding.decode(mediaType, charset, rawdata, loggedEvents, fallback='utf-8')
  
    if rawdata is None:
      return {'loggedEvents': loggedEvents}
  
    rawdata = rawdata.replace('\r\n', '\n').replace('\r', '\n') # normalize EOL
    validator = _validate(rawdata, firstOccurrenceOnly, loggedEvents, baseURI, encoding, selfURIs)
  
    # Warn about mismatches between media type and feed version
    if mediaType and validator.feedType:
      mediaTypes.checkAgainstFeedType(mediaType, validator.feedType, validator.loggedEvents)
  
    params = {"feedType":validator.feedType, "loggedEvents":validator.loggedEvents}
    if wantRawData:
      params['rawdata'] = rawdata
    return params

  finally:
    try:
      if usock: usock.close()
    except:
      pass
  
__all__ = ['base',
           'channel',
           'compatibility',
           'image',
           'item',
           'logging',
           'rdf',
           'root',
           'rss',
           'skipHours',
           'textInput',
           'util',
           'validators',
           'validateURL',
           'validateString']
