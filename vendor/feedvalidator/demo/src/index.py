import feedvalidator
import sys

def escapeURL(url):
    import cgi, urllib, urlparse
    parts = map(urllib.quote, map(urllib.unquote, urlparse.urlparse(url)))
    return cgi.escape(urlparse.urlunparse(parts))

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
    import re
    url = re.sub(r'^(\w*://)[-+.\w]*(:[-+.\w]+)?@', r'\1' ,url)

    return url

def index(req,url="",out="xml"):

  if not url:
    s = """<html><head><title>Feed Validator</title></head><body>
 Enter the URL to validate:
  <p>
  <form method="GET">

    URL: <input type="text" name="url"><br>
    <input type="submit">
    <input type="hidden" name="out" value="html">
  </form>
</html>"""
    return s
  
  url = sanitizeURL(url)
  events = feedvalidator.validateURL(url, firstOccurrenceOnly=1)['loggedEvents']

  # (optional) arg 2 is compatibility level
  # "A" is most basic level
  # "AA" mimics online validator
  # "AAA" is experimental; these rules WILL change or disappear in future versions
  from feedvalidator import compatibility
  filter = "AA"
  filterFunc = getattr(compatibility, filter)
  events = filterFunc(events)

  if out == "html":
    s = "<html><body><p>Validating " + escapeURL(url) + "...</p><pre>"

    from feedvalidator.formatter.text_plain import Formatter
    output = Formatter(events)
    if output:
      s += "\n".join(output)
    else:
      s += "No errors or warnings"

    s += "</pre></body></html>"
  
    return s
  else:
    from feedvalidator.formatter.text_xml import Formatter
    s = "\n".join(Formatter(events))  or ""

    s = '<?xml version="1.0"?>\n<validationErrors>\n' + s + "</validationErrors>"
    req.content_type = "application/xml"
    return s

if __name__=="__main__":
    import sys
    for url in sys.argv[1:]: 
      print index(0,url=url,out="html")
