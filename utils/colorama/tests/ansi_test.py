
import sys
from unittest2 import TestCase, main

from ..ansi import Fore, Back, Style
from ..ansitowin32 import AnsiToWin32


stdout_orig = sys.stdout
stderr_orig = sys.stderr


class AnsiTest(TestCase):
    
    def setUp(self):
        # sanity check: stdout should be a file or StringIO object.
        # It will only be AnsiToWin32 if init() has previously wrapped it
        self.assertNotEqual(type(sys.stdout), AnsiToWin32)
        self.assertNotEqual(type(sys.stderr), AnsiToWin32)

    def tearDown(self):
        sys.stdout = stdout_orig
        sys.stderr = stderr_orig


    def testForeAttributes(self):
        self.assertEquals(Fore.BLACK, '\033[30m')
        self.assertEquals(Fore.RED, '\033[31m')
        self.assertEquals(Fore.GREEN, '\033[32m')
        self.assertEquals(Fore.YELLOW, '\033[33m')
        self.assertEquals(Fore.BLUE, '\033[34m')
        self.assertEquals(Fore.MAGENTA, '\033[35m')
        self.assertEquals(Fore.CYAN, '\033[36m')
        self.assertEquals(Fore.WHITE, '\033[37m')
        self.assertEquals(Fore.RESET, '\033[39m')


    def testBackAttributes(self):
        self.assertEquals(Back.BLACK, '\033[40m')
        self.assertEquals(Back.RED, '\033[41m')
        self.assertEquals(Back.GREEN, '\033[42m')
        self.assertEquals(Back.YELLOW, '\033[43m')
        self.assertEquals(Back.BLUE, '\033[44m')
        self.assertEquals(Back.MAGENTA, '\033[45m')
        self.assertEquals(Back.CYAN, '\033[46m')
        self.assertEquals(Back.WHITE, '\033[47m')
        self.assertEquals(Back.RESET, '\033[49m')


    def testStyleAttributes(self):
        self.assertEquals(Style.DIM, '\033[2m')
        self.assertEquals(Style.NORMAL, '\033[22m')
        self.assertEquals(Style.BRIGHT, '\033[1m')


if __name__ == '__main__':
    main()

