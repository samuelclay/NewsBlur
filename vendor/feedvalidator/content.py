"""$Id: content.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from validators import *
from logging import *
#
# item element.
#
class textConstruct(validatorBase,rfc2396,nonhtml):
  from validators import mime_re
  import re

  def getExpectedAttrNames(self):
      return [(None, u'type'),(None, u'src')]

  def normalizeWhitespace(self):
      pass

  def maptype(self):
    if self.type.find('/') > -1:
      self.log(InvalidTextType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.type}))

  def prevalidate(self):
    if self.attrs.has_key((None,"src")):
      self.type=''
    else:
      self.type='text'
      if self.getFeedType() == TYPE_RSS2 and self.name != 'atom_summary':
        self.log(DuplicateDescriptionSemantics({"element":self.name}))

    if self.attrs.has_key((None,"type")):
      self.type=self.attrs.getValue((None,"type"))
      if not self.type:
        self.log(AttrNotBlank({"parent":self.parent.name, "element":self.name, "attr":"type"}))

    self.maptype()

    if self.attrs.has_key((None,"src")):
      self.children.append(True) # force warnings about "mixed" content
      self.value=self.attrs.getValue((None,"src"))
      rfc2396.validate(self, errorClass=InvalidURIAttribute, extraParams={"attr": "src"})
      self.value=""

      if not self.attrs.has_key((None,"type")):
        self.log(MissingTypeAttr({"parent":self.parent.name, "element":self.name, "attr":"type"}))

    if self.type in ['text','html','xhtml'] and not self.attrs.has_key((None,"src")):
      pass
    elif self.type and not self.mime_re.match(self.type):
      self.log(InvalidMIMEType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.type}))
    else:
      self.log(ValidMIMEAttribute({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.type}))
    
    if not self.xmlLang:
      self.log(MissingDCLanguage({"parent":self.name, "element":"xml:lang"}))

  def validate(self):
    if self.type in ['text','xhtml']:
      if self.type=='xhtml':
        nonhtml.validate(self, NotInline)
      else:
        nonhtml.validate(self, ContainsUndeclaredHTML)
    else:
      if self.type.find('/') > -1 and not (
         self.type.endswith('+xml') or self.type.endswith('/xml') or
         self.type.startswith('text/')):
        import base64
        try:
          self.value=base64.decodestring(self.value)
          if self.type.endswith('/html'): self.type='html'
        except:
          self.log(NotBase64({"parent":self.parent.name, "element":self.name,"value":self.value}))

      if self.type=='html' or self.type.endswith("/html"):
        self.validateSafe(self.value)

        if self.type.endswith("/html"):
          if self.value.find("<html")<0 and not self.attrs.has_key((None,"src")):
            self.log(HtmlFragment({"parent":self.parent.name, "element":self.name,"value":self.value, "type":self.type}))
      else:
        nonhtml.validate(self, ContainsUndeclaredHTML)

    if not self.value and len(self.children)==0 and not self.attrs.has_key((None,"src")):
       self.log(NotBlank({"parent":self.parent.name, "element":self.name}))

  def textOK(self):
    if self.children: validatorBase.textOK(self)

  def characters(self, string):
    for c in string:
      if 0x80 <= ord(c) <= 0x9F or c == u'\ufffd':
        from validators import BadCharacters
        self.log(BadCharacters({"parent":self.parent.name, "element":self.name}))
    if (self.type=='xhtml') and string.strip() and not self.value.strip():
      self.log(MissingXhtmlDiv({"parent":self.parent.name, "element":self.name}))
    validatorBase.characters(self,string)

  def startElementNS(self, name, qname, attrs):
    if (self.type<>'xhtml') and not (
        self.type.endswith('+xml') or self.type.endswith('/xml')):
      self.log(UndefinedElement({"parent":self.name, "element":name}))

    if self.type=="xhtml":
      if name<>'div' and not self.value.strip():
        self.log(MissingXhtmlDiv({"parent":self.parent.name, "element":self.name}))
      elif qname not in ["http://www.w3.org/1999/xhtml"]:
        self.log(NotHtml({"parent":self.parent.name, "element":self.name, "message":"unexpected namespace: %s" % qname}))

    if self.type=="application/xhtml+xml":
      if name<>'html':
        self.log(HtmlFragment({"parent":self.parent.name, "element":self.name,"value":self.value, "type":self.type}))
      elif qname not in ["http://www.w3.org/1999/xhtml"]:
        self.log(NotHtml({"parent":self.parent.name, "element":self.name, "message":"unexpected namespace: %s" % qname}))

    if self.attrs.has_key((None,"mode")):
      if self.attrs.getValue((None,"mode")) == 'escaped':
        self.log(NotEscaped({"parent":self.parent.name, "element":self.name}))

    if name=="div" and qname=="http://www.w3.org/1999/xhtml":
      handler=diveater()
    else:
      handler=eater()
    self.children.append(handler)
    self.push(handler, name, attrs)

# treat xhtml:div as part of the content for purposes of detecting escaped html
class diveater(eater):
  def __init__(self):
    eater.__init__(self)
    self.mixed = False
  def textOK(self):
    pass
  def characters(self, string):
    validatorBase.characters(self, string)
  def startElementNS(self, name, qname, attrs):
    if not qname:
      self.log(MissingNamespace({"parent":"xhtml:div", "element":name}))
    self.mixed = True
    eater.startElementNS(self, name, qname, attrs)
  def validate(self):
    if not self.mixed: self.parent.value += self.value

class content(textConstruct):
  def maptype(self):
    if self.type == 'multipart/alternative':
      self.log(InvalidMIMEType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.type}))
