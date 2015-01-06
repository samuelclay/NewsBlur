"""$Id: textInput.py 699 2006-09-25 02:01:18Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 699 $"
__date__ = "$Date: 2006-09-25 02:01:18 +0000 (Mon, 25 Sep 2006) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from validators import *
from extension import extension_everywhere

#
# textInput element.
#
class textInput(validatorBase, extension_everywhere):
  def getExpectedAttrNames(self):
      return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'about')]

  def validate(self):
    if not "title" in self.children:
      self.log(MissingTitle({"parent":self.name, "element":"title"}))
    if not "link" in self.children:
      self.log(MissingLink({"parent":self.name, "element":"link"}))
    if not "description" in self.children:
      self.log(MissingDescription({"parent":self.name,"element":"description"}))
    if not "name" in self.children:
      self.log(MissingElement({"parent":self.name, "element":"name"}))

  def do_title(self):
    return nonhtml(), noduplicates()

  def do_description(self):
    return text(), noduplicates()

  def do_name(self):
    return formname(), noduplicates()

  def do_link(self):
    return rfc2396_full(), noduplicates()

  def do_dc_creator(self):
    return text() # duplicates allowed

  def do_dc_subject(self):
    return text() # duplicates allowed

  def do_dc_date(self):
    return w3cdtf(), noduplicates()
