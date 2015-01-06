from base import validatorBase
from validators import *

class xrds(validatorBase):
  def do_xrd_XRD(self):
    return xrd()

class xrd(validatorBase):
  def do_xrd_Service(self):
    return service()

class service(validatorBase):
  def getExpectedAttrNames(self):
    return [(None,'priority')]
  def prevalidate(self):
    self.validate_optional_attribute((None,'priority'), nonNegativeInteger)

  def do_xrd_Type(self):
    return xrdtype()
  def do_xrd_URI(self):
    return xrdtype()
  def do_openid_Delegate(self):
    return delegate()

xrdtype  = rfc3987
URI      = rfc3987
delegate = rfc3987
