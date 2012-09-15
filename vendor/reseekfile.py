"""Wrap a file handle to allow seeks back to the beginning

Sometimes data coming from a socket or other input file handle isn't
what it was supposed to be.  For example, suppose you are reading from
a buggy server which is supposed to return an XML stream but can also
return an unformatted error message.  (This often happens because the
server doesn't handle incorrect input very well.)

A ReseekFile helps solve this problem.  It is a wrapper to the
original input stream but provides a buffer.  Read requests to the
ReseekFile get forwarded to the input stream, appended to a buffer,
then returned to the caller.  The buffer contains all the data read so
far.

The ReseekFile can be told to reseek to the start position.  The next
read request will come from the buffer, until the buffer has been
read, in which case it gets the data from the input stream.  This
newly read data is also appended to the buffer.

When buffering is no longer needed, use the 'nobuffer()' method.  This
tells the ReseekFile that once it has read from the buffer it should
throw the buffer away.  After nobuffer is called, the behaviour of
'seek' is no longer defined.

For example, suppose you have the server as above which either
gives an error message is of the form:

  ERROR: cannot do that

or an XML data stream, starting with "<?xml".

  infile = urllib2.urlopen("http://somewhere/")
  infile = ReseekFile.ReseekFile(infile)
  s = infile.readline()
  if s.startswith("ERROR:"):
      raise Exception(s[:-1])
  infile.seek(0)
  infile.nobuffer()   # Don't buffer the data
   ... process the XML from infile ...


This module also implements 'prepare_input_source(source)' modeled on
xml.sax.saxutils.prepare_input_source.  This opens a URL and if the
input stream is not already seekable, wraps it in a ReseekFile.


NOTE:
  Don't use bound methods for the ReseekFile.  When the buffer is
empty, the ReseekFile reassigns the input file's read/readlines/etc.
method as instance variable.  This gives slightly better performance
at the cost of not allowing an infrequently used idiom.

  Use tell() to get the beginning byte location.  ReseekFile will
attempt to get the real position from the wrapped file and use that as
the beginning location.  If the wrapped file does not support tell(),
ReseekFile.tell() will return 0.

  readlines does not yet support a sizehint.  Want to implement it?

The latest version of this code can be found at
  http://www.dalkescientific.com/Python/
"""
# Started in 2003 by Andrew Dalke, Dalke Scientific Software, LLC.
# This software has been released to the public domain.  No
# copyright is asserted.

## Changelog:
# 2005-11-06
#   Use StringIO if cStringIO doesn't exist.  Suggested by Howard Golden
#   for use with non-CPython implementations.
# 2005-05-18
#   Can specify a factory to specify how to create the temporary file.
#   Factories for memory-based (cStringIO) and file-based storages
#   Track the buffer file size so I don't depend on getvalue()
#   Fixed a few typos

def memory_backed_tempfile():
    try:
        from cStringIO import StringIO
    except ImportError:
        from StringIO import StringIO
    return StringIO()

def file_backed_tempfile():
    import tempfile
    return tempfile.NamedTemporaryFile(mode="r+b")

class ReseekFile:
    """wrap a file handle to allow seeks back to the beginning

    Takes a file handle in the constructor.
    
    See the module docstring for more documentation.
    """
    def __init__(self, file, tempfile_factory = memory_backed_tempfile):
        self.file = file
        self.buffer_file = tempfile_factory()
        self.at_beginning = 1
        try:
            self.beginning = file.tell()
        except (IOError, AttributeError):
            self.beginning = 0
        self._use_buffer = 1
        self._buffer_size = 0
        
    def seek(self, offset, whence = 0):
        """offset, whence = 0

        Seek to a given byte position.  Only supports whence == 0
        and offset == the initial value of ReseekFile.tell() (which
        is usually 0, but not always.)
        """
        if whence != 0:
            raise TypeError("Unexpected whence value of %s; expecting 0" % \
                            (whence,))
        if offset != self.beginning:
            raise TypeError("Unexpected offset value of %r; expecting '%s'" % \
                             (offset, self.beginning))
        self.buffer_file.seek(0)
        self.at_beginning = 1
        
    def tell(self):
        """the current position of the file

        The initial position may not be 0 if the underlying input
        file supports tell and it not at position 0.
        """
        if not self.at_beginning:
            raise TypeError("ReseekFile cannot tell except at the beginning of file")
        return self.beginning

    def _read(self, size):
        if size < 0:
            y = self.file.read()
            z = self.buffer_file.read() + y
            if self._use_buffer:
                self.buffer_file.write(y)
                self._buffer_size += len(y)
            return z
        if size == 0:
            return ""
        x = self.buffer_file.read(size)
        if len(x) < size:
            y = self.file.read(size - len(x))
            if self._use_buffer:
                self.buffer_file.write(y)
                self._buffer_size += len(y)
            return x + y
        return x
        
    def read(self, size = -1):
        """read up to 'size' bytes from the file

        Default is -1, which means to read to end of file.
        """
        x = self._read(size)
        if self.at_beginning and x:
            self.at_beginning = 0
        self._check_no_buffer()
        return x

    def readline(self):
        """read a line from the file"""

        # Can we get it out of the buffer_file?
        s = self.buffer_file.readline()
        if s[-1:] == "\n":
            return s
        # No, so now we read a line from the input file
        t = self.file.readline()

        # Append the new data to the buffer, if still buffering
        if self._use_buffer:
            self.buffer_file.write(t)
            self._buffer_size += len(t)        
        self._check_no_buffer()

        return s + t

    def readlines(self):
        """read all remaining lines from the file"""
        s = self.read()
        lines = []
        i, j = 0, s.find("\n")
        while j > -1:
            lines.append(s[i:j+1])
            i = j+1
            j = s.find("\n", i)
        if i < len(s):
            # Only get here if the last line doesn't have a newline
            lines.append(s[i:])
        return lines

    def _check_no_buffer(self):
        # If 'nobuffer' called and finished with the buffer file
        # then get rid of the buffer and redirect everything to
        # the original input file.
        if (self._use_buffer == 0 and 
            (self.buffer_file.tell() == self._buffer_size)):
            # I'm doing this for the slightly better performance
            self.seek = getattr(self.file, "seek", None)
            self.tell = getattr(self.file, "tell", None)
            self.read = self.file.read
            self.readline = self.file.readline
            self.readlines = self.file.readlines
            del self.buffer_file

    def nobuffer(self):
        """tell the ReseekFile to stop using the buffer once it's exhausted"""
        self._use_buffer = 0

def prepare_input_source(source):
    """given a URL, returns a xml.sax.xmlreader.InputSource

    Works like xml.sax.saxutils.prepare_input_source.  Wraps the
    InputSource in a ReseekFile if the URL returns a non-seekable
    file.

    To turn the buffer off if that happens, you'll need to do
    something like

    f = source.getCharacterStream()
     ...
    try:
       f.nobuffer()
    except AttributeError:
       pass

    or

    if isinstance(f, ReseekFile):
      f.nobuffer()
    
    """
    from xml.sax import saxutils
    source = saxutils.prepare_input_source(source)
    # Is this correct?  Don't know - don't have Unicode experience
    f = source.getCharacterStream() or source.getByteStream()
    try:
        f.tell()
    except (AttributeError, IOError):
        f = ReseekFile.ReseekFile(f)
        source.setByteStream(f)
        source.setCharacterStream(None)
    return source

def test_reads(test_s, file, seek0):
    assert file.read(2) == "Th"
    assert file.read(3) == "is "
    assert file.read(4) == "is a"
    assert file.read(0) == ""
    assert file.read(0) == ""
    assert file.read(6) == " test."
    file.seek(seek0)
    assert file.read(2) == "Th"
    assert file.read(3) == "is "
    assert file.read(4) == "is a"
    assert file.read(0) == ""
    assert file.read(0) == ""
    assert file.read(6) == " test."
    assert file.read(1) == "\n"
    assert file.read(5) == "12345"
    assert file.read() == "67890\n"
    file.seek(seek0)
    assert file.read() == test_s
    file.seek(seek0)

    
def _test(ReseekFileFactory):
    from cStringIO import StringIO
    s = "This is a test.\n1234567890\n"
    file = StringIO(s)
    # Test with a normal file
    x = file.tell()
    test_reads(s, file, x)
    test_reads(s, file, x)

    # Test with a ReseekFile wrapper
    rf = ReseekFileFactory(file)
    y = rf.tell()
    rf.seek(y)
    test_reads(s, rf, y)
    assert rf.read() == s
    assert rf.read() == ""

    # Make sure the tell offset is correct (may not be 0)
    file = StringIO("X" + s)
    file.read(1)
    rf = ReseekFileFactory(file)
    y = rf.tell()
    test_reads(s, rf, y)
    rf.seek(y)
    test_reads(s, rf, y)
    assert rf.read() == s
    assert rf.read() == ""

    # Test the ability to turn off buffering and have changes
    # propogate correctly
    file = StringIO("X" + s)
    file.read(1)
    rf = ReseekFileFactory(file)
    y = rf.tell()
    assert y == 1
    rf.read(1000)
    rf.seek(y)
    rf.nobuffer()
    assert rf.tell() == y
    test_reads(s, rf, y)
    rf.seek(y)
    test_reads(s, rf, y)
    assert rf.read() == s
    assert rf.read() == ""

    # turn off buffering after partial reads
    file = StringIO("X" + s)
    file.read(1)
    rf = ReseekFileFactory(file)
    y = rf.tell()
    rf.read(5)
    rf.seek(y)
    rf.nobuffer()
    assert rf.read() == s

    file = StringIO("X" + s)
    file.read(1)
    rf = ReseekFileFactory(file)
    y = rf.tell()
    t = rf.read(5)
    rf.seek(y)
    rf.nobuffer()
    assert rf.read(5) == t

    file = StringIO("X" + s)
    file.read(1)
    rf = ReseekFileFactory(file)
    y = rf.tell()
    t = rf.read(5)
    assert t == s[:5]
    rf.seek(y)
    rf.nobuffer()
    assert rf.read(8) == s[:8]

    file = StringIO("X" + s)
    file.read(1)
    rf = ReseekFileFactory(file)
    y = rf.tell()
    t = rf.read(5)
    assert t == s[:5]
    rf.nobuffer()
    assert rf.read(8) == s[5:5+8]

    # Should only do this test on Unix systems
    import os
    infile = os.popen("echo HELLO_THERE")
    infile.read(1)
    rf = ReseekFileFactory(infile)
    y = rf.tell()
    assert rf.read(1) == "E"
    assert rf.read(2) == "LL"
    rf.seek(y)
    assert rf.read(4) == "ELLO"
    rf.seek(y)
    assert rf.read(1) == "E"
    rf.nobuffer()
    assert rf.read(1) == "L"
    assert rf.read(4) == "LO_T"
    assert rf.read(4) == "HERE"
    try:
        rf.seek(y)
        raise AssertionError("Cannot seek here!")
    except IOError:
        pass
    try:
        rf.tell()
        raise AssertionError("Cannot tell here!")
    except IOError:
        pass

    # Check if readline/readlines works
    s = "This is line 1.\nAnd line 2.\nAnd now, page 3!"
    file = StringIO(s)
    rf = ReseekFileFactory(file)
    rf.read(1)
    assert rf.readline() == "his is line 1.\n"
    rf.seek(0)
    assert rf.readline() == "This is line 1.\n"
    rf.read(2)
    assert rf.readline() == "d line 2.\n"
    rf.seek(0)
    assert rf.readlines() == ["This is line 1.\n",
                              "And line 2.\n",
                              "And now, page 3!"]

    rf.seek(0)
    rf.read(len(s))
    assert rf.readlines() == []
    rf.seek(0)

    # Now there is a final newline
    s = "This is line 1.\nAnd line 2.\nAnd now, page 3!\n"
    rf = ReseekFileFactory(StringIO(s))
    rf.read(1)
    rf.seek(0)
    rf.nobuffer()
    assert rf.readlines() == ["This is line 1.\n",
                              "And line 2.\n",
                              "And now, page 3!\n"]
    
def test():
    _test(ReseekFile)

    # Test with a different backing store.  Make sure that I'm
    # using the backing store.
    was_called = [0]
    def file_backed(infile):
        was_called[0] = 1
        return ReseekFile(infile, file_backed_tempfile)
    _test(file_backed)
    if not was_called[0]:
        raise AssertionError("file_backed_tempfile was not called")

    import cStringIO
    f = cStringIO.StringIO("Andrew")
    g = ReseekFile(f, file_backed_tempfile)
    if not hasattr(g.buffer_file, "name"):
        raise AssertionError("backend file not created")
    
if __name__ == "__main__":
    test()
    print "All tests passed."