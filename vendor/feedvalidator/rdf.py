"""$Id: rdf.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from logging import *
from validators import rdfAbout, noduplicates, text, eater
from root import rss11_namespace as rss11_ns
from extension import extension_everywhere

rdfNS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

#
# rdf:RDF element.  The valid children include "channel", "item", "textinput", "image"
#
class rdf(validatorBase,object):

  def do_rss090_channel(self):
    from channel import channel
    self.dispatcher.defaultNamespaces.append("http://my.netscape.com/rdf/simple/0.9/")
    return channel(), noduplicates()

  def do_channel(self):
    from channel import rss10Channel
    return rdfAbout(), rss10Channel(), noduplicates()

  def _is_090(self):
    return "http://my.netscape.com/rdf/simple/0.9/" in self.dispatcher.defaultNamespaces

  def _withAbout(self,v):
    if self._is_090():
      return v
    else:
      return v, rdfAbout()
      
  def do_item(self):
    from item import rss10Item
    return self._withAbout(rss10Item())

  def do_textinput(self):
    from textInput import textInput
    return self._withAbout(textInput())

  def do_image(self):
    return self._withAbout(rss10Image())
  
  def do_cc_License(self):
    return eater()

  def do_taxo_topic(self):
    return eater()

  def do_rdf_Description(self):
    return eater()

  def prevalidate(self):
    self.setFeedType(TYPE_RSS1)
    
  def validate(self):
    if not "channel" in self.children and not "rss090_channel" in self.children:
      self.log(MissingElement({"parent":self.name.replace('_',':'), "element":"channel"}))

from validators import rfc2396_full

class rss10Image(validatorBase, extension_everywhere):
  def validate(self):
    if not "title" in self.children:
      self.log(MissingTitle({"parent":self.name, "element":"title"}))
    if not "link" in self.children:
      self.log(MissingLink({"parent":self.name, "element":"link"}))
    if not "url" in self.children:
      self.log(MissingElement({"parent":self.name, "element":"url"}))

  def do_title(self):
    from image import title
    return title(), noduplicates()

  def do_link(self):
    return rfc2396_full(), noduplicates()

  def do_url(self):
    return rfc2396_full(), noduplicates()

  def do_dc_creator(self):
    return text()

  def do_dc_subject(self):
    return text() # duplicates allowed

  def do_dc_date(self):
    from validators import w3cdtf
    return w3cdtf(), noduplicates()

  def do_cc_license(self):
    return eater()

#
# This class performs RSS 1.x specific validations on extensions.
#
class rdfExtension(validatorBase):
  def __init__(self, qname, literal=False):
    validatorBase.__init__(self)
    self.qname=qname
    self.literal=literal

  def textOK(self):
    pass

  def setElement(self, name, attrs, parent):
    validatorBase.setElement(self, name, attrs, parent)

    if attrs.has_key((rdfNS,"parseType")):
      if attrs[(rdfNS,"parseType")] == "Literal": self.literal=True

    if not self.literal:

      # ensure no rss11 children
      if self.qname==rss11_ns:
        from logging import UndefinedElement
        self.log(UndefinedElement({"parent":parent.name, "element":name}))

      # no duplicate rdf:abouts
      if attrs.has_key((rdfNS,"about")):
        about = attrs[(rdfNS,"about")]
        if not "abouts" in self.dispatcher.__dict__:
          self.dispatcher.__dict__["abouts"] = []
        if about in self.dispatcher.__dict__["abouts"]:
          self.log(DuplicateValue(
            {"parent":parent.name, "element":"rdf:about", "value":about}))
        else:
          self.dispatcher.__dict__["abouts"].append(about)

  def getExpectedAttrNames(self):
    # no rss11 attributes
    if self.literal or not self.attrs: return self.attrs.keys()
    return [(ns,n) for ns,n in self.attrs.keys() if ns!=rss11_ns]

  def validate(self):
    # rdflib 2.0.5 does not catch mixed content errors
    if self.value.strip() and self.children and not self.literal:
      self.log(InvalidRDF({"message":"mixed content"}))

  def startElementNS(self, name, qname, attrs):
    # ensure element is "namespace well formed"
    if name.find(':') != -1:
      from logging import MissingNamespace
      self.log(MissingNamespace({"parent":self.name, "element":name}))

    # ensure all attribute namespaces are properly defined
    for (namespace,attr) in attrs.keys():
      if ':' in attr and not namespace:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":self.name, "element":attr}))

    # eat children
    self.children.append((qname,name))
    self.push(rdfExtension(qname, self.literal), name, attrs)

  def characters(self, string):
    if not self.literal: validatorBase.characters(self, string)
