"""feedfinder: Find the Web feed for a Web page
http://www.aaronsw.com/2002/feedfinder/

Usage:
  feed(uri) - returns feed found for a URI
  feeds(uri) - returns all feeds found for a URI

    >>> import feedfinder
    >>> feedfinder.feed('scripting.com')
    'http://scripting.com/rss.xml'
    >>>
    >>> feedfinder.feeds('scripting.com')
    ['http://delong.typepad.com/sdj/atom.xml', 
     'http://delong.typepad.com/sdj/index.rdf', 
     'http://delong.typepad.com/sdj/rss.xml']
    >>>

Can also use from the command line.  Feeds are returned one per line:

    $ python feedfinder.py diveintomark.org
    http://diveintomark.org/xml/atom.xml

How it works:
  0. At every step, feeds are minimally verified to make sure they are really feeds.
  1. If the URI points to a feed, it is simply returned; otherwise
     the page is downloaded and the real fun begins.
  2. Feeds pointed to by LINK tags in the header of the page (autodiscovery)
  3. <A> links to feeds on the same server ending in ".rss", ".rdf", ".xml", or 
     ".atom"
  4. <A> links to feeds on the same server containing "rss", "rdf", "xml", or "atom"
  5. <A> links to feeds on external servers ending in ".rss", ".rdf", ".xml", or 
     ".atom"
  6. <A> links to feeds on external servers containing "rss", "rdf", "xml", or "atom"
  7. Try some guesses about common places for feeds (index.xml, atom.xml, etc.).
  8. As a last ditch effort, we search Syndic8 for feeds matching the URI
"""

__version__ = "1.371"
__date__ = "2006-04-24"
__maintainer__ = "Aaron Swartz (me@aaronsw.com)"
__author__ = "Mark Pilgrim (http://diveintomark.org)"
__copyright__ = "Copyright 2002-4, Mark Pilgrim; 2006 Aaron Swartz"
__license__ = "Python"
__credits__ = """Abe Fettig for a patch to sort Syndic8 feeds by popularity
Also Jason Diamond, Brian Lalor for bug reporting and patches"""

_debug = 0

import sgmllib, urllib.request, urllib.parse, urllib.error, urllib.parse, re, sys, urllib.robotparser
import requests
from io import StringIO
from lxml import etree


# XML-RPC support allows feedfinder to query Syndic8 for possible matches.
# Python 2.3 now comes with this module by default, otherwise you can download it
try:
    import xmlrpc.client # http://www.pythonware.com/products/xmlrpc/
except ImportError:
    xmlrpclib = None

if not dict:
    def dict(aList):
        rc = {}
        for k, v in aList:
            rc[k] = v
        return rc
    
def _debuglog(message):
    if _debug: print(message)
    
class URLGatekeeper:
    """a class to track robots.txt rules across multiple servers"""
    def __init__(self):
        self.rpcache = {} # a dictionary of RobotFileParser objects, by domain
        self.urlopener = urllib.request.build_opener()
        self.urlopener.version = "NewsBlur Feed Finder (Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) AppleWebKit/534.48.3 (KHTML, like Gecko) Version/5.1 Safari/534.48.3)"
        _debuglog(self.urlopener.version)
        self.urlopener.addheaders = [('User-Agent', self.urlopener.version)]
        # self.urlopener.addheaders = [('User-Agent', self.urlopener.version), ('Accept', '*')]
        #urllib.robotparser.URLopener.version = self.urlopener.version
        #urllib.robotparser.URLopener.addheaders = self.urlopener.addheaders
        
    def _getrp(self, url):
        protocol, domain = urllib.parse.urlparse(url)[:2]
        if domain in self.rpcache:
            return self.rpcache[domain]
        baseurl = '%s://%s' % (protocol, domain)
        robotsurl = urllib.parse.urljoin(baseurl, 'robots.txt')
        _debuglog('fetching %s' % robotsurl)
        rp = urllib.robotparser.RobotFileParser(robotsurl)
        try:
            rp.read()
        except:
            pass
        self.rpcache[domain] = rp
        return rp
        
    def can_fetch(self, url):
        rp = self._getrp(url)
        allow = rp.can_fetch(self.urlopener.version, url)
        _debuglog("gatekeeper of %s says %s" % (url, allow))
        return allow

    def get(self, url, check=False):
        if check and not self.can_fetch(url): return ''
        try:
            return requests.get(url, headers=dict(self.urlopener.addheaders)).text
        except:
            return ''

_gatekeeper = URLGatekeeper()

class BaseParser(sgmllib.SGMLParser):
    def __init__(self, baseuri):
        sgmllib.SGMLParser.__init__(self)
        self.links = []
        self.baseuri = baseuri
        
    def normalize_attrs(self, attrs):
        def cleanattr(v):
            v = sgmllib.charref.sub(lambda m: chr(int(m.groups()[0])), v)
            if not v: return
            v = v.strip()
            v = v.replace('&lt;', '<').replace('&gt;', '>').replace('&apos;', "'").replace('&quot;', '"').replace('&amp;', '&')
            return v
        attrs = [(k.lower(), cleanattr(v)) for k, v in attrs if cleanattr(v)]
        attrs = [(k, k in ('rel','type') and v.lower() or v) for k, v in attrs if cleanattr(v)]
        return attrs
        
    def do_base(self, attrs):
        attrsD = dict(self.normalize_attrs(attrs))
        if 'href' not in attrsD: return
        self.baseuri = attrsD['href']
    
    def error(self, *a, **kw): pass # we're not picky
        
class LinkParser(BaseParser):
    FEED_TYPES = ('application/rss+xml',
                  'text/xml',
                  'application/atom+xml',
                  'application/x.atom+xml',
                  'application/x-atom+xml')
    def do_link(self, attrs):
        attrsD = dict(self.normalize_attrs(attrs))
        if 'rel' not in attrsD: return
        rels = attrsD['rel'].split()
        if 'alternate' not in rels: return
        if attrsD.get('type') not in self.FEED_TYPES: return
        if 'href' not in attrsD: return
        self.links.append(urllib.parse.urljoin(self.baseuri, attrsD['href']))

class ALinkParser(BaseParser):
    def start_a(self, attrs):
        attrsD = dict(self.normalize_attrs(attrs))
        if 'href' not in attrsD: return
        self.links.append(urllib.parse.urljoin(self.baseuri, attrsD['href']))

def makeFullURI(uri):
    if not uri: return
    uri = uri.strip()
    if uri.startswith('feed://'):
        uri = 'http://' + uri.split('feed://', 1).pop()
    for x in ['http', 'https']:
        if uri.startswith('%s://' % x):
            return uri
    return 'http://%s' % uri

def getLinks(data, baseuri):
    p = LinkParser(baseuri)
    p.feed(data)
    return p.links

def getLinksLXML(data, baseuri):
    parser = etree.HTMLParser(recover=True)
    tree = etree.parse(StringIO(data), parser)
    links = []
    for link in tree.findall('.//link'):
        if link.attrib.get('type') in LinkParser.FEED_TYPES:
            href = link.attrib['href']
            if href: links.append(href)
    return links

def getALinks(data, baseuri):
    p = ALinkParser(baseuri)
    p.feed(data)
    return p.links

def getLocalLinks(links, baseuri):
    found_links = []
    if not baseuri: return found_links
    baseuri = baseuri.lower()
    for l in links:
        try:
            if l.lower().startswith(baseuri):
                found_links.append(l)
        except (AttributeError, UnicodeDecodeError):
            pass
    return found_links

def isFeedLink(link):
    return link[-4:].lower() in ('.rss', '.rdf', '.xml', '.atom')

def isXMLRelatedLink(link):
    link = link.lower()
    return link.count('rss') + link.count('rdf') + link.count('xml') + link.count('atom')

r_brokenRedirect = re.compile('<newLocation[^>]*>(.*?)</newLocation>', re.S)
def tryBrokenRedirect(data):
    if '<newLocation' in data:
        newuris = r_brokenRedirect.findall(data)
        if newuris and newuris[0]: return newuris[0].strip()

def couldBeFeedData(data):
    data = data.lower()
    if data.count('<html'): return 0
    return data.count('<rss') + data.count('<rdf') + data.count('<feed')

def isFeed(uri):
    _debuglog('seeing if %s is a feed' % uri)
    protocol = urllib.parse.urlparse(uri)
    if protocol[0] not in ('http', 'https'): return 0
    try:
        data = _gatekeeper.get(uri, check=False)
    except (KeyError, UnicodeDecodeError):
        return False
    count = couldBeFeedData(data)
    return count

def cmp_(a, b):
    return (a > b) - (a < b) 

def sortFeeds(feed1Info, feed2Info):
    return cmp_(feed2Info['headlines_rank'], feed1Info['headlines_rank'])

def getFeedsFromSyndic8(uri):
    feeds = []
    try:
        server = xmlrpc.client.Server('http://www.syndic8.com/xmlrpc.php')
        feedids = server.syndic8.FindFeeds(uri)
        infolist = server.syndic8.GetFeedInfo(feedids, ['headlines_rank','status','dataurl'])
        infolist.sort(sortFeeds)
        feeds = [f['dataurl'] for f in infolist if f['status']=='Syndicated']
        _debuglog('found %s feeds through Syndic8' % len(feeds))
    except:
        pass
    return feeds
    
def feeds(uri, all=False, querySyndic8=False, _recurs=None):
    if _recurs is None: _recurs = [uri]
    fulluri = makeFullURI(uri)
    try:
        data = _gatekeeper.get(fulluri, check=False)
    except:
        return []
    # is this already a feed?
    if couldBeFeedData(data):
        return [fulluri]
    newuri = tryBrokenRedirect(data)
    if newuri and newuri not in _recurs:
        _recurs.append(newuri)
        return feeds(newuri, all=all, querySyndic8=querySyndic8, _recurs=_recurs)
    # nope, it's a page, try LINK tags first
    _debuglog('looking for LINK tags')
    try:
        outfeeds = getLinks(data, fulluri)
    except:
        outfeeds = []
    if not outfeeds:
        _debuglog('using lxml to look for LINK tags')
        try:
            outfeeds = getLinksLXML(data, fulluri)
        except:
            outfeeds = []
    _debuglog('found %s feeds through LINK tags' % len(outfeeds))
    outfeeds = list(filter(isFeed, outfeeds))
    if all or not outfeeds:
        # no LINK tags, look for regular <A> links that point to feeds
        _debuglog('no LINK tags, looking at A tags')
        try:
            links = getALinks(data, fulluri)
        except:
            links = []
        _debuglog('no LINK tags, looking at local links')
        locallinks = getLocalLinks(links, fulluri)
        # look for obvious feed links on the same server
        outfeeds.extend(list(filter(isFeed, list(filter(isFeedLink, locallinks)))))
        if all or not outfeeds:
            # look harder for feed links on the same server
            outfeeds.extend(list(filter(isFeed, list(filter(isXMLRelatedLink, locallinks)))))
        if all or not outfeeds:
            # look for obvious feed links on another server
            outfeeds.extend(list(filter(isFeed, list(filter(isFeedLink, links)))))
        if all or not outfeeds:
            # look harder for feed links on another server
            outfeeds.extend(list(filter(isFeed, list(filter(isXMLRelatedLink, links)))))
    if all or not outfeeds:
        _debuglog('no A tags, guessing')
        suffixes = [ # filenames used by popular software:
          'feed/', # obvious
          'atom.xml', # blogger, TypePad
          'index.atom', # MT, apparently
          'index.rdf', # MT
          'rss.xml', # Dave Winer/Manila
          'index.xml', # MT
          'index.rss' # Slash
        ]
        outfeeds.extend(list(filter(isFeed, [urllib.parse.urljoin(fulluri, x) for x in suffixes])))
    if (all or not outfeeds) and querySyndic8:
        # still no luck, search Syndic8 for feeds (requires xmlrpclib)
        _debuglog('still no luck, searching Syndic8')
        outfeeds.extend(getFeedsFromSyndic8(uri))
    if hasattr(__builtins__, 'set') or 'set' in __builtins__:
        outfeeds = list(set(outfeeds))
    return outfeeds

getFeeds = feeds # backwards-compatibility

def feed(uri):
    #todo: give preference to certain feed formats
    feedlist = feeds(uri)
    if feedlist:
        feeds_no_comments = [f for f in feedlist if 'comments' not in f.lower()]
        if feeds_no_comments:
            return feeds_no_comments[0]
        return feedlist[0]
    else:
        return None

##### test harness ######

def test():
    uri = 'http://diveintomark.org/tests/client/autodiscovery/html4-001.html'
    failed = []
    count = 0
    while 1:
        data = _gatekeeper.get(uri)
        if data.find('Atom autodiscovery test') == -1: break
        sys.stdout.write('.')
        sys.stdout.flush()
        count += 1
        links = getLinks(data, uri)
        if not links:
            print(('\n*** FAILED ***', uri, 'could not find link'))
            failed.append(uri)
        elif len(links) > 1:
            print(('\n*** FAILED ***', uri, 'found too many links'))
            failed.append(uri)
        else:
            atomdata = urllib.request.urlopen(links[0]).read()
            if atomdata.find('<link rel="alternate"') == -1:
                print(('\n*** FAILED ***', uri, 'retrieved something that is not a feed'))
                failed.append(uri)
            else:
                backlink = atomdata.split('href="').pop().split('"')[0]
                if backlink != uri:
                    print(('\n*** FAILED ***', uri, 'retrieved wrong feed'))
                    failed.append(uri)
        if data.find('<link rel="next" href="') == -1: break
        uri = urllib.parse.urljoin(uri, data.split('<link rel="next" href="').pop().split('"')[0])
    print()
    print((count, 'tests executed,', len(failed), 'failed'))
        
if __name__ == '__main__':
    args = sys.argv[1:]
    if args and args[0] == '--debug':
        _debug = 1
        args.pop(0)
    if args:
        uri = args[0]
    else:
        uri = 'http://diveintomark.org/'
    if uri == 'test':
        test()
    else:
        print(("\n".join(getFeeds(uri))))
