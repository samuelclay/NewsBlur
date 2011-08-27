"""
URI Normalization function:
 * Always provide the URI scheme in lowercase characters.
 * Always provide the host, if any, in lowercase characters.
 * Only perform percent-encoding where it is essential.
 * Always use uppercase A-through-F characters when percent-encoding.
 * Prevent dot-segments appearing in non-relative URI paths.
 * For schemes that define a default authority, use an empty authority if the
   default is desired.
 * For schemes that define an empty path to be equivalent to a path of "/",
   use "/".
 * For schemes that define a port, use an empty port if the default is desired
 * All portions of the URI must be utf-8 encoded NFC from Unicode strings

implements:
  http://gbiv.com/protocols/uri/rev-2002/rfc2396bis.html#canonical-form
  http://www.intertwingly.net/wiki/pie/PaceCanonicalIds

inspired by:
  Tony J. Ibbs,    http://starship.python.net/crew/tibs/python/tji_url.py
  Mark Nottingham, http://www.mnot.net/python/urlnorm.py
"""

__license__ = "Python"

import re, unicodedata, urlparse
from urllib import quote, unquote

default_port = {
    'ftp': 21,
    'telnet': 23,
    'http': 80,
    'gopher': 70,
    'news': 119,
    'nntp': 119,
    'prospero': 191,
    'https': 443,
    'snews': 563,
    'snntp': 563,
}

def normalize(url):
    """Normalize a URL."""
    if not isinstance(url, basestring):
        return url
        
    scheme,auth,path,query,fragment = urlparse.urlsplit(url.strip())
    (userinfo,host,port)=re.search('([^@]*@)?([^:]*):?(.*)',auth).groups()

    # Always provide the URI scheme in lowercase characters.
    scheme = scheme.lower()

    # Always provide the host, if any, in lowercase characters.
    host = host.lower()
    if host and host[-1] == '.': host = host[:-1]

    # Only perform percent-encoding where it is essential.
    # Always use uppercase A-through-F characters when percent-encoding.
    # All portions of the URI must be utf-8 encoded NFC from Unicode strings
    def clean(string):
        try:
            string=unicode(unquote(string))
            return unicodedata.normalize('NFC',string).encode('utf-8')
        except UnicodeDecodeError:
            return string
    path=quote(clean(path),"~:/?#[]@!$&'()*+,;=")
    fragment=quote(clean(fragment),"~")

    # note care must be taken to only encode & and = characters as values
    query="&".join(["=".join([quote(clean(t) ,"~:/?#[]@!$'()*+,;=")
        for t in q.split("=",1)]) for q in query.split("&")])

    # Prevent dot-segments appearing in non-relative URI paths.
    if scheme in ["","http","https","ftp","file"]:
        output=[]
        for input in path.split('/'):
            if input=="":
                if not output: output.append(input)
            elif input==".":
                pass
            elif input=="..":
                if len(output)>1: output.pop()
            else:
                output.append(input)
        if input in ["",".",".."]: output.append("")
        path='/'.join(output)

    # For schemes that define a default authority, use an empty authority if
    # the default is desired.
    if userinfo in ["@",":@"]: userinfo=""

    # For schemes that define an empty path to be equivalent to a path of "/",
    # use "/".
    if path=="" and scheme in ["http","https","ftp","file"]:
        path="/"

    # For schemes that define a port, use an empty port if the default is
    # desired
    if port and scheme in default_port.keys():
        if port.isdigit():
            port=str(int(port))
            if int(port)==default_port[scheme]:
                port = ''

    # Put it all back together again
    auth=(userinfo or "") + host
    if port: auth+=":"+port
    if url.endswith("#") and query=="" and fragment=="": path+="#"
    url = urlparse.urlunsplit((scheme,auth,path,query,fragment))
    
    if '://' not in url:
        url = 'http://' + url
    if url.startswith('feed://'):
        url = url.replace('feed://', 'http://')

    return url

if __name__ == "__main__":
    import unittest
    suite = unittest.TestSuite()

    """ from http://www.intertwingly.net/wiki/pie/PaceCanonicalIds """
    tests= [
        (False, "http://:@example.com/"),
        (False, "http://@example.com/"),
        (False, "http://example.com"),
        (False, "HTTP://example.com/"),
        (False, "http://EXAMPLE.COM/"),
        (False, "http://example.com/%7Ejane"),
        (False, "http://example.com/?q=%C7"),
        (False, "http://example.com/?q=%5c"),
        (False, "http://example.com/?q=C%CC%A7"),
        (False, "http://example.com/a/../a/b"),
        (False, "http://example.com/a/./b"),
        (False, "http://example.com:80/"),
        (True,  "http://example.com/"),
        (True,  "http://example.com/?q=%C3%87"),
        (True,  "http://example.com/?q=%E2%85%A0"),
        (True,  "http://example.com/?q=%5C"),
        (True,  "http://example.com/~jane"),
        (True,  "http://example.com/a/b"),
        (True,  "http://example.com:8080/"),
        (True,  "http://user:password@example.com/"),

        # from rfc2396bis
        (True,  "ftp://ftp.is.co.za/rfc/rfc1808.txt"),
        (True,  "http://www.ietf.org/rfc/rfc2396.txt"),
        (True,  "ldap://[2001:db8::7]/c=GB?objectClass?one"),
        (True,  "mailto:John.Doe@example.com"),
        (True,  "news:comp.infosystems.www.servers.unix"),
        (True,  "tel:+1-816-555-1212"),
        (True,  "telnet://192.0.2.16:80/"),
        (True,  "urn:oasis:names:specification:docbook:dtd:xml:4.1.2"),

        # other
        (True,  "http://127.0.0.1/"),
        (False,  "http://127.0.0.1:80/"),
        (True,   "http://www.w3.org/2000/01/rdf-schema#"),
        (False, "http://example.com:081/"),
    ]

    def testcase(expected,value):
        class test(unittest.TestCase):
            def runTest(self):
                assert (normalize(value)==value)==expected, \
                    (expected, value, normalize(value))
        return test()

    for (expected,value) in tests:
        suite.addTest(testcase(expected,value))

    """ mnot test suite; three tests updated for rfc2396bis. """
    tests = {
        '/foo/bar/.':                    '/foo/bar/',
        '/foo/bar/./':                   '/foo/bar/',
        '/foo/bar/..':                   '/foo/',
        '/foo/bar/../':                  '/foo/',
        '/foo/bar/../baz':               '/foo/baz',
        '/foo/bar/../..':                '/',
        '/foo/bar/../../':               '/',
        '/foo/bar/../../baz':            '/baz',
        '/foo/bar/../../../baz':         '/baz', #was: '/../baz',
        '/foo/bar/../../../../baz':      '/baz',
        '/./foo':                        '/foo',
        '/../foo':                       '/foo', #was: '/../foo',
        '/foo.':                         '/foo.',
        '/.foo':                         '/.foo',
        '/foo..':                        '/foo..',
        '/..foo':                        '/..foo',
        '/./../foo':                     '/foo', #was: '/../foo',
        '/./foo/.':                      '/foo/',
        '/foo/./bar':                    '/foo/bar',
        '/foo/../bar':                   '/bar',
        '/foo//':                        '/foo/',
        '/foo///bar//':                  '/foo/bar/',
        'http://www.foo.com:80/foo':     'http://www.foo.com/foo',
        'http://www.foo.com:8000/foo':   'http://www.foo.com:8000/foo',
        'http://www.foo.com./foo/bar.html': 'http://www.foo.com/foo/bar.html',
        'http://www.foo.com.:81/foo':    'http://www.foo.com:81/foo',
        'http://www.foo.com/%7ebar':     'http://www.foo.com/~bar',
        'http://www.foo.com/%7Ebar':     'http://www.foo.com/~bar',
        'ftp://user:pass@ftp.foo.net/foo/bar':
             'ftp://user:pass@ftp.foo.net/foo/bar',
        'http://USER:pass@www.Example.COM/foo/bar':
             'http://USER:pass@www.example.com/foo/bar',
        'http://www.example.com./':      'http://www.example.com/',
        '-':                             '-',
    }

    def testcase(original,normalized):
        class test(unittest.TestCase):
            def runTest(self):
                assert normalize(original)==normalized, \
                    (original, normalized, normalize(original))
        return test()

    for (original,normalized) in tests.items():
        suite.addTest(testcase(original,normalized))

    """ execute tests """
    unittest.TextTestRunner().run(suite)
