"""$Id: compatibility.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from logging import *

def _must(event):
  return isinstance(event, Error)

def _should(event):
  return isinstance(event, Warning)

def _may(event):
  return isinstance(event, Info)

def A(events):
  return [event for event in events if _must(event)]

def AA(events):
  return [event for event in events if _must(event) or _should(event)]

def AAA(events):
  return [event for event in events if _must(event) or _should(event) or _may(event)]

def AAAA(events):
  return events

def analyze(events, rawdata):
  for event in events:
    if isinstance(event,UndefinedElement):
      if event.params['parent'] == 'root':
        if event.params['element'].lower() in ['html','xhtml:html']:
          return "html"
  return None
