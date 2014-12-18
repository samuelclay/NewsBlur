#!/usr/bin/python
"""$Id: testUri.py 708 2006-10-11 13:30:30Z rubys $"""

__author__ = "Joseph Walton <http://www.kafsemo.org/>"
__version__ = "$Revision: 708 $"
__date__ = "$Date: 2006-10-11 13:30:30 +0000 (Wed, 11 Oct 2006) $"
__copyright__ = "Copyright (c) 2004 Joseph Walton"

import os, sys

curdir = os.path.abspath(os.path.dirname(sys.argv[0]))
srcdir = os.path.split(curdir)[0]
if srcdir not in sys.path:
  sys.path.insert(0, srcdir)
basedir = os.path.split(srcdir)[0]

import unittest

class UriTest(unittest.TestCase):
  pass

testsEqual = [
  ['http://example.com/', 'http://example.com'],
  ['HTTP://example.com/', 'http://example.com/'],
  ['http://example.com/', 'http://example.com:/'],
  ['http://example.com/', 'http://example.com:80/'],
  ['http://example.com/', 'http://Example.com/'],
  ['http://example.com/~smith/', 'http://example.com/%7Esmith/'],
  ['http://example.com/~smith/', 'http://example.com/%7esmith/'],
  ['http://example.com/%7Esmith/', 'http://example.com/%7esmith/'],
  ['http://example.com/%C3%87', 'http://example.com/C%CC%A7'],

  ['tag:example.com,2004:Test', 'TAG:example.com,2004:Test'],

  ['ftp://example.com/', 'ftp://EXAMPLE.COM/'],
  ['ftp://example.com/', 'ftp://example.com:21/'],
  ['mailto:user@example.com', 'mailto:user@EXAMPLE.COM'],

  ['../%C3%87', '../C%CC%A7'],
]

testsDifferent = [
  ['http://example.com/', 'http://example.org/'],
  ['http://example.com/index.html', 'http://example.com'],
  ['FTP://example.com/', 'http://example.com/'],
  ['http://example.com/', 'http://example.com:8080/'],
  ['http://example.com:8080/', 'http://example.com:80/'],
  ['http://example.com/index.html', 'http://example.com/INDEX.HTML'],
  ['http://example.com/~smith/', 'http://example.com/%7Esmith'],
  ['http://example.com/~smith/', 'http://example.com/%2fsmith/'],

  ['http://user:password@example.com/', 'http://USER:PASSWORD@example.com/'],

  # Not a valid HTTP URL
  ['http://example.com:x', 'http://example.com/'],

  ['tag:example.com,2004:Test', 'tag:EXAMPLE.COM,2004:Test'],
  ['tag:user@example.com,2004:Test', 'tag:user@EXAMPLE.COM,2004:Test'],
  ['tag:example.com,2004:test', 'Tag:example.com,2004:TEST'],
  ['tag:example.com,2004:Test', 'Tag:example.com,2004-01:Test'],
  ['tag:user@example.com,2004:Test', 'tag:USER@example.com,2004:Test'],

  ['ftp://example.com/', 'ftp://example.com/test'],
  ['mailto:user@example.com', 'mailto:USER@example.com'],
  ['mailto:user@example.com?subject=test', 'mailto:user@example.com?subject=TEST']
]

# Examples from PaceCanonicalIds
testsCanonical = [
  ['HTTP://example.com/', 'http://example.com/'],
  ['http://EXAMPLE.COM/', 'http://example.com/'],
  ['http://example.com/%7Ejane', 'http://example.com/~jane'],
  ['http://example.com/?q=1%2f2', 'http://example.com/?q=1%2F2'],
  ['http://example.com/?q=1/2'],
  ['http://example.com/a/./b', 'http://example.com/a/b'],
  ['http://example.com/a/../a/b', 'http://example.com/a/b'],
  ['http://user:password@example.com/', 'http://user:password@example.com/'],
  ['http://User:Password@Example.com/', 'http://User:Password@example.com/'],
  ['http://@example.com/', 'http://example.com/'],
  ['http://@Example.com/', 'http://example.com/'],
  ['http://:@example.com/', 'http://example.com/'],
  ['http://:@Example.com/', 'http://example.com/'],
  ['http://example.com', 'http://example.com/'],
  ['http://example.com:80/', 'http://example.com/'],
  ['http://www.w3.org/2000/01/rdf-schema#'],
  ['http://example.com/?q=C%CC%A7', 'http://example.com/?q=%C3%87'],
  ['http://example.com/?q=%E2%85%A0'],

  ['http://example.com/?'],

  [u'http://example.com/%C3%87'],
 
  
  # Other tests
  ['mailto:user@EXAMPLE.COM', 'mailto:user@example.com'],
  ['TAG:example.com,2004:Test', 'tag:example.com,2004:Test'],
  ['ftp://Example.Com:21/', 'ftp://example.com/'],
  ['http://example.com/?q=%E2%85%A0'],
  ['ldap://[2001:db8::7]/c=GB?objectClass?one'],
  ['mailto:John.Doe@example.com'],
  ['news:comp.infosystems.www.servers.unix'],
  ['tel:+1-816-555-1212'],
  ['telnet://192.0.2.16:80/'],
  ['urn:oasis:names:specification:docbook:dtd:xml:4.1.2'],

  ['http://example.com:081/', 'http://example.com:81/'],

  ['/test#test#test', '/test#test%23test'],
  ['http://com./'],
  ['http://example.com./', 'http://example.com/'],
  ['http://www.example.com//a//', 'http://www.example.com//a//'],
  ['http://www.example.com/./a//', 'http://www.example.com/a//'],
  ['http://www.example.com//a/./', 'http://www.example.com//a/'],

  ['http://example.com/%2F/'],
  ['http://example.com/\\/', 'http://example.com/%5C/'],

  ["aa1+-.:///?a1-._~!$&'()*+,;=:@/?#a1-._~!$&'()*+,;=:@/?"],

  ['http://example.com/?a b', 'http://example.com/?a%20b'],
  ['http://example.com/?a+b'],
  ['http://a/b/c/../../../../g', 'http://a/g'],

  ['/.foo', '/.foo'],
  ['/foo/bar/.', '/foo/bar/'],
  ['/foo/bar/..', '/foo/'],
  ['http:test'],
  ['tag:'],
  ['file://', 'file:///'],

  ['telnet://example.com:23/', 'telnet://example.com/'],

  ['x://:@a/', 'x://a/'],

  ['tag:www.stanleysy.com,2005://1.119'],
  ['tag:timothy@hpl.hp.com,2001:web/externalHome'],

  ['http://xxx/read?id=abc%26x%3Dz&x=y'],
  ['tag:www.stanleysy.com,2005:%2F%2F1.119'],
]

testsInvalid = [
   # This URI is not in canonical form, and cannot be normalised
  'http://example.com/?q=%C7'

  # Don't try to deal with relative URI references
  'foo/../bar',
  './http://',
  './\\/',
]

import feedvalidator.uri

def buildTestSuite():
  i = 0
  for t in testsEqual:
    i+=1
    def tstEqual(self, a, b):
      self.assertEqual(feedvalidator.uri.Uri(a), feedvalidator.uri.Uri(b))
    func = lambda self, a=t[0], b=t[1]: tstEqual(self, a, b)
    func.__doc__ = 'Test ' + t[0] + " == "  + t[1]
    setattr(UriTest, 'test' + str(i), func)

  for t in testsDifferent:
    i+=1
    def tstDifferent(self, a, b):
      self.assertNotEqual(feedvalidator.uri.Uri(a), feedvalidator.uri.Uri(b))
    func = lambda self, a=t[0], b=t[1]: tstDifferent(self, a, b)
    func.__doc__ = 'Test ' + t[0] + " != "  + t[1]
    setattr(UriTest, 'test' + str(i), func)

  for t in testsCanonical:
    i+=1
    o = t[0]
    if len(t) > 1:
      c = t[1]
    else:
      c = o
    def tstCanonicalForm(self, a, b):
      cf = feedvalidator.uri.canonicalForm(a)
      self.assertEqual(cf, b, 'Became: ' + str(cf))
    func = lambda self, a=o, b=c: tstCanonicalForm(self, a, b)
    func.__doc__ = 'Test ' + o + ' becomes ' + c
    setattr(UriTest, 'test' + str(i), func)

  for a in testsInvalid:
    i+= 1
    def tstCanFindCanonicalForm(self, a):
      self.assertEquals(feedvalidator.uri.canonicalForm(a), None)
    func = lambda self, a=a: tstCanFindCanonicalForm(self, a)
    func.__doc__ = 'Test ' + a + ' cannot be canonicalised'
    setattr(UriTest, 'test' + str(i), func)

  return unittest.TestLoader().loadTestsFromTestCase(UriTest)

if __name__ == '__main__':
  buildTestSuite()
  unittest.main()
