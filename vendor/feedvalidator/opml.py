"""$Id: opml.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from validators import *
from logging import *
import re

#
# Outline Processor Markup Language element.
#
class opml(validatorBase):
  versionList = ['1.0', '1.1']

  def validate(self):
    self.setFeedType(TYPE_OPML)

    if (None,'version') in self.attrs.getNames():
      if self.attrs[(None,'version')] not in opml.versionList:
        self.log(InvalidOPMLVersion({"parent":self.parent.name, "element":self.name, "value":self.attrs[(None,'version')]}))
    elif self.name != 'outlineDocument':
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"version"}))
    
    if 'head' not in self.children:
      self.log(MissingElement({"parent":self.name, "element":"head"}))

    if 'body' not in self.children:
      self.log(MissingElement({"parent":self.name, "element":"body"}))

  def getExpectedAttrNames(self):
    return [(None, u'version')]

  def do_head(self):
    return opmlHead()

  def do_body(self):
    return opmlBody()

class opmlHead(validatorBase):
  def do_title(self):
    return safeHtml(), noduplicates()

  def do_dateCreated(self):
    return rfc822(), noduplicates()

  def do_dateModified(self):
    return rfc822(), noduplicates()

  def do_ownerName(self):
    return safeHtml(), noduplicates()

  def do_ownerEmail(self):
    return email(), noduplicates()

  def do_expansionState(self):
    return commaSeparatedLines(), noduplicates()

  def do_vertScrollState(self):
    return positiveInteger(), nonblank(), noduplicates()

  def do_windowTop(self):
    return positiveInteger(), nonblank(), noduplicates()

  def do_windowLeft(self):
    return positiveInteger(), nonblank(), noduplicates()

  def do_windowBottom(self):
    return positiveInteger(), nonblank(), noduplicates()

  def do_windowRight(self):
    return positiveInteger(), nonblank(), noduplicates()

class commaSeparatedLines(text):
  linenumbers_re=re.compile('^(\d+(,\s*\d+)*)?$')
  def validate(self):
    if not self.linenumbers_re.match(self.value):
      self.log(InvalidExpansionState({"parent":self.parent.name, "element":self.name, "value":self.value}))

class opmlBody(validatorBase):

  def validate(self):
    if 'outline' not in self.children:
      self.log(MissingElement({"parent":self.name, "element":"outline"}))

  def do_outline(self):
    return opmlOutline()

class opmlOutline(validatorBase,rfc822,safeHtml,iso639,rfc2396_full,truefalse):
  versionList = ['RSS', 'RSS1', 'RSS2', 'scriptingNews']

  def getExpectedAttrNames(self):
    return [
      (None, u'category'),
      (None, u'created'),
      (None, u'description'),
      (None, u'htmlUrl'),
      (None, u'isBreakpoint'),
      (None, u'isComment'),
      (None, u'language'),
      (None, u'text'), 
      (None, u'title'),
      (None, u'type'), 
      (None, u'url'),
      (None, u'version'),
      (None, u'xmlUrl'),
    ]

  def validate(self):

    if not (None,'text') in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"text"}))

    if (None,'type') in self.attrs.getNames():
      if self.attrs[(None,'type')].lower() == 'rss':

        if not (None,'xmlUrl') in self.attrs.getNames():
          self.log(MissingXmlURL({"parent":self.parent.name, "element":self.name}))
        if not (None,'title') in self.attrs.getNames():
          self.log(MissingTitleAttr({"parent":self.parent.name, "element":self.name}))

      elif self.attrs[(None,'type')].lower() == 'link':

        if not (None,'url') in self.attrs.getNames():
          self.log(MissingUrlAttr({"parent":self.parent.name, "element":self.name}))

      else:

        self.log(InvalidOutlineType({"parent":self.parent.name, "element":self.name, "value":self.attrs[(None,'type')]}))

    if (None,'version') in self.attrs.getNames():
      if self.attrs[(None,'version')] not in opmlOutline.versionList:
        self.log(InvalidOutlineVersion({"parent":self.parent.name, "element":self.name, "value":self.attrs[(None,'version')]}))
 
    if len(self.attrs)>1 and not (None,u'type') in self.attrs.getNames():
      for name in u'description htmlUrl language title version xmlUrl'.split():
        if (None, name) in self.attrs.getNames():
          self.log(MissingOutlineType({"parent":self.parent.name, "element":self.name}))
          break

    if (None,u'created') in self.attrs.getNames():
      self.name = 'created'
      self.value = self.attrs[(None,'created')]
      rfc822.validate(self)

    if (None,u'description') in self.attrs.getNames():
      self.name = 'description'
      self.value = self.attrs[(None,'description')]
      safeHtml.validate(self)

    if (None,u'htmlUrl') in self.attrs.getNames():
      self.name = 'htmlUrl'
      self.value = self.attrs[(None,'htmlUrl')]
      rfc2396_full.validate(self)

    if (None,u'isBreakpoint') in self.attrs.getNames():
      self.name = 'isBreakpoint'
      self.value = self.attrs[(None,'isBreakpoint')]
      truefalse.validate(self)

    if (None,u'isComment') in self.attrs.getNames():
      self.name = 'isComment'
      self.value = self.attrs[(None,'isComment')]
      truefalse.validate(self)

    if (None,u'language') in self.attrs.getNames():
      self.name = 'language'
      self.value = self.attrs[(None,'language')]
      iso639.validate(self)

    if (None,u'title') in self.attrs.getNames():
      self.name = 'title'
      self.value = self.attrs[(None,'title')]
      safeHtml.validate(self)

    if (None,u'text') in self.attrs.getNames():
      self.name = 'text'
      self.value = self.attrs[(None,'text')]
      safeHtml.validate(self)

    if (None,u'url') in self.attrs.getNames():
      self.name = 'url'
      self.value = self.attrs[(None,'url')]
      rfc2396_full.validate(self)

  def characters(self, string):
    if not self.value:
      if string.strip():
        self.log(UnexpectedText({"element":self.name,"parent":self.parent.name}))
        self.value = string
    
  def do_outline(self):
    return opmlOutline()
