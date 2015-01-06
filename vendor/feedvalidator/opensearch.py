from validators import *
from logging import *
import re

class OpenSearchDescription(validatorBase):
  def __init__(self):
    self.exampleFound = 0
    validatorBase.__init__(self)

  def validate(self):
    name=self.name.replace("opensearch_",'')
    if not "ShortName" in self.children:
      self.log(MissingElement({"parent":name, "element":"ShortName"}))
    if not "Description" in self.children:
      self.log(MissingElement({"parent":name, "element":"Description"}))
    if not "Url" in self.children:
      self.log(MissingElement({"parent":name, "element":"Url"}))
    if not self.exampleFound:
      self.log(ShouldIncludeExample({}))

  def do_ShortName(self):
    return lengthLimitedText(16), noduplicates()
  def do_Description(self):
    return lengthLimitedText(1024), noduplicates()
  def do_Url(self):
    return Url()
  def do_Contact(self):
    return addr_spec(), noduplicates()
  def do_Tags(self):
    return lengthLimitedText(256), noduplicates()
  def do_LongName(self):
    return lengthLimitedText(48), noduplicates()
  def do_Image(self):
    return Image()
  def do_Query(self):
    return Query()
  def do_Developer(self):
    return lengthLimitedText(64), noduplicates()
  def do_Attribution(self):
    return lengthLimitedText(256), noduplicates()
  def do_SyndicationRight(self):
    return SyndicationRight(), noduplicates()
  def do_AdultContent(self):
    return AdultContent(), noduplicates()
  def do_Language(self):
    return Language()
  def do_InputEncoding(self):
    return Charset()
  def do_OutputEncoding(self):
    return Charset()

class Url(validatorBase):
  def getExpectedAttrNames(self):
    return [(None,attr) for attr in ['template', 'type', 'indexOffset',
      'pageOffset']]
  def prevalidate(self):
    self.validate_required_attribute((None,'template'), Template())
    self.validate_required_attribute((None,'type'), MimeType)
    self.validate_optional_attribute((None,'indexOffset'), Integer)
    self.validate_optional_attribute((None,'pageOffset'), Integer)

class Template(rfc2396_full):
  tparam = re.compile("{((?:[-a-zA-Z0-9._~]|%[a-fA-F0-9]{2})+:?(?:[-a-zA-Z0-9._~]|%[a-fA-F0-9]{2})*)\??}")
  valuelist = ['searchTerms', 'count', 'startIndex', 'startPage', 'language',
    'inputEncoding', 'outputEncoding']

  def validate(self):
    for pname in self.tparam.findall(self.value):
      if pname.find(':')<0:
        if pname not in self.valuelist:
          self.log(InvalidLocalParameter({'value':pname}))
      else:
        prefix,name = pname.split(':',1)
        if not self.parent.namespaceFor(prefix):
          self.log(UndeclaredPrefix({'value':prefix}))
    self.value = self.tparam.sub(r'\1',self.value)
    rfc2396_full.validate(self)

class Image(rfc2396_full):
  def getExpectedAttrNames(self):
    return [(None,attr) for attr in ['height', 'width', 'type']]
  def prevalidate(self):
    self.validate_required_attribute((None,'height'), nonNegativeInteger)
    self.validate_required_attribute((None,'width'), nonNegativeInteger)
    self.validate_required_attribute((None,'type'), MimeType)

class Query(validatorBase):
  def getExpectedAttrNames(self):
    return [(None,attr) for attr in ['role', 'title', 'totalResults',
      'searchTerms', 'count', 'startIndex', 'startPage', 'language',
      'inputEncoding', 'xutputEncoding', 'parameter']]

  def prevalidate(self):
    self.validate_required_attribute((None,'role'), QueryRole)
    self.validate_optional_attribute((None,'title'), lengthLimitedText(256))
    self.validate_optional_attribute((None,'title'), nonhtml)
    self.validate_optional_attribute((None,'totalResults'), nonNegativeInteger)
    self.validate_optional_attribute((None,'searchTerms'), UrlEncoded)
    self.validate_optional_attribute((None,'count'), nonNegativeInteger)
    self.validate_optional_attribute((None,'startIndex'), Integer)
    self.validate_optional_attribute((None,'startPage'), Integer)
    self.validate_optional_attribute((None,'language'), iso639)
    self.validate_optional_attribute((None,'inputEncoding'), Charset)
    self.validate_optional_attribute((None,'outputEncoding'), Charset)

    if self.attrs.has_key((None,"role")) and \
      self.attrs.getValue((None,"role")) == "example":
      self.parent.exampleFound = 1

class QueryRole(enumeration):
  error = InvalidLocalRole
  valuelist = ['request', 'example', 'related', 'correction', 'subset',
    'superset']
  def validate(self):
    if self.value.find(':')<0:
      enumeration.validate(self)
    else:
      prefix,name = self.value.split(':',1)
      if not self.parent.namespaceFor(prefix):
        self.log(UndeclaredPrefix({'value':prefix}))

class UrlEncoded(validatorBase):
  def validate(self):
    from urllib import quote, unquote
    import re
    for value in self.value.split():
      value = re.sub('%\w\w', lambda x: x.group(0).upper(), value)
      if value != quote(unquote(value)):
        self.log(NotURLEncoded({}))
        break

class SyndicationRight(enumeration):
  error = InvalidSyndicationRight
  valuelist = ['open','limited','private','closed']
  def validate(self):
    self.value = self.value.lower()
    enumeration.validate(self)

class AdultContent(enumeration):
  error = InvalidAdultContent
  valuelist = ['false', 'FALSE', '0', 'no', 'NO',
    'true', 'TRUE', '1', 'yes', 'YES']

class Language(iso639):
  def validate(self):
    if self.value != '*':
      iso639.validate(self)
