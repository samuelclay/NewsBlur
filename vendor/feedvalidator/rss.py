"""$Id: rss.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from logging import *
from validators import noduplicates

#
# Rss element.  The only valid child element is "channel"
#
class rss(validatorBase):
  def do_channel(self):
    from channel import rss20Channel
    return rss20Channel(), noduplicates()

  def do_access_restriction(self):
    from extension import access_restriction
    return access_restriction(), noduplicates()

  def getExpectedAttrNames(self):
    return [(None, u'version')]

  def prevalidate(self):
    self.setFeedType(TYPE_RSS2) # could be anything in the 0.9x family, don't really care
    self.version = "2.0"
    if (None,'version') not in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"version"}))
    elif [e for e in self.dispatcher.loggedEvents if e.__class__==ValidDoctype]:
      self.version = self.attrs[(None,'version')]
      if self.attrs[(None,'version')]<>'0.91':
        self.log(InvalidDoctype({"parent":self.parent.name, "element":self.name, "attr":"version"}))
    else:
      self.version = self.attrs[(None,'version')]
    
  def validate(self):
    if not "channel" in self.children:
      self.log(MissingElement({"parent":self.name, "element":"channel"}))
