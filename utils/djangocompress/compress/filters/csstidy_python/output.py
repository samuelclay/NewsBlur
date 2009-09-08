# CSSTidy - CSS Printer
#
# CSS Printer class
#
# This file is part of CSSTidy.
#
# CSSTidy is free software you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation either version 2 of the License, or
# (at your option) any later version.
#
# CSSTidy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CSSTidy if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# @license http://opensource.org/licenses/gpl-license.php GNU Public License
# @package csstidy
# @author Dj Gilcrease (digitalxero at gmail dot com) 2005-2006

import data

class CSSPrinter(object):
    def __init__(self, parser):
        self.parser = parser
        self._css = {}
        self.__renderMethods = {'string': self.__renderString, 'file': self.__renderFile}

#PUBLIC METHODS
    def prepare(self, css):
        self._css = css

    def render(self, output="string", *args, **kwargs):
        return self.__renderMethods[output](*args, **kwargs)

#PRIVATE METHODS
    def __renderString(self, *args, **kwargs):
        ##OPTIMIZE##
        template = self.parser.getSetting('template')
        ret = ""

        if template == 'highest_compression':
            top_line_end = ""
            iner_line_end = ""
            bottom_line_end = ""
            indent = ""

        elif template == 'high_compression':
            top_line_end = "\n"
            iner_line_end = ""
            bottom_line_end = "\n"
            indent = ""

        elif template == 'default':
            top_line_end = "\n"
            iner_line_end = "\n"
            bottom_line_end = "\n\n"
            indent = ""

        elif template == 'low_compression':
            top_line_end = "\n"
            iner_line_end = "\n"
            bottom_line_end = "\n\n"
            indent = "    "

        if self.parser.getSetting('timestamp'):
            ret += '/# CSSTidy ' + self.parser.version + ': ' + datetime.now().strftime("%a, %d %b %Y %H:%M:%S +0000") + ' #/' + top_line_end

        for item in self.parser._import:
            ret += '@import(' + item + ');' + top_line_end

        for item in self.parser._charset:
            ret += '@charset(' + item + ');' + top_line_end

        for item in self.parser._namespace:
            ret += '@namespace(' + item + ');' + top_line_end

        for media, css in self._css.iteritems():
            for selector, cssdata in css.iteritems():
                ret += selector + '{' + top_line_end

                for item, value in cssdata.iteritems():
                    ret += indent +  item + ':' + value + ';' + iner_line_end

                ret += '}' + bottom_line_end

        return ret

    def __renderFile(self, filename=None, *args, **kwargs):
        if filename is None:
            return self.__renderString()

        try:
            f = open(filename, "w")
            f.write(self.__renderString())
        finally:
            f.close()