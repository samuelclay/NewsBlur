"""$Id: root.py 717 2007-01-04 18:04:57Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net/> and Mark Pilgrim <http://diveintomark.org/>"
__version__ = "$Revision: 717 $"
__date__ = "$Date: 2007-01-04 18:04:57 +0000 (Thu, 04 Jan 2007) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby and Mark Pilgrim"

from base import validatorBase

rss11_namespace='http://purl.org/net/rss1.1#'
purl1_namespace='http://purl.org/rss/1.0/'
soap_namespace='http://feeds.archive.org/validator/'
pie_namespace='http://purl.org/atom/ns#'
atom_namespace='http://www.w3.org/2005/Atom'
opensearch_namespace='http://a9.com/-/spec/opensearch/1.1/'
xrds_namespace='xri://$xrds'

#
# Main document.  
# Supports rss, rdf, pie, and ffkar
#
class root(validatorBase):

  def __init__(self, parent, base):
    validatorBase.__init__(self)
    self.parent = parent
    self.dispatcher = parent
    self.name = "root"
    self.xmlBase = base
    self.xmlLang = None

  def startElementNS(self, name, qname, attrs):
    if name=='rss':
      if qname:
        from logging import InvalidNamespace
        self.log(InvalidNamespace({"parent":"root", "element":name, "namespace":qname}))
        self.dispatcher.defaultNamespaces.append(qname)

    if name=='feed' or name=='entry':
      if qname==pie_namespace:
        from logging import ObsoleteNamespace
        self.log(ObsoleteNamespace({"element":"feed"}))
        self.dispatcher.defaultNamespaces.append(pie_namespace)
        from logging import TYPE_ATOM
        self.setFeedType(TYPE_ATOM)
      elif not qname:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":"root", "element":name}))
      else:
        if name=='feed':
          from logging import TYPE_ATOM
          self.setFeedType(TYPE_ATOM)
        else:
          from logging import TYPE_ATOM_ENTRY
          self.setFeedType(TYPE_ATOM_ENTRY)
        self.dispatcher.defaultNamespaces.append(atom_namespace)
        if qname<>atom_namespace:
          from logging import InvalidNamespace
          self.log(InvalidNamespace({"parent":"root", "element":name, "namespace":qname}))
          self.dispatcher.defaultNamespaces.append(qname)

    if name=='Channel':
      if not qname:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":"root", "element":name}))
      elif qname != rss11_namespace :
        from logging import InvalidNamespace
        self.log(InvalidNamespace({"parent":"root", "element":name, "namespace":qname}))
      else:
        self.dispatcher.defaultNamespaces.append(qname)
        from logging import TYPE_RSS1
        self.setFeedType(TYPE_RSS1)

    if name=='OpenSearchDescription':
      if not qname:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":"root", "element":name}))
        qname = opensearch_namespace
      elif qname != opensearch_namespace:
        from logging import InvalidNamespace
        self.log(InvalidNamespace({"element":name, "namespace":qname}))
        self.dispatcher.defaultNamespaces.append(qname)
        qname = opensearch_namespace

    if name=='XRDS':
      from logging import TYPE_XRD
      self.setFeedType(TYPE_XRD)
      if not qname:
        from logging import MissingNamespace
        self.log(MissingNamespace({"parent":"root", "element":name}))
        qname = xrds_namespace
      elif qname != xrds_namespace:
        from logging import InvalidNamespace
        self.log(InvalidNamespace({"element":name, "namespace":qname}))
        self.dispatcher.defaultNamespaces.append(qname)
        qname = xrds_namespace

    validatorBase.startElementNS(self, name, qname, attrs)

  def unknown_starttag(self, name, qname, attrs):
    from logging import ObsoleteNamespace,InvalidNamespace,UndefinedElement
    if qname in ['http://example.com/newformat#','http://purl.org/atom/ns#']:
      self.log(ObsoleteNamespace({"element":name, "namespace":qname}))
    elif name=='feed':
      self.log(InvalidNamespace({"element":name, "namespace":qname}))
    else:
      self.log(UndefinedElement({"parent":"root", "element":name}))

    from validators import any
    return any(self, name, qname, attrs)

  def do_rss(self):
    from rss import rss
    return rss()

  def do_feed(self):
    from feed import feed
    if pie_namespace in self.dispatcher.defaultNamespaces:
      from validators import eater
      return eater()
    return feed()

  def do_entry(self):
    from entry import entry
    return entry()

  def do_opml(self):
    from opml import opml
    return opml()

  def do_outlineDocument(self):
    from logging import ObsoleteVersion
    self.log(ObsoleteVersion({"element":"outlineDocument"}))

    from opml import opml
    return opml()

  def do_opensearch_OpenSearchDescription(self):
    import opensearch
    self.dispatcher.defaultNamespaces.append(opensearch_namespace)
    from logging import TYPE_OPENSEARCH
    self.setFeedType(TYPE_OPENSEARCH)
    return opensearch.OpenSearchDescription()

  def do_xrds_XRDS(self):
    from xrd import xrds
    return xrds()
    
  def do_rdf_RDF(self):
    from rdf import rdf
    self.dispatcher.defaultNamespaces.append(purl1_namespace)
    return rdf()

  def do_Channel(self):
    from channel import rss10Channel
    return rss10Channel()

  def do_soap_Envelope(self):
    return root(self, self.xmlBase)

  def do_soap_Body(self):
    self.dispatcher.defaultNamespaces.append(soap_namespace)
    return root(self, self.xmlBase)

  def do_request(self):
    return root(self, self.xmlBase)

  def do_xhtml_html(self):
    from logging import UndefinedElement
    self.log(UndefinedElement({"parent":"root", "element":"xhtml:html"}))
    from validators import eater
    return eater()
