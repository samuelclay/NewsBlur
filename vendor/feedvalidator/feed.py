"""$Id: feed.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from validators import *
from logging import *
from itunes import itunes_channel
from extension import extension_feed

#
# Atom root element
#
class feed(validatorBase, extension_feed, itunes_channel):
  def prevalidate(self):
    self.links = []
    
  def missingElement(self, params):
    offset = [self.line - self.dispatcher.locator.getLineNumber(),
              self.col  - self.dispatcher.locator.getColumnNumber()]
    self.log(MissingElement(params), offset)

  def validate_metadata(self):
    if not 'title' in self.children:
      self.missingElement({"parent":self.name, "element":"title"})
    if not 'id' in self.children:
      self.missingElement({"parent":self.name, "element":"id"})
    if not 'updated' in self.children:
      self.missingElement({"parent":self.name, "element":"updated"})

    # ensure that there is a link rel="self"
    for link in self.links:
      if link.rel=='self': break
    else:
      offset = [self.line - self.dispatcher.locator.getLineNumber(),
                self.col  - self.dispatcher.locator.getColumnNumber()]
      self.log(MissingSelf({"parent":self.parent.name, "element":self.name}), offset)

    # can only have one alternate per type
    types={}
    for link in self.links:
      if not link.rel=='alternate': continue
      if not link.type in types: types[link.type]={}
      if link.rel in types[link.type]:
        if link.hreflang in types[link.type][link.rel]:
          self.log(DuplicateAtomLink({"parent":self.name, "element":"link", "type":link.type, "hreflang":link.hreflang}))
        else:
          types[link.type][link.rel] += [link.hreflang]
      else:
        types[link.type][link.rel] = [link.hreflang]

    if self.itunes: itunes_channel.validate(self)

  def metadata(self):
    if 'entry' in self.children:
      self.log(MisplacedMetadata({"parent":self.name, "element":self.child}))

  def validate(self):
    if not 'entry' in self.children:
      self.validate_metadata()

  def do_author(self):
    self.metadata()
    from author import author
    return author()

  def do_category(self):
    self.metadata()
    from category import category
    return category()

  def do_contributor(self):
    self.metadata()
    from author import author
    return author()

  def do_generator(self):
    self.metadata()
    from generator import generator
    return generator(), nonblank(), noduplicates()

  def do_id(self):
    self.metadata()
    return canonicaluri(), nows(), noduplicates()

  def do_icon(self):
    self.metadata()
    return nonblank(), nows(), rfc2396(), noduplicates()

  def do_link(self):
    self.metadata()
    from link import link
    self.links += [link()]
    return self.links[-1]

  def do_logo(self):
    self.metadata()
    return nonblank(), nows(), rfc2396(), noduplicates()

  def do_title(self):
    self.metadata()
    from content import textConstruct
    return textConstruct(), noduplicates()
  
  def do_subtitle(self):
    self.metadata()
    from content import textConstruct
    return textConstruct(), noduplicates()
  
  def do_rights(self):
    self.metadata()
    from content import textConstruct
    return textConstruct(), noduplicates()

  def do_updated(self):
    self.metadata()
    return rfc3339(), nows(), noduplicates()

  def do_entry(self):
    if not 'entry' in self.children:
      self.validate_metadata()
    from entry import entry
    return entry()
