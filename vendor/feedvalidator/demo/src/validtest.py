"""$Id: validtest.py 708 2006-10-11 13:30:30Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 708 $"
__date__ = "$Date: 2006-10-11 13:30:30 +0000 (Wed, 11 Oct 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

import feedvalidator
import unittest, new, os, sys, glob, re
from feedvalidator.logging import Message,SelfDoesntMatchLocation,MissingSelf
from feedvalidator import compatibility
from feedvalidator.formatter.application_test import Formatter

class TestCase(unittest.TestCase):
  def failIfNoMessage(self, theList):
    filterFunc = compatibility.AA
    events = filterFunc(theList)
    output = Formatter(events)
    for e in events:
      if not output.format(e):
        raise self.failureException, 'could not contruct message for %s' % e

  def failUnlessContainsInstanceOf(self, theClass, params, theList, msg=None):
    """Fail if there are no instances of theClass in theList with given params"""
    self.failIfNoMessage(theList)

    failure=(msg or 'no %s instances in %s' % (theClass.__name__, `theList`))
    for item in theList:
      if issubclass(item.__class__, theClass):
        if not params: return
        for k, v in params.items():
          if str(item.params[k]) <> v:
            failure=("%s.%s value was %s, expected %s" %
               (theClass.__name__, k, item.params[k], v))
            break
        else:
          return
    raise self.failureException, failure

  def failIfContainsInstanceOf(self, theClass, params, theList, msg=None):
    """Fail if there are instances of theClass in theList with given params"""

    self.failIfNoMessage(theList)

    for item in theList:
      if theClass==Message and isinstance(item,SelfDoesntMatchLocation):
        continue
      if theClass==Message and isinstance(item,MissingSelf):
        continue
      if issubclass(item.__class__, theClass):
        if not params:
          raise self.failureException, \
             (msg or 'unexpected %s' % (theClass.__name__))
        allmatch = 1
        for k, v in params.items():
          if item.params[k] != v:
            allmatch = 0
        if allmatch:
          raise self.failureException, \
             "unexpected %s.%s with a value of %s" % \
             (theClass.__name__, k, v)

desc_re = re.compile("<!--\s*Description:\s*(.*?)\s*Expect:\s*(!?)(\w*)(?:{(.*?)})?\s*-->")

validome_re = re.compile("<!--\s*Description:\s*(.*?)\s*Message:\s*(!?)(\w*).*?\s*-->", re.S)

def getDescription(xmlfile):
  """Extract description and exception from XML file

  The deal here is that each test case is an XML file which contains
  not only a possibly invalid RSS feed but also the description of the
  test, i.e. the exception that we would expect the RSS validator to
  raise (or not) when it validates the feed.  The expected exception and
  the human-readable description are placed into an XML comment like this:

  <!--
    Description:  channel must include title
    Expect:     MissingTitle
  -->

  """

  stream = open(xmlfile)
  xmldoc = stream.read()
  stream.close()

  search_results = desc_re.search(xmldoc)
  if search_results:
    description, cond, excName, plist = list(search_results.groups())
  else:
    search_results = validome_re.search(xmldoc)
    if search_results:
      plist = ''
      description, cond, excName = list(search_results.groups())
      excName = excName.capitalize()
      if excName=='Valid': cond,excName = '!', 'Message' 
    else:
      raise RuntimeError, "can't parse %s" % xmlfile

  if cond == "":
    method = TestCase.failUnlessContainsInstanceOf
  else:
    method = TestCase.failIfContainsInstanceOf

  params = {}
  if plist:
    for entry in plist.split(','):
      name,value = entry.lstrip().split(':',1)
      params[name] = value

  exc = getattr(feedvalidator, excName)

  description = xmlfile + ": " + description

  return method, description, params, exc

def buildTestCase(xmlfile, xmlBase, description, method, exc, params):
  """factory to create functions which validate `xmlfile`

  the returned function asserts that validating `xmlfile` (an XML file)
  will return a list of exceptions that include an instance of
  `exc` (an Exception class)
  """
  func = lambda self, xmlfile=xmlfile, exc=exc, params=params: \
       method(self, exc, params, feedvalidator.validateString(open(xmlfile).read(), fallback='US-ASCII', base=xmlBase)['loggedEvents'])
  func.__doc__ = description
  return func

def buildTestSuite():
  curdir = os.path.dirname(os.path.abspath(__file__))
  basedir = os.path.split(curdir)[0]
  for xmlfile in sys.argv[1:] or (glob.glob(os.path.join(basedir, 'testcases', '**', '**', '*.xml')) + glob.glob(os.path.join(basedir, 'testcases', 'opml', '**', '*.opml'))):
    method, description, params, exc = getDescription(xmlfile)
    xmlBase  = os.path.abspath(xmlfile).replace(basedir,"http://www.feedvalidator.org")
    testName = 'test_' + xmlBase
    testFunc = buildTestCase(xmlfile, xmlBase, description, method, exc, params)
    instanceMethod = new.instancemethod(testFunc, None, TestCase)
    setattr(TestCase, testName, instanceMethod)
  return unittest.TestLoader().loadTestsFromTestCase(TestCase)
  
if __name__ == '__main__':
  suite = buildTestSuite()
  unittest.main(argv=sys.argv[:1])
