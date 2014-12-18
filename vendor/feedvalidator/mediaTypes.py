"""
$Id: mediaTypes.py 717 2007-01-04 18:04:57Z rubys $
This module deals with valid internet media types for feeds.
"""

__author__ = "Joseph Walton <http://www.kafsemo.org/>"
__version__ = "$Revision: 717 $"
__date__ = "$Date: 2007-01-04 18:04:57 +0000 (Thu, 04 Jan 2007) $"
__copyright__ = "Copyright (c) 2004 Joseph Walton"

from cgi import parse_header
from logging import UnexpectedContentType, TYPE_RSS1, TYPE_RSS2, TYPE_ATOM, TYPE_ATOM_ENTRY, TYPE_OPML, TYPE_OPENSEARCH, TYPE_XRD

FEED_TYPES = [
  'text/xml', 'application/xml', 'application/rss+xml', 'application/rdf+xml',
  'application/atom+xml', 'text/x-opml', 'application/xrds+xml',
  'application/opensearchdescription+xml'
]

# Is the Content-Type correct?
def checkValid(contentType, loggedEvents):
  (mediaType, params) = parse_header(contentType)
  if mediaType.lower() not in FEED_TYPES:
    loggedEvents.append(UnexpectedContentType({"type": "Feeds", "contentType": contentType}))
  if 'charset' in params:
    charset = params['charset']
  else:
    charset = None

  return (mediaType, charset)

# Warn about mismatches between media type and feed version
def checkAgainstFeedType(mediaType, feedType, loggedEvents):
  mtl = mediaType.lower()

  if mtl in ['application/x.atom+xml', 'application/atom+xml']:
    if feedType not in [TYPE_ATOM, TYPE_ATOM_ENTRY]:
      loggedEvents.append(UnexpectedContentType({"type": 'Non-Atom 1.0 feeds', "contentType": mediaType}))
  elif mtl == 'application/rdf+xml':
    if feedType != TYPE_RSS1:
      loggedEvents.append(UnexpectedContentType({"type": 'Non-RSS 1.0 feeds', "contentType": mediaType}))
  elif mtl == 'application/rss+xml':
    if feedType not in [TYPE_RSS1, TYPE_RSS2]:
      loggedEvents.append(UnexpectedContentType({"type": 'Non-RSS feeds', "contentType": mediaType}))
  elif mtl == 'text/x-opml':
    if feedType not in [TYPE_OPML]:
      loggedEvents.append(UnexpectedContentType({"type": 'Non-OPML feeds', "contentType": mediaType}))
  elif mtl == 'application/opensearchdescription+xml':
    if feedType not in [TYPE_OPENSEARCH]:
      loggedEvents.append(UnexpectedContentType({"type": 'Non-OpenSearchDescription documents', "contentType": mediaType}))
  elif mtl == 'application/xrds+xml':
    if feedType not in [TYPE_XRD]:
      loggedEvents.append(UnexpectedContentType({"type": 'Non-Extensible Resource Descriptor documents', "contentType": mediaType}))

# warn if a non-specific media type is used without a 'marker'
def contentSniffing(mediaType, rawdata, loggedEvents):
  if mediaType not in FEED_TYPES: return
  if mediaType == 'application/atom+xml': return
  if mediaType == 'application/rss+xml': return
  if mediaType == 'text/x-opml': return
  if mediaType == 'application/opensearchdescription+xml': return
  if mediaType == 'application/xrds+xml': return

  block = rawdata[:512]

  if block.find('<rss') >= 0: return
  if block.find('<feed') >= 0: return
  if block.find('<opml') >= 0: return
  if block.find('<OpenSearchDescription') >= 0: return
  if (block.find('<rdf:RDF') >=0 and 
      block.find('http://www.w3.org/1999/02/22-rdf-syntax-ns#') >= 0 and
      block.find( 'http://purl.org/rss/1.0/')): return

  from logging import NonSpecificMediaType
  loggedEvents.append(NonSpecificMediaType({"contentType": mediaType}))
