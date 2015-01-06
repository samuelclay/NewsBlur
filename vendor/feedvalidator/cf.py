# http://msdn.microsoft.com/XML/rss/sle/default.aspx

from base import validatorBase
from validators import eater, text

class sort(validatorBase):
  def getExpectedAttrNames(self):
      return [(None,u'data-type'),(None,u'default'),(None,u'element'),(None, u'label'),(None,u'ns')]

class group(validatorBase):
  def getExpectedAttrNames(self):
      return [(None,u'element'),(None, u'label'),(None,u'ns')]

class listinfo(validatorBase):
  def do_cf_sort(self):
    return sort()
  def do_cf_group(self):
    return group()

class treatAs(text): pass
