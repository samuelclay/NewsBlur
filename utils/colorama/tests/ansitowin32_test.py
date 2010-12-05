
from unittest2 import TestCase, main
from mock import Mock, patch

from .utils import platform

from ..ansi import Style
from ..ansitowin32 import AnsiToWin32, StreamWrapper



class StreamWrapperTest(TestCase):

    def testIsAProxy(self):
        mockStream = Mock()
        wrapper = StreamWrapper(mockStream, None)
        self.assertTrue( wrapper.random_attr is mockStream.random_attr )

    def testDelegatesWrite(self):
        mockStream = Mock()
        mockConverter = Mock()
        wrapper = StreamWrapper(mockStream, mockConverter)
        wrapper.write('hello')
        self.assertTrue(mockConverter.write.call_args, (('hello',), {}))


class AnsiToWin32Test(TestCase):

    def testInit(self):
        mockStdout = object()
        auto = object()
        stream = AnsiToWin32(mockStdout, autoreset=auto)
        self.assertEquals(stream.wrapped, mockStdout)
        self.assertEquals(stream.autoreset, auto)

    @patch('colorama.ansitowin32.winterm', None)
    def testStripIsTrueOnWindows(self):
        with platform('windows'):
            stream = AnsiToWin32(None)
            self.assertTrue(stream.strip)

    def testStripIsFalseOffWindows(self):
        with platform('darwin'):
            stream = AnsiToWin32(None)
            self.assertFalse(stream.strip)


    def testWriteStripsAnsi(self):
        mockStdout = Mock()
        stream = AnsiToWin32(mockStdout)
        stream.wrapped = Mock()
        stream.write_and_convert = Mock()
        stream.strip = True

        stream.write('abc')

        self.assertFalse(stream.wrapped.write.called)
        self.assertEquals(stream.write_and_convert.call_args, (('abc',), {}))


    def testWriteDoesNotStripAnsi(self):
        mockStdout = Mock()
        stream = AnsiToWin32(mockStdout)
        stream.wrapped = Mock()
        stream.write_and_convert = Mock()
        stream.strip = False
        stream.convert = False

        stream.write('abc')
        
        self.assertFalse(stream.write_and_convert.called)
        self.assertEquals(stream.wrapped.write.call_args, (('abc',), {}))


    def assert_autoresets(self, convert, autoreset=True):
        stream = AnsiToWin32(Mock())
        stream.convert = convert
        stream.reset_all = Mock()
        stream.autoreset = autoreset
        stream.winterm = Mock()

        stream.write('abc')
        
        self.assertEquals(stream.reset_all.called, autoreset)

    def testWriteAutoresets(self):
        self.assert_autoresets(convert=True)
        self.assert_autoresets(convert=False)
        self.assert_autoresets(convert=True, autoreset=False)
        self.assert_autoresets(convert=False, autoreset=False)

    def testWriteAndConvertWritesPlainText(self):
        stream = AnsiToWin32(Mock())
        stream.write_and_convert( 'abc' )
        self.assertEquals( stream.wrapped.write.call_args, (('abc',), {}) )

    def testWriteAndConvertStripsAllValidAnsi(self):
        stream = AnsiToWin32(Mock())
        stream.call_win32 = Mock()
        data = [
            'abc\033[mdef',
            'abc\033[0mdef',
            'abc\033[2mdef',
            'abc\033[02mdef',
            'abc\033[002mdef',
            'abc\033[40mdef',
            'abc\033[040mdef',
            'abc\033[0;1mdef',
            'abc\033[40;50mdef',
            'abc\033[50;30;40mdef',
            'abc\033[Adef',
            'abc\033[0Gdef',
            'abc\033[1;20;128Hdef',
        ]
        for datum in data:
            stream.wrapped.write.reset_mock()
            stream.write_and_convert( datum )
            self.assertEquals(
               [args[0] for args in stream.wrapped.write.call_args_list],
               [ ('abc',), ('def',) ]
            )

    def testWriteAndConvertSkipsEmptySnippets(self):
        stream = AnsiToWin32(Mock())
        stream.call_win32 = Mock()
        stream.write_and_convert( '\033[40m\033[41m' )
        self.assertFalse( stream.wrapped.write.called )

    def testWriteAndConvertCallsWin32WithParamsAndCommand(self):
        stream = AnsiToWin32(Mock())
        stream.convert = True
        stream.call_win32 = Mock()
        stream.extract_params = Mock(return_value='params')
        data = {
            'abc\033[adef':         ('a', 'params'),
            'abc\033[;;bdef':       ('b', 'params'),
            'abc\033[0cdef':        ('c', 'params'),
            'abc\033[;;0;;Gdef':    ('G', 'params'),
            'abc\033[1;20;128Hdef': ('H', 'params'),
        }
        for datum, expected in data.items():
            stream.call_win32.reset_mock()
            stream.write_and_convert( datum )
            self.assertEquals( stream.call_win32.call_args[0], expected )

    def testExtractParams(self):
        stream = AnsiToWin32(Mock())
        data = {
            '':               (),
            ';;':             (),
            '2':              (2,),
            ';;002;;':        (2,),
            '0;1':            (0, 1),
            ';;003;;456;;':   (3, 456),
            '11;22;33;44;55': (11, 22, 33, 44, 55),
        }
        for datum, expected in data.items():
            self.assertEquals(stream.extract_params(datum), expected)

    def testCallWin32UsesLookup(self):
        listener = Mock()
        stream = AnsiToWin32(listener)
        stream.win32_calls = {
            1: (lambda *_, **__: listener(11),),
            2: (lambda *_, **__: listener(22),),
            3: (lambda *_, **__: listener(33),),
        }
        stream.call_win32('m', (3, 1, 99, 2))
        self.assertEquals(
            [a[0][0] for a in listener.call_args_list],
            [33, 11, 22] )

    def testCallWin32DefaultsToParams0(self):
        mockStdout = Mock()
        stream = AnsiToWin32(mockStdout)
        stream.win32_calls = {0: (mockStdout.reset,)}
        
        stream.call_win32('m', [])

        self.assertTrue(mockStdout.reset.called)


if __name__ == '__main__':
    main()

