"""$Id: item.py 742 2007-03-23 18:51:49Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 742 $"
__date__ = "$Date: 2007-03-23 18:51:49 +0000 (Fri, 23 Mar 2007) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from validators import *
from logging import *
from itunes import itunes_item
from extension import *

#
# item element.
#
class item(validatorBase, extension_item, itunes_item):
  def validate(self):
    if not "link" in self.children:
      self.log(MissingItemLink({"parent":self.name, "element":"link"}))
    if not "title" in self.children:
      self.log(MissingItemTitle({"parent":self.name, "element":"title"}))
    if (not "title" in self.children) and (not "description" in self.children):
      self.log(ItemMustContainTitleOrDescription({}))
    if not "guid" in self.children:
      if self.getFeedType() == TYPE_RSS2:
        if self.parent.parent.version.startswith("2."):
          self.log(MissingGuid({"parent":self.name, "element":"guid"}))

    if self.itunes: itunes_item.validate(self)
        
  def do_link(self):
    return rfc2396_full(), noduplicates()
  
  def do_title(self):
    return nonhtml(), noduplicates()

  def do_description(self):
    if self.getFeedType() == TYPE_RSS2:
      if self.parent.parent.version == "0.91":
        return nonhtml(), noduplicates()
    return safeHtml(), noduplicates()

  def do_content_encoded(self):
    return safeHtml(), noduplicates()

  def do_xhtml_body(self):
    if self.getFeedType() == TYPE_RSS2:
      self.log(DuplicateDescriptionSemantics({"element":"xhtml:body"}))
    return htmlEater().setElement('xhtml:body',{},self)

  def do_atom_id(self):
    if "guid" in self.children:
      self.log(DuplicateItemSemantics({"core":"guid", "ext":"atom:id"}))
    return rfc2396_full(), noduplicates(), unique('atom_id',self.parent)

  def do_atom_link(self):
    from link import link
    return link()

  def do_atom_title(self):
    from content import content
    return content(), noduplicates()

  def do_atom_summary(self):
    from content import textConstruct
    return textConstruct(), noduplicates()

  def do_atom_author(self):
    from author import author
    return author(), noduplicates()

  def do_atom_contributor(self):
    from author import author
    return author()

  def do_atom_content(self):
    from content import content
    return content()

  def do_atom_published(self):
    if "published" in self.children:
      self.log(DuplicateItemSemantics({"core":"pubDate", "ext":"atom:published"}))
    return rfc3339(), noduplicates()
  
  def do_atom_updated(self):
    return rfc3339(), noduplicates()

  def do_dc_creator(self):
    if self.child.find('.')<0 and "author" in self.children:
      self.log(DuplicateItemSemantics({"core":"author", "ext":"dc:creator"}))
    return text() # duplicates allowed

  def do_dc_subject(self):
    if self.child.find('.')<0 and "category" in self.children:
      self.log(DuplicateItemSemantics({"core":"category", "ext":"dc:subject"}))
    return text() # duplicates allowed

  def do_dc_date(self):
    if self.child.find('.')<0 and "pubDate" in self.children:
      self.log(DuplicateItemSemantics({"core":"pubDate", "ext":"dc:date"}))
    return w3cdtf()

  def do_cc_license(self):
    if "creativeCommons_license" in self.children:
      self.log(DuplicateItemSemantics({"core":"creativeCommons:license", "ext":"cc:license"}))
    return eater()

  def do_creativeCommons_license(self):
    if "cc_license" in self.children:
      self.log(DuplicateItemSemantics({"core":"creativeCommons:license", "ext":"cc:license"}))
    return rfc2396_full()

class rss20Item(item, extension_rss20_item):
  def do_comments(self):
    return rfc2396_full(), noduplicates()

  def do_enclosure(self):
    return enclosure(), noduplicates(DuplicateEnclosure)
  
  def do_pubDate(self):
    if "dc_date" in self.children:
      self.log(DuplicateItemSemantics({"core":"pubDate", "ext":"dc:date"}))
    if "atom_published" in self.children:
      self.log(DuplicateItemSemantics({"core":"pubDate", "ext":"atom:published"}))
    return rfc822(), noduplicates()

  def do_author(self):
    if "dc_creator" in self.children:
      self.log(DuplicateItemSemantics({"core":"author", "ext":"dc:creator"}))
    return email(), noduplicates()

  def do_category(self):
    if "dc_subject" in self.children:
      self.log(DuplicateItemSemantics({"core":"category", "ext":"dc:subject"}))
    return category()

  def do_guid(self):
    if "atom_id" in self.children:
      self.log(DuplicateItemSemantics({"core":"guid", "ext":"atom:id"}))
    return guid(), noduplicates(), unique('guid',self.parent)

  def do_source(self):
    if "dc_source" in self.children:
      self.log(DuplicateItemSemantics({"core":"source", "ext":"dc:source"}))
    return source(), noduplicates()

class rss10Item(item, extension_rss10_item):
  def validate(self):
    if not "link" in self.children:
      self.log(MissingItemLink({"parent":self.name, "element":"link"}))
    if not "title" in self.children:
      self.log(MissingItemTitle({"parent":self.name, "element":"title"}))

  def getExpectedAttrNames(self):
      return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'about')]

  def do_rdfs_label(self):
      return text()

  def do_rdfs_comment(self):
      return text()

  def prevalidate(self):
    if self.attrs.has_key((rdfNS,"about")):
      about = self.attrs[(rdfNS,"about")]
      if not "abouts" in self.dispatcher.__dict__:
        self.dispatcher.__dict__["abouts"] = []
      if about in self.dispatcher.__dict__["abouts"]:
        self.log(DuplicateValue({"parent":self.name, "element":"rdf:about", "value":about}))
      else:
        self.dispatcher.__dict__["abouts"].append(about)


#
# items element.
#
class items(validatorBase):
  from root import rss11_namespace as rss11_ns

  def getExpectedAttrNames(self):
    return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'parseType')]

  def do_item(self):
    if self.rss11_ns not in self.dispatcher.defaultNamespaces:
      self.log(UndefinedElement({"element":"item","parent":"items"}))
    return rss10Item()

  def do_rdf_Seq(self):
    if self.rss11_ns in self.dispatcher.defaultNamespaces:
      self.log(UndefinedElement({"element":"rdf:Seq","parent":"items"}))
    return rdfSeq()

class rdfSeq(validatorBase):
  def do_rdf_li(self):
    return rdfLi()

class rdfLi(validatorBase):
  def getExpectedAttrNames(self):
    return [(None,u'resource'),
            (u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'resource')]

class category(nonhtml):
  def getExpectedAttrNames(self):
    return [(None, u'domain')]

class source(nonhtml, httpURLMixin):
  def getExpectedAttrNames(self):
    return [(None, u'url')]
  def prevalidate(self):
    try:
      self.validateHttpURL(None, 'url')
    except KeyError:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":'url'}))
    return text.prevalidate(self)

class enclosure(validatorBase, httpURLMixin):
  from validators import mime_re
  def getExpectedAttrNames(self):
    return [(None, u'url'), (None, u'length'), (None, u'type')]
  def prevalidate(self):
    try:
      if int(self.attrs.getValue((None, 'length'))) <= 0:
        self.log(InvalidIntegerAttribute({"parent":self.parent.name, "element":self.name, "attr":'length'}))
      else:
        self.log(ValidIntegerAttribute({"parent":self.parent.name, "element":self.name, "attr":'length'}))
    except KeyError:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":'length'}))
    except ValueError:
      self.log(InvalidIntegerAttribute({"parent":self.parent.name, "element":self.name, "attr":'length'}))

    try:
      if not self.mime_re.match(self.attrs.getValue((None, 'type'))):
        self.log(InvalidMIMEAttribute({"parent":self.parent.name, "element":self.name, "attr":'type'}))
      else:
        self.log(ValidMIMEAttribute({"parent":self.parent.name, "element":self.name, "attr":'type'}))
    except KeyError:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":'type'}))

    if self.attrs.has_key((None,u"url")):
      self.validateHttpURL(None, 'url')
      if hasattr(self.parent,'setEnclosure'): 
        self.parent.setEnclosure(self.attrs.getValue((None, 'url')))
    else:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":'url'}))

    return validatorBase.prevalidate(self)

class guid(rfc2396_full, noduplicates):
  def getExpectedAttrNames(self):
    return [(None, u'isPermaLink')]

  def validate(self):
    isPermalink = 1
    try:
      isPermalinkStr = self.attrs.getValue((None, 'isPermaLink'))
      if isPermalinkStr not in ('true', 'false'):
        self.log(InvalidBooleanAttribute({"parent":self.parent.name, "element":self.name, "attr":"isPermaLink"}))
      else:
        self.log(ValidBooleanAttribute({"parent":self.parent.name, "element":self.name, "attr":"isPermaLink"}))
      isPermalink = (isPermalinkStr == 'true')
    except KeyError:
      pass
    if isPermalink:
      if not(rfc2396.validate(self, InvalidHttpGUID, ValidHttpGUID)):
        return 0
      else:
        lu = self.value.lower()
        if lu.startswith("tag:") or lu.startswith("urn:uuid:"):
          self.log(InvalidPermalink({"parent":self.parent.name, "element":self.name}))
          return 0
        else:
          return 1
    elif len(self.value)<9 and self.value.isdigit():
      self.log(NotSufficientlyUnique({"parent":self.parent.name, "element":self.name, "value":self.value}))
      return noduplicates.validate(self)
    else:
      self.log(ValidHttpGUID({"parent":self.parent.name, "element":self.name}))
      return noduplicates.validate(self)
