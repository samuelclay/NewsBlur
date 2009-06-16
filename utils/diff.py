"""HTML Diff: http://www.aaronsw.com/2002/diff
Rough code, badly documented. Send me comments and patches."""

__author__ = 'Aaron Swartz <me@aaronsw.com>'
__copyright__ = '(C) 2003 Aaron Swartz. GNU GPL 2.'
__version__ = '0.22'

import difflib, string

class HTMLDiff:
    
    def __init__(self, a, b):
        self.original = a
        self.revised = b
        self.diffText = None
        
        self.num_delete = 0
        self.num_insert = 0
        self.num_replace = 0
        
        self._textDiff(a, b)
        
    def getDiff(self):
        return self.diffText
        
    def getStats(self):
        return (self.num_insert, self.num_delete, self.num_replace)
                
    def isTag(self, x): return x[0] == "<" and x[-1] == ">"

    def _textDiff(self, a, b):
        """Takes in strings a and b and returns a human-readable HTML diff."""

        out = []
        a, b = self.html2list(a), self.html2list(b)
        s = difflib.SequenceMatcher(None, a, b)
    
        for e in s.get_opcodes():
            if e[0] == "replace":
                self.num_replace += 1
                out.append('<del class="diff modified">'+''.join(a[e[1]:e[2]]) + '</del><ins class="diff modified">'+''.join(b[e[3]:e[4]])+"</ins>")
            elif e[0] == "delete":
                self.num_delete += 1
                out.append('<del class="diff">'+ ''.join(a[e[1]:e[2]]) + "</del>")
            elif e[0] == "insert":
                self.num_insert += 1
                out.append('<ins class="diff">'+''.join(b[e[3]:e[4]]) + "</ins>")
            elif e[0] == "equal":
                out.append(''.join(b[e[3]:e[4]]))
            else: 
                raise "Um, something's broken. I didn't expect a '" + `e[0]` + "'."
                
        self.diffText = ''.join(out)

    def html2list(self, x, b=0):
        mode = 'char'
        cur = ''
        out = []
        for c in x:
            if mode == 'tag':
                if c == '>': 
                    if b: cur += ']'
                    else: cur += c
                    out.append(cur); cur = ''; mode = 'char'
                else: cur += c
            elif mode == 'char':
                if c == '<': 
                    out.append(cur)
                    if b: cur = '['
                    else: cur = c
                    mode = 'tag'
                elif c in string.whitespace: out.append(cur+c); cur = ''
                else: cur += c
        out.append(cur)
        return filter(lambda x: x is not '', out)


from difflib import SequenceMatcher

class TextDiff:
    """Create diffs of text snippets."""

    def __init__(self, source, target):
        """source = source text - target = target text"""
        self.nl = "<NL>"
        self.delTag = "<span class='deleted'>%s</span>"
        self.insTag = "<span class='inserted'>%s</span>"
        self.source = source.replace("\n", "\n%s" % self.nl).split()
        self.target = target.replace("\n", "\n%s" % self.nl).split()
        self.deleteCount, self.insertCount, self.replaceCount = 0, 0, 0
        self.diffText = None
        self.cruncher = SequenceMatcher(None, self.source,
                                 self.target)
        self._buildDiff()

    def _buildDiff(self):
        """Create a tagged diff."""
        outputList = []
        for tag, alo, ahi, blo, bhi in self.cruncher.get_opcodes():
           if tag == 'replace':
              # Text replaced = deletion + insertion
              outputList.append(self.delTag % " ".join(self.source[alo:ahi]))
              outputList.append(self.insTag % " ".join(self.target[blo:bhi]))
              self.replaceCount += 1
           elif tag == 'delete':
              # Text deleted
              outputList.append(self.delTag % " ".join(self.source[alo:ahi]))
              self.deleteCount += 1
           elif tag == 'insert':
              # Text inserted
              outputList.append(self.insTag % " ".join(self.target[blo:bhi]))
              self.insertCount += 1
           elif tag == 'equal':
              # No change
              outputList.append(" ".join(self.source[alo:ahi]))
        diffText = " ".join(outputList)
        diffText = " ".join(diffText.split())
        self.diffText = diffText.replace(self.nl, "\n")

    def getStats(self):
        "Return a tuple of stat values."
        return (self.insertCount, self.deleteCount, self.replaceCount)

    def getDiff(self):
        "Return the diff text."
        return self.diffText

if __name__ == "__main__":
    ch1 = """Today, pythonistas raised in the shadows of the Cold
    War assumes responsibilities in a world warmed by the sunshine of
    spam and freedom"""

    ch2 = """Today, pythonistas raised in the shadows of the Cold
    War assumes responsibilities in a world warmed by the sunshine of
    spam and freedom."""

    differ = TextDiff(ch1, ch2)

    print "%i insertion(s), %i deletion(s), %i replacement(s)" % differ.getStats()
    print differ.getDiff()
    
    html_differ = HTMLDiff(ch1, ch2)
    print html_differ.getDiff()
    print html_differ.getStats()
    