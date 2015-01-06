"""$Id: image.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from validators import *
from extension import extension_everywhere

#
# image element.
#
class image(validatorBase, extension_everywhere):
  def getExpectedAttrNames(self):
    return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'resource'),
            (u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'about'),
            (u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'parseType')]
  def validate(self):
    if self.value.strip():
      self.log(UnexpectedText({"parent":self.parent.name, "element":"image"}))
    if self.attrs.has_key((rdfNS,"resource")):
      return # looks like an RSS 1.0 feed
    if not "title" in self.children:
      self.log(MissingTitle({"parent":self.name, "element":"title"}))
    if not "url" in self.children:
      self.log(MissingElement({"parent":self.name, "element":"url"}))
    if self.attrs.has_key((rdfNS,"parseType")):
      return # looks like an RSS 1.1 feed
    if not "link" in self.children:
      self.log(MissingLink({"parent":self.name, "element":"link"}))

  def do_title(self):
    return title(), noduplicates()

  def do_link(self):
    return link(), noduplicates()

  def do_url(self):
    return url(), noduplicates()

  def do_width(self):
    return width(), noduplicates()

  def do_height(self):
    return height(), noduplicates()

  def do_description(self):
    return nonhtml(), noduplicates()
  
  def do_dc_creator(self):
    return text()

  def do_dc_subject(self):
    return text() # duplicates allowed

  def do_dc_date(self):
    return w3cdtf(), noduplicates()

  def do_cc_license(self):
    return eater()

class link(rfc2396_full):
  def validate(self):
    rfc2396_full.validate(self)
    if self.parent.parent.link and self.parent.parent.link != self.value:
      self.log(ImageLinkDoesntMatch({"parent":self.parent.name, "element":self.name}))
 
class url(rfc2396_full):
  def validate(self):
    rfc2396_full.validate(self)
    import re
    ext = self.value.split('.')[-1].lower()
    if re.match("^\w+$", ext) and ext not in ['jpg','jpeg','gif','png']:
      self.log(ImageUrlFormat({"parent":self.parent.name, "element":self.name}))
 
class title(nonhtml, noduplicates):
  def validate(self):
    if not self.value.strip():
      self.log(NotBlank({"parent":self.parent.name, "element":self.name}))
    else:
      self.log(ValidTitle({"parent":self.parent.name, "element":self.name}))
      nonhtml.validate(self)

class width(text, noduplicates):
  def validate(self):
    try:
      w = int(self.value)
      if (w <= 0) or (w > 144):
        self.log(InvalidWidth({"parent":self.parent.name, "element":self.name, "value":self.value}))
      else:
        self.log(ValidWidth({"parent":self.parent.name, "element":self.name}))
    except ValueError:
      self.log(InvalidWidth({"parent":self.parent.name, "element":self.name, "value":self.value}))

class height(text, noduplicates):
  def validate(self):
    try:
      h = int(self.value)
      if (h <= 0) or (h > 400):
        self.log(InvalidHeight({"parent":self.parent.name, "element":self.name, "value":self.value}))
      else:
        self.log(ValidHeight({"parent":self.parent.name, "element":self.name}))
    except ValueError:
      self.log(InvalidHeight({"parent":self.parent.name, "element":self.name, "value":self.value}))
