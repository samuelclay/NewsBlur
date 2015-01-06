"""$Id: base.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

"""Base class for output classes"""

from UserList import UserList
import os
LANGUAGE = os.environ.get('LANGUAGE', 'en')
lang = __import__('feedvalidator.i18n.%s' % LANGUAGE, globals(), locals(), LANGUAGE)

from feedvalidator.logging import Info, Warning, Error

class BaseFormatter(UserList):
  def __getitem__(self, i):
    return self.format(self.data[i])

  def getErrors(self):
    return [self.format(msg) for msg in self.data if isinstance(msg,Error)]

  def getWarnings(self):
    return [self.format(msg) for msg in self.data if isinstance(msg,Warning)]

  def getLine(self, event):
    if not event.params.has_key('line'): return ''
    return lang.line % event.params

  def getColumn(self, event):
    if not event.params.has_key('column'): return ''
    return lang.column % event.params

  def getLineAndColumn(self, event):
    line = self.getLine(event)
    if not line: return ''
    column = self.getColumn(event)
    return '%s, %s:' % (line, column)
  
  def getCount(self, event):
    if not event.params.has_key('msgcount'): return ''
    count = int(event.params['msgcount'])
    if count <= 1: return ''
    return lang.occurances % event.params
  
  def getMessageClass(self, event):
    classes = [event.__class__]
    while len(classes):
      if lang.messages.has_key(classes[0]):
        return classes[0]
      classes = classes + list(classes[0].__bases__)
      del classes[0]
    return "Undefined message: %s[%s]" % (event.__class__, event.params)
    
  def getMessage(self, event):
    classes = [event.__class__]
    while len(classes):
      if lang.messages.has_key(classes[0]):
        return lang.messages[classes[0]] % event.params
      classes = classes + list(classes[0].__bases__)
      del classes[0]
    return "Undefined message: %s[%s]" % (event.__class__, event.params)
    
  def format(self, event):
    """returns the formatted representation of a single event"""
    return `event`
