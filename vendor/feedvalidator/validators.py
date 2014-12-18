"""$Id: validators.py 749 2007-04-02 15:45:49Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 749 $"
__date__ = "$Date: 2007-04-02 15:45:49 +0000 (Mon, 02 Apr 2007) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase
from logging import *
import re, time, datetime
from uri import canonicalForm, urljoin
from rfc822 import AddressList, parsedate

rdfNS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

#
# Valid mime type
#
mime_re = re.compile('[^\s()<>,;:\\"/[\]?=]+/[^\s()<>,;:\\"/[\]?=]+(\s*;\s*[^\s()<>,;:\\"/[\]?=]+=("(\\"|[^"])*"|[^\s()<>,;:\\"/[\]?=]+))*$')

#
# Extensibility hook: logic varies based on type of feed
#
def any(self, name, qname, attrs):
  if self.getFeedType() != TYPE_RSS1:
    return eater()
  else:
    from rdf import rdfExtension
    return rdfExtension(qname)

#
# This class simply eats events.  Useful to prevent cascading of errors
#
class eater(validatorBase):
  def getExpectedAttrNames(self):
    return self.attrs.getNames()

  def characters(self, string):
    for c in string:
      if 0x80 <= ord(c) <= 0x9F or c == u'\ufffd':
        from validators import BadCharacters
        self.log(BadCharacters({"parent":self.parent.name, "element":self.name}))

  def startElementNS(self, name, qname, attrs):
    # RSS 2.0 arbitrary restriction on extensions
    feedtype=self.getFeedType()
    if (not qname) and feedtype and (feedtype==TYPE_RSS2) and self.name.find('_')>=0:
       from logging import NotInANamespace
       self.log(NotInANamespace({"parent":self.name, "element":name, "namespace":'""'}))

    # ensure element is "namespace well formed"
    if name.find(':') != -1:
      from logging import MissingNamespace
      self.log(MissingNamespace({"parent":self.name, "element":name}))

    # ensure all attribute namespaces are properly defined
    for (namespace,attr) in attrs.keys():
      if ':' in attr and not namespace:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":self.name, "element":attr}))
      for c in attrs.get((namespace,attr)):
        if 0x80 <= ord(c) <= 0x9F or c == u'\ufffd':
          from validators import BadCharacters
          self.log(BadCharacters({"parent":name, "element":attr}))

    # eat children
    self.push(eater(), name, attrs)

from HTMLParser import HTMLParser, HTMLParseError
class HTMLValidator(HTMLParser):
  htmltags = [
    "a", "abbr", "acronym", "address", "applet", "area", "b", "base",
    "basefont", "bdo", "big", "blockquote", "body", "br", "button", "caption",
    "center", "cite", "code", "col", "colgroup", "dd", "del", "dir", "div",
    "dfn", "dl", "dt", "em", "fieldset", "font", "form", "frame", "frameset",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "head", "hr", "html", "i", "iframe", "img", "input", "ins",
    "isindex", "kbd", "label", "legend", "li", "link", "map", "menu", "meta",
    "noframes", "noscript", "object", "ol", "optgroup", "option", "p",
    "param", "pre", "q", "s", "samp", "script", "select", "small", "span",
    "strike", "strong", "style", "sub", "sup", "table", "tbody", "td",
    "textarea", "tfoot", "th", "thead", "title", "tr", "tt", "u", "ul",
    "var", "xmp", "plaintext", "embed", "comment", "listing"]

  acceptable_elements = ['a', 'abbr', 'acronym', 'address', 'area', 'b', 'big',
    'blockquote', 'br', 'button', 'caption', 'center', 'cite', 'code', 'col',
    'colgroup', 'dd', 'del', 'dfn', 'dir', 'div', 'dl', 'dt', 'em', 'fieldset',
    'font', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'i', 'img',
    'input', 'ins', 'kbd', 'label', 'legend', 'li', 'map', 'menu', 'ol',
    'optgroup', 'option', 'p', 'pre', 'q', 's', 'samp', 'select', 'small',
    'span', 'strike', 'strong', 'sub', 'sup', 'table', 'tbody', 'td',
    'textarea', 'tfoot', 'th', 'thead', 'tr', 'tt', 'u', 'ul', 'var',
    'noscript']

  acceptable_attributes = ['abbr', 'accept', 'accept-charset', 'accesskey',
    'action', 'align', 'alt', 'axis', 'bgcolor', 'border', 'cellpadding',
    'cellspacing', 'char', 'charoff', 'charset', 'checked', 'cite', 'class',
    'clear', 'cols', 'colspan', 'color', 'compact', 'coords', 'datetime',
    'dir', 'disabled', 'enctype', 'face', 'for', 'frame', 'headers', 'height',
    'href', 'hreflang', 'hspace', 'id', 'ismap', 'label', 'lang', 'longdesc',
    'maxlength', 'media', 'method', 'multiple', 'name', 'nohref', 'noshade',
    'nowrap', 'prompt', 'readonly', 'rel', 'rev', 'rows', 'rowspan', 'rules',
    'scope', 'selected', 'shape', 'size', 'span', 'src', 'start', 'summary',
    'tabindex', 'target', 'title', 'type', 'usemap', 'valign', 'value',
    'vspace', 'width', 'xml:lang', 'xmlns']

  acceptable_css_properties = ['azimuth', 'background', 'background-color',
    'border', 'border-bottom', 'border-bottom-color', 'border-bottom-style',
    'border-bottom-width', 'border-collapse', 'border-color', 'border-left',
    'border-left-color', 'border-left-style', 'border-left-width',
    'border-right', 'border-right-color', 'border-right-style',
    'border-right-width', 'border-spacing', 'border-style', 'border-top',
    'border-top-color', 'border-top-style', 'border-top-width', 'border-width',
    'clear', 'color', 'cursor', 'direction', 'display', 'elevation', 'float',
    'font', 'font-family', 'font-size', 'font-style', 'font-variant',
    'font-weight', 'height', 'letter-spacing', 'line-height', 'margin',
    'margin-bottom', 'margin-left', 'margin-right', 'margin-top', 'overflow',
    'padding', 'padding-bottom', 'padding-left', 'padding-right',
    'padding-top', 'pause', 'pause-after', 'pause-before', 'pitch',
    'pitch-range', 'richness', 'speak', 'speak-header', 'speak-numeral',
    'speak-punctuation', 'speech-rate', 'stress', 'text-align',
    'text-decoration', 'text-indent', 'unicode-bidi', 'vertical-align',
    'voice-family', 'volume', 'white-space', 'width']

  # survey of common keywords found in feeds
  acceptable_css_keywords = ['aqua', 'auto', 'black', 'block', 'blue', 'bold',
    'both', 'bottom', 'brown', 'center', 'collapse', 'dashed', 'dotted',
    'fuchsia', 'gray', 'green', '!important', 'italic', 'left', 'lime',
    'maroon', 'medium', 'none', 'navy', 'normal', 'nowrap', 'olive',
    'pointer', 'purple', 'red', 'right', 'solid', 'silver', 'teal', 'top',
    'transparent', 'underline', 'white', 'yellow']

  valid_css_values = re.compile('^(#[0-9a-f]+|rgb\(\d+%?,\d*%?,?\d*%?\)?|' +
    '\d?\.?\d?\d(cm|em|ex|in|mm|pc|pt|px|%|,|\))?)$')

  def log(self,msg):
    offset = [self.element.line + self.getpos()[0] - 1 -
              self.element.dispatcher.locator.getLineNumber(),
              -self.element.dispatcher.locator.getColumnNumber()]
    self.element.log(msg, offset)

  def __init__(self,value,element):
    self.element=element
    self.valid = True
    HTMLParser.__init__(self)
    if value.lower().find('<?import ') >= 0:
      self.log(SecurityRisk({"parent":self.element.parent.name, "element":self.element.name, "tag":"?import"}))
    try:
      self.feed(value)
      self.close()
      if self.valid:
        self.log(ValidHtml({"parent":self.element.parent.name, "element":self.element.name}))
    except HTMLParseError, msg:
      element = self.element
      offset = [element.line - element.dispatcher.locator.getLineNumber(),
                - element.dispatcher.locator.getColumnNumber()]
      match = re.search(', at line (\d+), column (\d+)',str(msg))
      if match: offset[0] += int(match.group(1))-1
      element.log(NotHtml({"parent":element.parent.name, "element":element.name, "value": str(msg)}),offset)

  def handle_starttag(self, tag, attributes):
    if tag.lower() not in self.htmltags: 
      self.log(NotHtml({"parent":self.element.parent.name, "element":self.element.name,"value":tag, "message": "Non-html tag"}))
      self.valid = False
    elif tag.lower() not in HTMLValidator.acceptable_elements: 
      self.log(SecurityRisk({"parent":self.element.parent.name, "element":self.element.name, "tag":tag}))
    for (name,value) in attributes:
      if name.lower() == 'style':
        for evil in checkStyle(value):
          self.log(DangerousStyleAttr({"parent":self.element.parent.name, "element":self.element.name, "attr":"style", "value":evil}))
      elif name.lower() not in self.acceptable_attributes:
        self.log(SecurityRiskAttr({"parent":self.element.parent.name, "element":self.element.name, "attr":name}))

  def handle_charref(self, name):
    if name.startswith('x'):
      value = int(name[1:],16)
    else:
      value = int(name)
    if 0x80 <= value <= 0x9F or value == 0xfffd: 
      self.log(BadCharacters({"parent":self.element.parent.name,
        "element":self.element.name, "value":"&#" + name + ";"}))

#
# Scub CSS properties for potentially evil intent
#
def checkStyle(style):
  if not re.match("""^([:,;#%.\sa-zA-Z0-9!]|\w-\w|'[\s\w]+'|"[\s\w]+"|\([\d,\s]+\))*$""", style):
    return [style]
  if not re.match("^(\s*[-\w]+\s*:\s*[^:;]*(;|$))*$", style):
    return [style]
  
  unsafe = []
  for prop,value in re.findall("([-\w]+)\s*:\s*([^:;]*)",style.lower()):
    if prop not in HTMLValidator.acceptable_css_properties:
      if prop not in unsafe: unsafe.append(prop)
    elif prop.split('-')[0] in ['background','border','margin','padding']:
      for keyword in value.split():
        if keyword not in HTMLValidator.acceptable_css_keywords and \
          not HTMLValidator.valid_css_values.match(keyword):
          if keyword not in unsafe: unsafe.append(keyword)

  return unsafe

#
# This class simply html events.  Identifies unsafe events
#
class htmlEater(validatorBase):
  def getExpectedAttrNames(self):
    if self.attrs and len(self.attrs): 
      return self.attrs.getNames()
  def textOK(self): pass
  def startElementNS(self, name, qname, attrs):
    for attr in attrs.getNames():
      if attr[0]==None:
        if attr[1].lower() == 'style':
          for value in checkStyle(attrs.get(attr)):
            self.log(DangerousStyleAttr({"parent":self.parent.name, "element":self.name, "attr":attr[1], "value":value}))
        elif attr[1].lower() not in HTMLValidator.acceptable_attributes:
          self.log(SecurityRiskAttr({"parent":self.parent.name, "element":self.name, "attr":attr[1]}))
    self.push(htmlEater(), self.name, attrs)
    if name.lower() not in HTMLValidator.acceptable_elements:
      self.log(SecurityRisk({"parent":self.parent.name, "element":self.name, "tag":name}))
  def endElementNS(self,name,qname):
    pass

#
# text: i.e., no child elements allowed (except rdf:Description).
#
class text(validatorBase):
  def textOK(self): pass
  def getExpectedAttrNames(self):
    if self.getFeedType() == TYPE_RSS1:
      return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'parseType'), 
              (u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'datatype'),
              (u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'resource')]
    else:
      return []
  def startElementNS(self, name, qname, attrs):
    if self.getFeedType() == TYPE_RSS1:
      if self.value.strip() or self.children:
        if self.attrs.get((u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'parseType')) != 'Literal':
          self.log(InvalidRDF({"message":"mixed content"}))
      from rdf import rdfExtension
      self.push(rdfExtension(qname), name, attrs)
    else:
      from base import namespaces
      ns = namespaces.get(qname, '')

      if name.find(':') != -1:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":self.name, "element":name}))
      else:
        self.log(UndefinedElement({"parent":self.name, "element":name}))

      self.push(eater(), name, attrs)

#
# noduplicates: no child elements, no duplicate siblings
#
class noduplicates(validatorBase):
  def __init__(self, message=DuplicateElement):
    self.message=message
    validatorBase.__init__(self)
  def startElementNS(self, name, qname, attrs):
    pass
  def characters(self, string):
    pass
  def prevalidate(self):
    if self.name in self.parent.children:
      self.log(self.message({"parent":self.parent.name, "element":self.name}))

#
# valid e-mail addr-spec
#
class addr_spec(text):
  email_re = re.compile('''([a-zA-Z0-9_\-\+\.\']+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$''')
  message = InvalidAddrSpec
  def validate(self, value=None):
    if not value: value=self.value
    if not self.email_re.match(value):
      self.log(self.message({"parent":self.parent.name, "element":self.name, "value":self.value}))
    else:
      self.log(ValidContact({"parent":self.parent.name, "element":self.name, "value":self.value}))

#
# iso639 language code
#
def iso639_validate(log,value,element,parent):
  import iso639codes
  if '-' in value:
    lang, sublang = value.split('-', 1)
  else:
    lang = value
  if not iso639codes.isoLang.has_key(unicode.lower(unicode(lang))):
    log(InvalidLanguage({"parent":parent, "element":element, "value":value}))
  else:
    log(ValidLanguage({"parent":parent, "element":element}))

class iso639(text):
  def validate(self):
    iso639_validate(self.log, self.value, self.name, self.parent.name) 

#
# Encoding charset
#
class Charset(text):
  def validate(self):
    try:
      import codecs
      codecs.lookup(self.value)
    except:
      self.log(InvalidEncoding({'value': self.value}))

#
# Mime type
#
class MimeType(text):
  def validate(self):
    if not mime_re.match(self.value):
      self.log(InvalidMIMEType({'attr':'type'}))

#
# iso8601 dateTime
#
class iso8601(text):
  iso8601_re = re.compile("^\d\d\d\d(-\d\d(-\d\d(T\d\d:\d\d(:\d\d(\.\d*)?)?" +
                       "(Z|([+-]\d\d:\d\d))?)?)?)?$")
  message = InvalidISO8601DateTime

  def validate(self):
    if not self.iso8601_re.match(self.value):
      self.log(self.message({"parent":self.parent.name, "element":self.name, "value":self.value}))
      return

    work=self.value.split('T')

    date=work[0].split('-')
    year=int(date[0])
    if len(date)>1:
      month=int(date[1])
      try:
        if len(date)>2: datetime.date(year,month,int(date[2]))
      except ValueError, e:
        return self.log(self.message({"parent":self.parent.name, "element":self.name, "value":str(e)}))

    if len(work) > 1:
      time=work[1].split('Z')[0].split('+')[0].split('-')[0]
      time=time.split(':')
      if int(time[0])>23:
        self.log(self.message({"parent":self.parent.name, "element":self.name, "value":self.value}))
        return
      if len(time)>1 and int(time[1])>60:
        self.log(self.message({"parent":self.parent.name, "element":self.name, "value":self.value}))
        return
      if len(time)>2 and float(time[2])>60.0:
        self.log(self.message({"parent":self.parent.name, "element":self.name, "value":self.value}))
        return

    self.log(ValidW3CDTFDate({"parent":self.parent.name, "element":self.name, "value":self.value}))
    return 1

class w3cdtf(iso8601):
  # The same as in iso8601, except a timezone is not optional when
  #  a time is present
  iso8601_re = re.compile("^\d\d\d\d(-\d\d(-\d\d(T\d\d:\d\d(:\d\d(\.\d*)?)?" +
                           "(Z|([+-]\d\d:\d\d)))?)?)?$")
  message = InvalidW3CDTFDate

class rfc3339(iso8601):
  # The same as in iso8601, except that the only thing that is optional
  # is the seconds
  iso8601_re = re.compile("^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d*)?" +
                           "(Z|([+-]\d\d:\d\d))$")
  message = InvalidRFC3339Date

  def validate(self):
    if iso8601.validate(self):
      tomorrow=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.localtime(time.time()+86400))
      if self.value > tomorrow or self.value < "1970":
        self.log(ImplausibleDate({"parent":self.parent.name,
          "element":self.name, "value":self.value}))
        return 0
      return 1
    return 0

class iso8601_date(iso8601):
  date_re = re.compile("^\d\d\d\d-\d\d-\d\d$")
  def validate(self):
    if iso8601.validate(self):
      if not self.date_re.search(self.value):
        self.log(InvalidISO8601Date({"parent":self.parent.name, "element":self.name, "value":self.value}))

iana_schemes = [ # http://www.iana.org/assignments/uri-schemes.html
  "ftp", "http", "gopher", "mailto", "news", "nntp", "telnet", "wais",
  "file", "prospero", "z39.50s", "z39.50r", "cid", "mid", "vemmi",
  "service", "imap", "nfs", "acap", "rtsp", "tip", "pop", "data", "dav",
  "opaquelocktoken", "sip", "sips", "tel", "fax", "modem", "ldap",
  "https", "soap.beep", "soap.beeps", "xmlrpc.beep", "xmlrpc.beeps",
  "urn", "go", "h323", "ipp", "tftp", "mupdate", "pres", "im", "mtqp",
  "iris.beep", "dict", "snmp", "crid", "tag", "dns", "info"
]

#
# rfc2396 fully qualified (non-relative) uri
#
class rfc2396(text):
  rfc2396_re = re.compile("([a-zA-Z][0-9a-zA-Z+\\-\\.]*:)?/{0,2}" +
    "[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*'()%,#]*$")
  urn_re = re.compile(r"^[Uu][Rr][Nn]:[a-zA-Z0-9][a-zA-Z0-9-]{1,31}:([a-zA-Z0-9()+,\.:=@;$_!*'\-]|%[0-9A-Fa-f]{2})+$")
  tag_re = re.compile(r"^tag:([a-z0-9\-\._]+?@)?[a-z0-9\.\-]+?,\d{4}(-\d{2}(-\d{2})?)?:[0-9a-zA-Z;/\?:@&=+$\.\-_!~*'\(\)%,]*(#[0-9a-zA-Z;/\?:@&=+$\.\-_!~*'\(\)%,]*)?$")
  def validate(self, errorClass=InvalidLink, successClass=ValidURI, extraParams={}):
    success = 0
    scheme=self.value.split(':')[0].lower()
    if scheme=='tag':
      if self.tag_re.match(self.value):
        success = 1
        logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
        logparams.update(extraParams)
        self.log(ValidTAG(logparams))
      else:
        logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
        logparams.update(extraParams)
        self.log(InvalidTAG(logparams))
    elif scheme=="urn":
      if self.urn_re.match(self.value):
        success = 1
        logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
        logparams.update(extraParams)
        self.log(ValidURN(logparams))
      else:
        logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
        logparams.update(extraParams)
        self.log(InvalidURN(logparams))
    elif not self.rfc2396_re.match(self.value):
      logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
      logparams.update(extraParams)
      urichars_re=re.compile("[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*'()%,#]")
      for c in self.value:
        if ord(c)<128 and not urichars_re.match(c):
          logparams['value'] = repr(str(c))
          self.log(InvalidUriChar(logparams))
          break
      else:
        try:
          if self.rfc2396_re.match(self.value.encode('idna')):
            errorClass=UriNotIri
        except:
          pass
        self.log(errorClass(logparams))
    elif scheme in ['http','ftp']:
      if not re.match('^\w+://[^/].*',self.value):
        logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
        logparams.update(extraParams)
        self.log(errorClass(logparams))
      else:
        success = 1
    elif self.value.find(':')>=0 and scheme.isalpha() and scheme not in iana_schemes:
      self.log(SchemeNotIANARegistered({"parent":self.parent.name, "element":self.name, "value":scheme}))
    else:
      success = 1
    if success:
      logparams = {"parent":self.parent.name, "element":self.name, "value":self.value}
      logparams.update(extraParams)
      self.log(successClass(logparams))
    return success

#
# rfc3987 iri
#
class rfc3987(rfc2396):
  def validate(self, errorClass=InvalidIRI, successClass=ValidURI, extraParams={}):
    try:
      if self.value: self.value = self.value.encode('idna')
    except:
      pass # apparently '.' produces label too long
    return rfc2396.validate(self, errorClass, successClass, extraParams)

class rfc2396_full(rfc2396): 
  rfc2396_re = re.compile("[a-zA-Z][0-9a-zA-Z+\\-\\.]*:(//)?" +
    "[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*'()%,#]+$")
  def validate(self, errorClass=InvalidFullLink, successClass=ValidURI, extraParams={}):
    return rfc2396.validate(self, errorClass, successClass, extraParams)

#
# URI reference resolvable relative to xml:base
#
class xmlbase(rfc3987):
  def validate(self, errorClass=InvalidIRI, successClass=ValidURI, extraParams={}):
    if rfc3987.validate(self, errorClass, successClass, extraParams):
      if self.dispatcher.xmlBase != self.xmlBase:
        docbase=canonicalForm(self.dispatcher.xmlBase).split('#')[0]
        elembase=canonicalForm(self.xmlBase).split('#')[0]
        value=canonicalForm(urljoin(elembase,self.value)).split('#')[0]
        if (value==elembase) and (elembase.encode('idna')!=docbase):
          self.log(SameDocumentReference({"parent":self.parent.name, "element":self.name, "value":self.value}))

#
# rfc822 dateTime (+Y2K extension)
#
class rfc822(text):
  rfc822_re = re.compile("(((mon)|(tue)|(wed)|(thu)|(fri)|(sat)|(sun))\s*,\s*)?" +
    "\d\d?\s+((jan)|(feb)|(mar)|(apr)|(may)|(jun)|(jul)|(aug)|(sep)|(oct)|" +
    "(nov)|(dec))\s+\d\d(\d\d)?\s+\d\d:\d\d(:\d\d)?\s+(([+-]\d\d\d\d)|" +
    "(ut)|(gmt)|(est)|(edt)|(cst)|(cdt)|(mst)|(mdt)|(pst)|(pdt)|[a-ik-z])?$",
    re.UNICODE)
  rfc2822_re = re.compile("(((Mon)|(Tue)|(Wed)|(Thu)|(Fri)|(Sat)|(Sun)), )?" +
    "\d\d? ((Jan)|(Feb)|(Mar)|(Apr)|(May)|(Jun)|(Jul)|(Aug)|(Sep)|(Oct)|" +
    "(Nov)|(Dec)) \d\d\d\d \d\d:\d\d(:\d\d)? (([+-]?\d\d[03]0)|" +
    "(UT)|(GMT)|(EST)|(EDT)|(CST)|(CDT)|(MST)|(MDT)|(PST)|(PDT)|Z)$")
  def validate(self):
    if self.rfc2822_re.match(self.value):
      import calendar
      value = parsedate(self.value)

      try:
        if value[0] > 1900:
          dow = datetime.date(*value[:3]).strftime("%a")
          if self.value.find(',')>0 and dow.lower() != self.value[:3].lower():
            self.log(IncorrectDOW({"parent":self.parent.name, "element":self.name, "value":self.value[:3]}))
            return
      except ValueError, e:
        self.log(InvalidRFC2822Date({"parent":self.parent.name, "element":self.name, "value":str(e)}))
        return

      tomorrow=time.localtime(time.time()+86400)
      if value > tomorrow or value[0] < 1970:
        self.log(ImplausibleDate({"parent":self.parent.name,
          "element":self.name, "value":self.value}))
      else:
        self.log(ValidRFC2822Date({"parent":self.parent.name, "element":self.name, "value":self.value}))
    else:
      value1,value2 = '', self.value
      value2 = re.sub(r'[\\](.)','',value2)
      while value1!=value2: value1,value2=value2,re.sub('\([^(]*?\)',' ',value2)
      if not self.rfc822_re.match(value2.strip().lower()):
        self.log(InvalidRFC2822Date({"parent":self.parent.name, "element":self.name, "value":self.value}))
      else:
        self.log(ProblematicalRFC822Date({"parent":self.parent.name, "element":self.name, "value":self.value}))

#
# Decode html entityrefs
#
from htmlentitydefs import name2codepoint
def decodehtml(data):
  chunks=re.split('&#?(\w+);',data)

  for i in range(1,len(chunks),2):
    if chunks[i].isdigit():
#      print chunks[i]
      chunks[i]=unichr(int(chunks[i]))
    elif chunks[i] in name2codepoint:
      chunks[i]=unichr(name2codepoint[chunks[i]])
    else:
      chunks[i]='&' + chunks[i] +';'

#  print repr(chunks)
  return u"".join(map(unicode,chunks))

#
# Scan HTML for relative URLs
#
class absUrlMixin:
  anchor_re = re.compile('<a\s+href=(?:"(.*?)"|\'(.*?)\'|([\w-]+))\s*>', re.IGNORECASE)
  img_re = re.compile('<img\s+[^>]*src=(?:"(.*?)"|\'(.*?)\'|([\w-]+))[\s>]', re.IGNORECASE)
  absref_re = re.compile("\w+:")
  def validateAbsUrl(self,value):
    refs = self.img_re.findall(self.value) + self.anchor_re.findall(self.value)
    for ref in [reduce(lambda a,b: a or b, x) for x in refs]:
      if not self.absref_re.match(decodehtml(ref)):
        self.log(ContainsRelRef({"parent":self.parent.name, "element":self.name, "value": ref}))

#
# Scan HTML for 'devious' content
#
class safeHtmlMixin:
  def validateSafe(self,value):
    HTMLValidator(value, self)

class safeHtml(text, safeHtmlMixin, absUrlMixin):
  def prevalidate(self):
    self.children.append(True) # force warnings about "mixed" content
  def validate(self):
    self.validateSafe(self.value)
    self.validateAbsUrl(self.value)

#
# Elements for which email addresses are discouraged
#
class nonemail(text):
  email_re = re.compile("<" + addr_spec.email_re.pattern[:-1] + ">")
  def validate(self):
    if self.email_re.search(self.value):
      self.log(ContainsEmail({"parent":self.parent.name, "element":self.name}))

#
# Elements for which html is discouraged, also checks for relative URLs
#
class nonhtml(text,safeHtmlMixin):#,absUrlMixin):
  htmlEndTag_re = re.compile("</(\w+)>")
  htmlEntity_re = re.compile("&(#?\w+);")
  def prevalidate(self):
    self.children.append(True) # force warnings about "mixed" content
  def validate(self, message=ContainsHTML):
    tags = [t for t in self.htmlEndTag_re.findall(self.value) if t.lower() in HTMLValidator.htmltags]
    if tags:
      self.log(message({"parent":self.parent.name, "element":self.name, "value":tags[0]}))
    elif self.htmlEntity_re.search(self.value):
      for value in self.htmlEntity_re.findall(self.value):
        from htmlentitydefs import name2codepoint
        if (value in name2codepoint or not value.isalpha()) and \
          value not in self.dispatcher.literal_entities:
          self.log(message({"parent":self.parent.name, "element":self.name, "value":'&'+value+';'}))

#
# valid e-mail addresses
#
class email(addr_spec,nonhtml):
  message = InvalidContact
  def validate(self):
    value=self.value
    list = AddressList(self.value)
    if len(list)==1: value=list[0][1]
    nonhtml.validate(self)
    addr_spec.validate(self, value)

class nonNegativeInteger(text):
  def validate(self):
    try:
      t = int(self.value)
      if t < 0:
        raise ValueError
      else:
        self.log(ValidInteger({"parent":self.parent.name, "element":self.name, "value":self.value}))
    except ValueError:
      self.log(InvalidNonNegativeInteger({"parent":self.parent.name, "element":self.name, "value":self.value}))

class positiveInteger(text):
  def validate(self):
    if self.value == '': return
    try:
      t = int(self.value)
      if t <= 0:
        raise ValueError
      else:
        self.log(ValidInteger({"parent":self.parent.name, "element":self.name, "value":self.value}))
    except ValueError:
      self.log(InvalidPositiveInteger({"parent":self.parent.name, "element":self.name, "value":self.value}))

class Integer(text):
  def validate(self):
    if self.value == '': return
    try:
      t = int(self.value)
      self.log(ValidInteger({"parent":self.parent.name, "element":self.name, "value":self.value}))
    except ValueError:
      self.log(InvalidInteger({"parent":self.parent.name, "element":self.name, "value":self.value}))

class Float(text):
  def validate(self, name=None):
    if not re.match('\d+\.?\d*$', self.value):
      self.log(InvalidFloat({"attr":name or self.name, "value":self.value}))

class percentType(text):
  def validate(self):
    try:
      t = float(self.value)
      if t < 0.0 or t > 100.0:
        raise ValueError
      else:
        self.log(ValidPercentage({"parent":self.parent.name, "element":self.name, "value":self.value}))
    except ValueError:
      self.log(InvalidPercentage({"parent":self.parent.name, "element":self.name, "value":self.value}))

class latitude(text):
  def validate(self):
    try:
      lat = float(self.value)
      if lat > 90 or lat < -90:
        raise ValueError
      else:
        self.log(ValidLatitude({"parent":self.parent.name, "element":self.name, "value":self.value}))
    except ValueError:
      self.log(InvalidLatitude({"parent":self.parent.name, "element":self.name, "value":self.value}))

class longitude(text):
  def validate(self):
    try:
      lon = float(self.value)
      if lon > 180 or lon < -180:
        raise ValueError
      else:
        self.log(ValidLongitude({"parent":self.parent.name, "element":self.name, "value":self.value}))
    except ValueError:
      self.log(InvalidLongitude({"parent":self.parent.name, "element":self.name, "value":self.value}))

#
# mixin to validate URL in attribute
#
class httpURLMixin:
  http_re = re.compile("http://", re.IGNORECASE)
  def validateHttpURL(self, ns, attr):
    value = self.attrs[(ns, attr)]
    if not self.http_re.search(value):
      self.log(InvalidURLAttribute({"parent":self.parent.name, "element":self.name, "attr":attr}))
    elif not rfc2396_full.rfc2396_re.match(value):
      self.log(InvalidURLAttribute({"parent":self.parent.name, "element":self.name, "attr":attr}))
    else:
      self.log(ValidURLAttribute({"parent":self.parent.name, "element":self.name, "attr":attr}))

class rdfResourceURI(rfc2396):
  def getExpectedAttrNames(self):
    return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'resource'),
            (u'http://purl.org/dc/elements/1.1/', u'title')]
  def validate(self):
    if (rdfNS, 'resource') in self.attrs.getNames():
      self.value=self.attrs.getValue((rdfNS, 'resource'))
      rfc2396.validate(self)
    elif self.getFeedType() == TYPE_RSS1:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"rdf:resource"}))

class rdfAbout(validatorBase):
  def getExpectedAttrNames(self):
    return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'about')]
  def startElementNS(self, name, qname, attrs):
    pass
  def validate(self):
    if (rdfNS, 'about') not in self.attrs.getNames():
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"rdf:about"}))
    else:
      test=rfc2396().setElement(self.name, self.attrs, self)
      test.value=self.attrs.getValue((rdfNS, 'about'))
      test.validate()

class nonblank(text):
  def validate(self, errorClass=NotBlank, extraParams={}):
    if not self.value:
      logparams={"parent":self.parent.name,"element":self.name}
      logparams.update(extraParams)
      self.log(errorClass(logparams))

class nows(text):
  def __init__(self):
    self.ok = 1
    text.__init__(self)
  def characters(self, string):
    text.characters(self, string)
    if self.ok and (self.value != self.value.strip()):
      self.log(UnexpectedWhitespace({"parent":self.parent.name, "element":self.name}))
      self.ok = 0

class unique(nonblank):
  def __init__(self, name, scope, message=DuplicateValue):
    self.name=name
    self.scope=scope
    self.message=message
    nonblank.__init__(self)
    if not name+'s' in self.scope.__dict__:
      self.scope.__dict__[name+'s']=[]
  def validate(self):
    nonblank.validate(self)
    list=self.scope.__dict__[self.name+'s']
    if self.value in list:
      self.log(self.message({"parent":self.parent.name, "element":self.name,"value":self.value}))
    elif self.value:
      list.append(self.value)

class rfc3987_full(xmlbase):
  rfc2396_re = rfc2396_full.rfc2396_re
  def validate(self, errorClass=InvalidFullLink, successClass=ValidURI, extraParams={}):
    return rfc2396.validate(self, errorClass, successClass, extraParams)

class canonicaluri(rfc3987_full):
  def validate(self):
    prestrip = self.value
    self.value = self.value.strip()
    if rfc3987_full.validate(self):
      c = canonicalForm(self.value)
      if c is None or c != prestrip:
        self.log(NonCanonicalURI({"parent":self.parent.name,"element":self.name,"uri":prestrip, "curi":c or 'N/A'}))

class yesno(text):
  def normalizeWhitespace(self):
    pass
  def validate(self):
    if not self.value.lower() in ['yes','no','clean']:
      self.log(InvalidYesNo({"parent":self.parent.name, "element":self.name,"value":self.value}))

class truefalse(text):
  def normalizeWhitespace(self):
    pass
  def validate(self):
    if not self.value.lower() in ['true','false']:
      self.log(InvalidTrueFalse({"parent":self.parent.name, "element":self.name,"value":self.value}))

class duration(text):
  duration_re = re.compile("([0-9]?[0-9]:)?[0-5]?[0-9]:[0-5][0-9]$")
  def validate(self):
    if not self.duration_re.search(self.value):
      self.log(InvalidDuration({"parent":self.parent.name, "element":self.name
      , "value":self.value}))

class lengthLimitedText(nonhtml):
  def __init__(self, max):
    self.max = max
    text.__init__(self)
  def validate(self):
    if len(self.value)>self.max:
      self.log(TooLong({"parent":self.parent.name, "element":self.name,
        "len": len(self.value), "max": self.max}))
    nonhtml.validate(self)

class keywords(text):
  def validate(self):
    if self.value.find(' ')>=0 and self.value.find(',')<0:
      self.log(InvalidKeywords({"parent":self.parent.name, "element":self.name}))

class commaSeparatedIntegers(text):
  def validate(self):
    if not re.match("^\d+(,\s*\d+)*$", self.value):
      self.log(InvalidCommaSeparatedIntegers({"parent":self.parent.name, 
        "element":self.name}))

class formname(text):
  def validate(self):
    if not re.match("^[a-zA-z][a-zA-z0-9:._]*", self.value):
      self.log(InvalidFormComponentName({"parent":self.parent.name, 
        "element":self.name, "value":self.value}))

class enumeration(text):
  def validate(self):
    if self.value not in self.valuelist:
      self.log(self.error({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class caseinsensitive_enumeration(enumeration):
  def validate(self):
    self.value=self.value.lower()
    enumeration.validate(self)

class iso3166(enumeration):
  error = InvalidCountryCode
  valuelist = [
    "AD", "AE", "AF", "AG", "AI", "AM", "AN", "AO", "AQ", "AR", "AS", "AT",
    "AU", "AW", "AZ", "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ",
    "BM", "BN", "BO", "BR", "BS", "BT", "BV", "BW", "BY", "BZ", "CA", "CC",
    "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU",
    "CV", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE",
    "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA",
    "GB", "GD", "GE", "GF", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR",
    "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN", "HR", "HT", "HU", "ID",
    "IE", "IL", "IN", "IO", "IQ", "IR", "IS", "IT", "JM", "JO", "JP", "KE",
    "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB",
    "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD",
    "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT",
    "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI",
    "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH",
    "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO",
    "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK",
    "SL", "SM", "SN", "SO", "SR", "ST", "SV", "SY", "SZ", "TC", "TD", "TF",
    "TG", "TH", "TJ", "TK", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ",
    "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI", "VN",
    "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"]

class iso4217(enumeration):
  error = InvalidCurrencyUnit
  valuelist = [
    "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZM",
    "BAM", "BBD", "BDT", "BGN", "BHD", "BIF", "BMD", "BND", "BOB", "BOV",
    "BRL", "BSD", "BTN", "BWP", "BYR", "BZD", "CAD", "CDF", "CHE", "CHF",
    "CHW", "CLF", "CLP", "CNY", "COP", "COU", "CRC", "CSD", "CUP", "CVE",
    "CYP", "CZK", "DJF", "DKK", "DOP", "DZD", "EEK", "EGP", "ERN", "ETB",
    "EUR", "FJD", "FKP", "GBP", "GEL", "GHC", "GIP", "GMD", "GNF", "GTQ",
    "GWP", "GYD", "HKD", "HNL", "HRK", "HTG", "HUF", "IDR", "ILS", "INR",
    "IQD", "IRR", "ISK", "JMD", "JOD", "JPY", "KES", "KGS", "KHR", "KMF",
    "KPW", "KRW", "KWD", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL",
    "LTL", "LVL", "LYD", "MAD", "MDL", "MGA", "MKD", "MMK", "MNT", "MOP",
    "MRO", "MTL", "MUR", "MWK", "MXN", "MXV", "MYR", "MZM", "NAD", "NGN",
    "NIO", "NOK", "NPR", "NZD", "OMR", "PAB", "PEN", "PGK", "PHP", "PKR",
    "PLN", "PYG", "QAR", "ROL", "RON", "RUB", "RWF", "SAR", "SBD", "SCR",
    "SDD", "SEK", "SGD", "SHP", "SIT", "SKK", "SLL", "SOS", "SRD", "STD",
    "SVC", "SYP", "SZL", "THB", "TJS", "TMM", "TND", "TOP", "TRL", "TRY",
    "TTD", "TWD", "TZS", "UAH", "UGX", "USD", "USN", "USS", "UYU", "UZS",
    "VEB", "VND", "VUV", "WST", "XAF", "XAG", "XAU", "XBA", "XBB", "XBC",
    "XBD", "XCD", "XDR", "XFO", "XFU", "XOF", "XPD", "XPF", "XPT", "XTS",
    "XXX", "YER", "ZAR", "ZMK", "ZWD"]
