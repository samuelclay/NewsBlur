"""$Id: entry.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from validators import *
from logging import *
from itunes import itunes_item
from extension import extension_entry

#
# pie/echo entry element.
#
class entry(validatorBase, extension_entry, itunes_item):
  def getExpectedAttrNames(self):
    return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'parseType')]

  def prevalidate(self):
    self.links=[]
    self.content=None

  def validate(self):
    if not 'title' in self.children:
      self.log(MissingElement({"parent":self.name, "element":"title"}))
    if not 'author' in self.children and not 'author' in self.parent.children:
      self.log(MissingElement({"parent":self.name, "element":"author"}))
    if not 'id' in self.children:
      self.log(MissingElement({"parent":self.name, "element":"id"}))
    if not 'updated' in self.children:
      self.log(MissingElement({"parent":self.name, "element":"updated"}))

    if self.content:
      if not 'summary' in self.children:
        if self.content.attrs.has_key((None,"src")):
          self.log(MissingSummary({"parent":self.parent.name, "element":self.name}))
        ctype = self.content.type
        if ctype.find('/') > -1 and not (
           ctype.endswith('+xml') or ctype.endswith('/xml') or
           ctype.startswith('text/')):
          self.log(MissingSummary({"parent":self.parent.name, "element":self.name}))
    else:
      if not 'summary' in self.children:
        self.log(MissingTextualContent({"parent":self.parent.name, "element":self.name}))
      for link in self.links:
        if link.rel == 'alternate': break
      else:
        self.log(MissingContentOrAlternate({"parent":self.parent.name, "element":self.name}))

    # can only have one alternate per type
    types={}
    for link in self.links:
      if not link.rel=='alternate': continue
      if not link.type in types: types[link.type]=[]
      if link.hreflang in types[link.type]:
        self.log(DuplicateAtomLink({"parent":self.name, "element":"link", "type":link.type, "hreflang":link.hreflang}))
      else:
        types[link.type] += [link.hreflang]

    if self.itunes: itunes_item.validate(self)

  def do_author(self):
    from author import author
    return author()

  def do_category(self):
    from category import category
    return category()

  def do_content(self):
    from content import content
    self.content=content()
    return self.content, noduplicates()

  def do_contributor(self):
    from author import author
    return author()

  def do_id(self):
    return canonicaluri(), nows(), noduplicates(), unique('id',self.parent,DuplicateEntries)

  def do_link(self):
    from link import link
    self.links += [link()]
    return self.links[-1]

  def do_published(self):
    return rfc3339(), nows(), noduplicates()

  def do_source(self):
    return source(), noduplicates()

  def do_rights(self):
    from content import textConstruct
    return textConstruct(), noduplicates()

  def do_summary(self):
    from content import textConstruct
    return textConstruct(), noduplicates()

  def do_title(self):
    from content import textConstruct
    return textConstruct(), noduplicates()
  
  def do_updated(self):
    return rfc3339(), nows(), noduplicates(), unique('updated',self.parent,DuplicateUpdated)
  
from feed import feed
class source(feed):
  def missingElement(self, params):
    self.log(MissingSourceElement(params))

  def validate(self):
    self.validate_metadata()

  def do_author(self):
    if not 'author' in self.parent.children:
      self.parent.children.append('author')
    return feed.do_author(self)

  def do_entry(self):
    self.log(UndefinedElement({"parent":self.name, "element":"entry"}))
    return eater()
