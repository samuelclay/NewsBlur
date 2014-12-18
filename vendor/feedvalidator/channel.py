"""$Id: channel.py 711 2006-10-25 00:43:41Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 711 $"
__date__ = "$Date: 2006-10-25 00:43:41 +0000 (Wed, 25 Oct 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from logging import *
from validators import *
from itunes import itunes_channel
from extension import *

#
# channel element.
#
class channel(validatorBase, rfc2396, extension_channel, itunes_channel):
  def __init__(self):
    self.link=None
    validatorBase.__init__(self)
  def validate(self):
    if not "description" in self.children:
      self.log(MissingDescription({"parent":self.name,"element":"description"}))
    if not "link" in self.children:
      self.log(MissingLink({"parent":self.name, "element":"link"}))
    if not "title" in self.children:
      self.log(MissingTitle({"parent":self.name, "element":"title"}))
    if not "dc_language" in self.children and not "language" in self.children:
      if not self.xmlLang:
        self.log(MissingDCLanguage({"parent":self.name, "element":"language"}))
    if self.children.count("image") > 1:
      self.log(DuplicateElement({"parent":self.name, "element":"image"}))
    if self.children.count("textInput") > 1:
      self.log(DuplicateElement({"parent":self.name, "element":"textInput"}))
    if self.children.count("skipHours") > 1:
      self.log(DuplicateElement({"parent":self.name, "element":"skipHours"}))
    if self.children.count("skipDays") > 1:
      self.log(DuplicateElement({"parent":self.name, "element":"skipDays"}))
    if self.attrs.has_key((rdfNS,"about")):
      self.value = self.attrs.getValue((rdfNS, "about"))
      rfc2396.validate(self, extraParams={"attr": "rdf:about"})
      if not "items" in self.children:
        self.log(MissingElement({"parent":self.name, "element":"items"}))

    if self.itunes: itunes_channel.validate(self)

  def do_image(self):
    from image import image
    return image(), noduplicates()

  def do_textInput(self):
    from textInput import textInput
    return textInput(), noduplicates()

  def do_textinput(self):
    if not self.attrs.has_key((rdfNS,"about")):
      # optimize for RSS 2.0.  If it is not valid RDF, assume that it is
      # a simple misspelling (in other words, the error message will be
      # less than helpful on RSS 1.0 feeds.
      self.log(UndefinedElement({"parent":self.name, "element":"textinput"}))
    return eater(), noduplicates()
  
  def do_link(self):
    return link(), noduplicates()

  def do_title(self):
    return nonhtml(), noduplicates(), nonblank()

  def do_description(self):
    return nonhtml(), noduplicates()

  def do_blink(self):
    return blink(), noduplicates()

  def do_atom_author(self):
    from author import author
    return author()

  def do_atom_category(self):
    from category import category
    return category()

  def do_atom_contributor(self):
    from author import author
    return author()

  def do_atom_generator(self):
    from generator import generator
    return generator(), nonblank(), noduplicates()

  def do_atom_id(self):
    return rfc2396_full(), noduplicates()

  def do_atom_icon(self):
    return nonblank(), rfc2396(), noduplicates()

  def do_atom_link(self):
    from link import link
    return link()

  def do_atom_logo(self):
    return nonblank(), rfc2396(), noduplicates()

  def do_atom_title(self):
    from content import textConstruct
    return textConstruct(), noduplicates()
  
  def do_atom_subtitle(self):
    from content import textConstruct
    return textConstruct(), noduplicates()
  
  def do_atom_rights(self):
    from content import textConstruct
    return textConstruct(), noduplicates()

  def do_atom_updated(self):
    return rfc3339(), noduplicates()

  def do_dc_creator(self):
    if "managingEditor" in self.children:
      self.log(DuplicateSemantics({"core":"managingEditor", "ext":"dc:creator"}))
    return text() # duplicates allowed

  def do_dc_subject(self):
    if "category" in self.children:
      self.log(DuplicateSemantics({"core":"category", "ext":"dc:subject"}))
    return text() # duplicates allowed

  def do_dc_date(self):
    if "pubDate" in self.children:
      self.log(DuplicateSemantics({"core":"pubDate", "ext":"dc:date"}))
    return w3cdtf(), noduplicates()

  def do_cc_license(self):
    if "creativeCommons_license" in self.children:
      self.log(DuplicateSemantics({"core":"creativeCommons:license", "ext":"cc:license"}))
    return eater()

  def do_creativeCommons_license(self):
    if "cc_license" in self.children:
      self.log(DuplicateSemantics({"core":"creativeCommons:license", "ext":"cc:license"}))
    return rfc2396_full()

class rss20Channel(channel):
  def do_item(self):
    from item import rss20Item
    return rss20Item()

  def do_category(self):
    return category()

  def do_cloud(self):
    return cloud(), noduplicates()
  
  do_rating = validatorBase.leaf # TODO test cases?!?

  def do_ttl(self):
    return positiveInteger(), nonblank(), noduplicates()
  
  def do_docs(self):
    return rfc2396_full(), noduplicates()
    
  def do_generator(self):
    if "admin_generatorAgent" in self.children:
      self.log(DuplicateSemantics({"core":"generator", "ext":"admin:generatorAgent"}))
    return text(), noduplicates()

  def do_pubDate(self):
    if "dc_date" in self.children:
      self.log(DuplicateSemantics({"core":"pubDate", "ext":"dc:date"}))
    return rfc822(), noduplicates()

  def do_managingEditor(self):
    if "dc_creator" in self.children:
      self.log(DuplicateSemantics({"core":"managingEditor", "ext":"dc:creator"}))
    return email(), noduplicates()

  def do_webMaster(self):
    if "dc_publisher" in self.children:
      self.log(DuplicateSemantics({"core":"webMaster", "ext":"dc:publisher"}))
    return email(), noduplicates()

  def do_language(self):
    if "dc_language" in self.children:
      self.log(DuplicateSemantics({"core":"language", "ext":"dc:language"}))
    return iso639(), noduplicates()

  def do_copyright(self):
    if "dc_rights" in self.children:
      self.log(DuplicateSemantics({"core":"copyright", "ext":"dc:rights"}))
    return nonhtml(), noduplicates()

  def do_lastBuildDate(self):
    if "dcterms_modified" in self.children:
      self.log(DuplicateSemantics({"core":"lastBuildDate", "ext":"dcterms:modified"}))
    return rfc822(), noduplicates()

  def do_skipHours(self):
    from skipHours import skipHours
    return skipHours()

  def do_skipDays(self):
    from skipDays import skipDays
    return skipDays()

class rss10Channel(channel):
  def getExpectedAttrNames(self):
    return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'about'),
      (u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'about')]
 
  def prevalidate(self):
    if self.attrs.has_key((rdfNS,"about")):
      if not "abouts" in self.dispatcher.__dict__:
        self.dispatcher.__dict__["abouts"] = []
      self.dispatcher.__dict__["abouts"].append(self.attrs[(rdfNS,"about")])

  def do_items(self): # this actually should be from the rss1.0 ns
    if not self.attrs.has_key((rdfNS,"about")):
      self.log(MissingAttribute({"parent":self.name, "element":self.name, "attr":"rdf:about"}))
    from item import items
    return items(), noduplicates()

  def do_rdfs_label(self):
      return text()

  def do_rdfs_comment(self):
      return text()


class link(rfc2396_full):
  def validate(self):
    self.parent.link = self.value
    rfc2396_full.validate(self)
 
class blink(text):
  def validate(self):
    self.log(NoBlink({}))
 
class category(nonhtml):
  def getExpectedAttrNames(self):
    return [(None, u'domain')]

class cloud(validatorBase):
  def getExpectedAttrNames(self):
    return [(None, u'domain'), (None, u'path'), (None, u'registerProcedure'),
      (None, u'protocol'), (None, u'port')]
  def prevalidate(self):
    if (None, 'domain') not in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"domain"}))
    else:
      self.log(ValidCloud({"parent":self.parent.name, "element":self.name, "attr":"domain"}))

    try:
      if int(self.attrs.getValue((None, 'port'))) <= 0:
        self.log(InvalidIntegerAttribute({"parent":self.parent.name, "element":self.name, "attr":'port'}))
      else:
        self.log(ValidCloud({"parent":self.parent.name, "element":self.name, "attr":'port'}))
    except KeyError:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":'port'}))
    except ValueError:
      self.log(InvalidIntegerAttribute({"parent":self.parent.name, "element":self.name, "attr":'port'}))

    if (None, 'path') not in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"path"}))
    else:
      self.log(ValidCloud({"parent":self.parent.name, "element":self.name, "attr":"path"}))

    if (None, 'registerProcedure') not in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"registerProcedure"}))
    else:
      self.log(ValidCloud({"parent":self.parent.name, "element":self.name, "attr":"registerProcedure"}))

    if (None, 'protocol') not in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"protocol"}))
    else:
      self.log(ValidCloud({"parent":self.parent.name, "element":self.name, "attr":"protocol"}))
    ## TODO - is there a list of accepted protocols for this thing?

    return validatorBase.prevalidate(self)
