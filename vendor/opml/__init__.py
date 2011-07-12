import lxml.etree

class OutlineElement(object):
    """A single outline object."""

    def __init__(self, root):
        """Initialize from the root <outline> node."""

        self._root = root

    def __getattr__(self, attr):

        if attr in self._root.attrib:
            return self._root.attrib[attr]

        raise AttributeError()

    @property
    def _outlines(self):
        """Return the available sub-outline objects as a seqeunce."""

        return [OutlineElement(n) for n in self._root.xpath('./outline')]

    def __len__(self):
        return len(self._outlines)

    def __getitem__(self, index):
        return self._outlines[index]

class Opml(object):
    """Python representation of an OPML file."""

    def __init__(self, xml_tree):
        """Initialize the object using the parsed XML tree."""

        self._tree = xml_tree

    def __getattr__(self, attr):
        """Fall back attribute handler -- attempt to find the attribute in 
        the OPML <head>."""

        result = self._tree.xpath('/opml/head/%s/text()' % attr)
        if len(result) == 1:
            return result[0]

        raise AttributeError()

    @property
    def _outlines(self):
        """Return the available sub-outline objects as a seqeunce."""

        return [OutlineElement(n) for n in self._tree.xpath(
                '/opml/body/outline')]

    def __len__(self):
        return len(self._outlines)

    def __getitem__(self, index):
        return self._outlines[index]

def from_string(opml_text):
    parser = lxml.etree.XMLParser(recover=True)
    return Opml(lxml.etree.fromstring(opml_text, parser))

def parse(opml_url):

    return Opml(lxml.etree.parse(opml_url))



