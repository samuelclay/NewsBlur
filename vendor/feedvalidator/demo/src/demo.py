#!/usr/bin/python

"""$Id: demo.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

import feedvalidator
import sys
import os
import urllib
import urllib2
import urlparse

if __name__ == '__main__':
  # arg 1 is URL to validate
  link = sys.argv[1:] and sys.argv[1] or 'http://www.intertwingly.net/blog/index.atom'
  link = urlparse.urljoin('file:' + urllib.pathname2url(os.getcwd()) + '/', link)
  try:
    link = link.decode('utf-8').encode('idna')
  except:
    pass
  print 'Validating %s' % link

  curdir = os.path.abspath(os.path.dirname(sys.argv[0]))
  basedir = urlparse.urljoin('file:' + curdir, ".")

  try:
    if link.startswith(basedir):
      events = feedvalidator.validateStream(urllib.urlopen(link), firstOccurrenceOnly=1,base=link.replace(basedir,"http://www.feedvalidator.org/"))['loggedEvents']
    else:
      events = feedvalidator.validateURL(link, firstOccurrenceOnly=1)['loggedEvents']
  except feedvalidator.logging.ValidationFailure, vf:
    events = [vf.event]

  # (optional) arg 2 is compatibility level
  # "A" is most basic level
  # "AA" mimics online validator
  # "AAA" is experimental; these rules WILL change or disappear in future versions
  from feedvalidator import compatibility
  filter = sys.argv[2:] and sys.argv[2] or "AA"
  filterFunc = getattr(compatibility, filter)
  events = filterFunc(events)

  from feedvalidator.formatter.text_plain import Formatter
  output = Formatter(events)
  if output:
      print "\n".join(output)
      sys.exit(1)
  else:
      print "No errors or warnings"
