# CSSTidy - CSS Parse
#
# CSS Parser class
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

import re

from optimizer import CSSOptimizer
from output import CSSPrinter
import data
from tools import SortedDict

class CSSTidy(object):
    #Saves the parsed CSS
    _css = ""
    _raw_css = SortedDict()
    _optimized_css = SortedDict()

    #List of Tokens
    _tokens = []

    #Printer class
    _output = None

    #Optimiser class
    _optimizer = None

    #Saves the CSS charset (@charset)
    _charset = ''

    #Saves all @import URLs
    _import = []

    #Saves the namespace
    _namespace = ''

    #Contains the version of csstidy
    _version = '1.3'

    #Stores the settings
    _settings = {}

    # Saves the parser-status.
    #
    # Possible values:
    # - is = in selector
    # - ip = in property
    # - iv = in value
    # - instr = in string (started at " or ' or ( )
    # - ic = in comment (ignore everything)
    # - at = in @-block
    _status = 'is'

    #Saves the current at rule (@media)
    _at = ''

    #Saves the current selector
    _selector = ''

    #Saves the current property
    _property = ''

    #Saves the position of , in selectors
    _sel_separate = []

    #Saves the current value
    _value = ''

    #Saves the current sub-value
    _sub_value = ''

    #Saves all subvalues for a property.
    _sub_value_arr = []

    #Saves the char which opened the last string
    _str_char = ''
    _cur_string = ''

    #Status from which the parser switched to ic or instr
    _from = ''

    #Variable needed to manage string-in-strings, for example url("foo.png")
    _str_in_str = False

    #=True if in invalid at-rule
    _invalid_at = False

    #=True if something has been added to the current selector
    _added = False

    #Saves the message log
    _log = SortedDict()

    #Saves the line number
    _line = 1

    def __init__(self):
        self._settings['remove_bslash'] = True
        self._settings['compress_colors'] = True
        self._settings['compress_font-weight'] = True
        self._settings['lowercase_s'] = False
        self._settings['optimise_shorthands'] = 2
        self._settings['remove_last_'] = False
        self._settings['case_properties'] = 1
        self._settings['sort_properties'] = False
        self._settings['sort_selectors'] = False
        self._settings['merge_selectors'] = 2
        self._settings['discard_invalid_properties'] = False
        self._settings['css_level'] = 'CSS2.1'
        self._settings['preserve_css'] = False
        self._settings['timestamp'] = False
        self._settings['template'] = 'highest_compression'

        #Maps self._status to methods
        self.__statusMethod = {'is':self.__parseStatus_is, 'ip': self.__parseStatus_ip, 'iv':self.__parseStatus_iv, 'instr':self.__parseStatus_instr, 'ic':self.__parseStatus_ic, 'at':self.__parseStatus_at}

        self._output = CSSPrinter(self)
        self._optimizer = CSSOptimizer(self)

    #Public Methods
    def getSetting(self, setting):
        return self._settings.get(setting, False)

    #Set the value of a setting.
    def setSetting(self, setting, value):
        self._settings[setting] = value
        return True

    def log(self, message, ttype, line = -1):
        if line == -1:
            line = self._line

        line = int(line)

        add = {'m': message, 't': ttype}

        if not self._log.has_key(line):
            self._log[line] = []
            self._log[line].append(add)
        elif add not in self._log[line]:
            self._log[line].append(add)


    #Checks if a character is escaped (and returns True if it is)
    def escaped(self, string, pos):
        return not (string[pos-1] != '\\' or self.escaped(string, pos-1))

    #Adds CSS to an existing media/selector
    def merge_css_blocks(self, media, selector, css_add):
        for prop, value in css_add.iteritems():
            self.__css_add_property(media, selector, prop, value, False)

    #Checks if $value is !important.
    def is_important(self, value):
        return '!important' in value.lower()

    #Returns a value without !important
    def gvw_important(self, value):
        if self.is_important(value):
            ret = value.strip()
            ret = ret[0:-9]
            ret = ret.strip()
            ret = ret[0:-1]
            ret = ret.strip()
            return ret

        return value

    def parse(self, cssString):
        #Switch from \r\n to \n
        self._css = cssString.replace("\r\n", "\n") + ' '
        self._raw_css = {}
        self._optimized_css = {}
        self._curComment = ''

        #Start Parsing
        i = 0
        while i < len(cssString):
            if self._css[i] == "\n" or self._css[i] == "\r":
                self._line += 1

            i += self.__statusMethod[self._status](i)

            i += 1;

        self._optimized_css = self._optimizer.optimize(self._raw_css)

    def parseFile(self, filename):
        try:
            f = open(filename, "r")
            self.parse(f.read())
        finally:
            f.close()

    #Private Methods
    def __parseStatus_is(self, idx):
        """
            Parse in Selector
        """
        ret = 0

        if self.__is_token(self._css, idx):
            if self._css[idx] == '/' and self._css[idx+1] == '*' and self._selector.strip() == '':
                self._status = 'ic'
                self._from = 'is'
                return 1

            elif self._css[idx] == '@' and self._selector.strip() == '':
                #Check for at-rule
                self._invalid_at = True

                for name, ttype in data.at_rules.iteritems():
                    if self._css[idx+1:len(name)].lower() == name.lower():
                        if ttype == 'at':
                            self._at = '@' + name
                        else:
                            self._selector = '@' + name

                        self._status = ttype
                        self._invalid_at = False
                        ret += len(name)

                if self._invalid_at:
                    self._selector = '@'
                    invalid_at_name = ''
                    for j in xrange(idx+1, len(self._css)):
                        if not self._css[j].isalpha():
                            break;

                        invalid_at_name += self._css[j]

                    self.log('Invalid @-rule: ' + invalid_at_name + ' (removed)', 'Warning')

            elif self._css[idx] == '"' or self._css[idx] == "'":
                self._cur_string = self._css[idx]
                self._status = 'instr'
                self._str_char = self._css[idx]
                self._from = 'is'

            elif self._invalid_at and self._css[idx] == ';':
                self._invalid_at = False
                self._status = 'is'

            elif self._css[idx] == '{':
                self._status = 'ip'
                self.__add_token(data.SEL_START, self._selector)
                self._added = False;

            elif self._css[idx] == '}':
                self.__add_token(data.AT_END, self._at)
                self._at = ''
                self._selector = ''
                self._sel_separate = []

            elif self._css[idx] == ',':
                self._selector = self._selector.strip() + ','
                self._sel_separate.append(len(self._selector))

            elif self._css[idx] == '\\':
                self._selector += self.__unicode(idx)

            #remove unnecessary universal selector,  FS#147
            elif not (self._css[idx] == '*' and self._css[idx+1] in ('.', '#', '[', ':')):
                self._selector += self._css[idx]

        else:
            lastpos = len(self._selector)-1

            if lastpos == -1 or not ((self._selector[lastpos].isspace() or self.__is_token(self._selector, lastpos) and self._selector[lastpos] == ',') and self._css[idx].isspace()):
                self._selector += self._css[idx]

        return ret

    def __parseStatus_ip(self, idx):
        """
            Parse in property
        """
        if self.__is_token(self._css, idx):
            if (self._css[idx] == ':' or self._css[idx] == '=') and self._property != '':
                self._status = 'iv'

                if not self.getSetting('discard_invalid_properties') or self.__property_is_valid(self._property):
                    self.__add_token(data.PROPERTY, self._property)

            elif self._css[idx] == '/' and self._css[idx+1] == '*' and self._property == '':
                self._status = 'ic'
                self._from = 'ip'
                return 1

            elif self._css[idx] == '}':
                self.__explode_selectors()
                self._status = 'is'
                self._invalid_at = False
                self.__add_token(data.SEL_END, self._selector)
                self._selector = ''
                self._property = ''

            elif self._css[idx] == ';':
                self._property = ''

            elif self._css[idx] == '\\':
                self._property += self.__unicode(idx)

        elif not self._css[idx].isspace():
            self._property += self._css[idx]

        return 0

    def __parseStatus_iv(self, idx):
        """
            Parse in value
        """
        pn = (( self._css[idx] == "\n" or self._css[idx] == "\r") and self.__property_is_next(idx+1) or idx == len(self._css)) #CHECK#
        if self.__is_token(self._css, idx) or pn:
            if self._css[idx] == '/' and self._css[idx+1] == '*':
                self._status = 'ic'
                self._from = 'iv'
                return 1

            elif self._css[idx] == '"' or self._css[idx] == "'" or self._css[idx] == '(':
                self._cur_string = self._css[idx]
                self._str_char = ')' if self._css[idx] == '(' else self._css[idx]
                self._status = 'instr'
                self._from = 'iv'

            elif self._css[idx] == ',':
                self._sub_value = self._sub_value.strip() + ','

            elif self._css[idx] == '\\':
                self._sub_value += self.__unicode(idx)

            elif self._css[idx] == ';' or pn:
                if len(self._selector) > 0 and self._selector[0] == '@' and data.at_rules.has_key(self._selector[1:]) and data.at_rules[self._selector[1:]] == 'iv':
                    self._sub_value_arr.append(self._sub_value.strip())

                    self._status = 'is'

                    if '@charset' in self._selector:
                        self._charset = self._sub_value_arr[0]

                    elif '@namespace' in self._selector:
                        self._namespace = ' '.join(self._sub_value_arr)

                    elif '@import' in self._selector:
                        self._import.append(' '.join(self._sub_value_arr))


                    self._sub_value_arr = []
                    self._sub_value = ''
                    self._selector = ''
                    self._sel_separate = []

                else:
                    self._status = 'ip'

            elif self._css[idx] != '}':
                self._sub_value += self._css[idx]

            if (self._css[idx] == '}' or self._css[idx] == ';' or pn) and self._selector != '':
                if self._at == '':
                    self._at = data.DEFAULT_AT

                #case settings
                if self.getSetting('lowercase_s'):
                    self._selector = self._selector.lower()

                self._property = self._property.lower()

                if self._sub_value != '':
                    self._sub_value_arr.append(self._sub_value)
                    self._sub_value = ''

                self._value = ' '.join(self._sub_value_arr)


                self._selector = self._selector.strip()

                valid = self.__property_is_valid(self._property)

                if (not self._invalid_at or self.getSetting('preserve_css')) and (not self.getSetting('discard_invalid_properties') or valid):
                    self.__css_add_property(self._at, self._selector, self._property, self._value)
                    self.__add_token(data.VALUE, self._value)

                if not valid:
                    if self.getSetting('discard_invalid_properties'):
                        self.log('Removed invalid property: ' + self._property, 'Warning')

                    else:
                        self.log('Invalid property in ' + self.getSetting('css_level').upper() + ': ' + self._property, 'Warning')

                self._property = '';
                self._sub_value_arr = []
                self._value = ''

            if self._css[idx] == '}':
                self.__explode_selectors()
                self.__add_token(data.SEL_END, self._selector)
                self._status = 'is'
                self._invalid_at = False
                self._selector = ''

        elif not pn:
            self._sub_value += self._css[idx]

            if self._css[idx].isspace():
                if self._sub_value != '':
                    self._sub_value_arr.append(self._sub_value)
                    self._sub_value = ''

        return 0

    def __parseStatus_instr(self, idx):
        """
            Parse in String
        """
        if self._str_char == ')' and (self._css[idx] == '"' or self._css[idx] == "'") and not self.escaped(self._css, idx):
            self._str_in_str = not self._str_in_str

        temp_add = self._css[idx] # ...and no not-escaped backslash at the previous position
        if (self._css[idx] == "\n" or self._css[idx] == "\r") and not (self._css[idx-1] == '\\' and not self.escaped(self._css, idx-1)):
            temp_add = "\\A "
            self.log('Fixed incorrect newline in string', 'Warning')

        if not (self._str_char == ')' and self._css[idx].isspace() and not self._str_in_str):
            self._cur_string += temp_add

        if self._css[idx] == self._str_char and not self.escaped(self._css, idx) and not self._str_in_str:
            self._status = self._from
            regex = re.compile(r'([\s]+)', re.I | re.U | re.S)
            if regex.match(self._cur_string) is None and self._property != 'content':
                if self._str_char == '"' or self._str_char == "'":
                    self._cur_string = self._cur_string[1:-1]

                elif len(self._cur_string) > 3 and (self._cur_string[1] == '"' or self._cur_string[1] == "'"):
                    self._cur_string = self._cur_string[0] + self._cur_string[2:-2] + self._cur_string[-1]

            if self._from == 'iv':
                self._sub_value += self._cur_string

            elif self._from == 'is':
                self._selector += self._cur_string

        return 0

    def __parseStatus_ic(self, idx):
        """
            Parse css In Comment
        """
        if self._css[idx] == '*' and self._css[idx+1] == '/':
            self._status = self._from
            self.__add_token(data.COMMENT, self._curComment)
            self._curComment = ''
            return 1

        else:
            self._curComment += self._css[idx]

        return 0

    def __parseStatus_at(self, idx):
        """
            Parse in at-block
        """
        if self.__is_token(string, idx):
            if self._css[idx] == '/' and self._css[idx+1] == '*':
                self._status = 'ic'
                self._from = 'at'
                return 1

            elif self._css[i] == '{':
                self._status = 'is'
                self.__add_token(data.AT_START, self._at)

            elif self._css[i] == ',':
                self._at = self._at.strip() + ','

            elif self._css[i] == '\\':
                self._at += self.__unicode(i)
        else:
            lastpos = len(self._at)-1
            if not (self._at[lastpos].isspace() or self.__is_token(self._at, lastpos) and self._at[lastpos] == ',') and self._css[i].isspace():
                self._at += self._css[i]

        return 0

    def __explode_selectors(self):
        #Explode multiple selectors
        if self.getSetting('merge_selectors') == 1:
            new_sels = []
            lastpos = 0;
            self._sel_separate.append(len(self._selector))

            for num in xrange(len(self._sel_separate)):
                pos = self._sel_separate[num]
                if num == (len(self._sel_separate)): #CHECK#
                    pos += 1

                new_sels.append(self._selector[lastpos:(pos-lastpos-1)])
                lastpos = pos

            if len(new_sels) > 1:
                for selector in new_sels:
                    self.merge_css_blocks(self._at, selector, self._raw_css[self._at][self._selector])

                del self._raw_css[self._at][self._selector]

        self._sel_separate = []

    #Adds a property with value to the existing CSS code
    def __css_add_property(self, media, selector, prop, new_val):
        if self.getSetting('preserve_css') or new_val.strip() == '':
            return

        if not self._raw_css.has_key(media):
            self._raw_css[media] = SortedDict()

        if not self._raw_css[media].has_key(selector):
            self._raw_css[media][selector] = SortedDict()

        self._added = True
        if self._raw_css[media][selector].has_key(prop):
            if (self.is_important(self._raw_css[media][selector][prop]) and self.is_important(new_val)) or not self.is_important(self._raw_css[media][selector][prop]):
                del self._raw_css[media][selector][prop]
                self._raw_css[media][selector][prop] = new_val.strip()

        else:
            self._raw_css[media][selector][prop] = new_val.strip()

    #Checks if the next word in a string from pos is a CSS property
    def __property_is_next(self, pos):
        istring = self._css[pos: len(self._css)]
        pos = istring.find(':')
        if pos == -1:
            return False;

        istring = istring[:pos].strip().lower()
        if data.all_properties.has_key(istring):
            self.log('Added semicolon to the end of declaration', 'Warning')
            return True

        return False;

    #Checks if a property is valid
    def __property_is_valid(self, prop):
        return (data.all_properties.has_key(prop) and data.all_properties[prop].find(self.getSetting('css_level').upper()) != -1)

    #Adds a token to self._tokens
    def __add_token(self, ttype, cssdata, do=False):
        if self.getSetting('preserve_css') or do:
            if ttype == data.COMMENT:
                token = [ttype, cssdata]
            else:
                token = [ttype, cssdata.strip()]

            self._tokens.append(token)

    #Parse unicode notations and find a replacement character
    def __unicode(self, idx):
       ##FIX##
       return ''

    #Starts parsing from URL
    ##USED?
    def __parse_from_url(self, url):
        try:
            if "http" in url.lower() or "https" in url.lower():
                f = urllib.urlopen(url)
            else:
                f = open(url)

            data = f.read()
            return self.parse(data)
        finally:
            f.close()

    #Checks if there is a token at the current position
    def __is_token(self, string, idx):
        return (string[idx] in data.tokens and not self.escaped(string, idx))


    #Property Methods
    def _getOutput(self):
        self._output.prepare(self._optimized_css)
        return self._output.render

    def _getLog(self):
        ret = ""
        ks = self._log.keys()
        ks.sort()
        for line in ks:
            for msg in self._log[line]:
                ret += "Type: " + msg['t'] + "\n"
                ret += "Message: " + msg['m'] + "\n"
            ret += "\n"

        return ret

    def _getCSS(self):
        return self._css


    #Properties
    Output = property(_getOutput, None)
    Log = property(_getLog, None)
    CSS = property(_getCSS, None)


if __name__ == '__main__':
    import sys
    tidy = CSSTidy()
    f = open(sys.argv[1], "r")
    css = f.read()
    f.close()
    tidy.parse(css)
    tidy.Output('file', filename="Stylesheet.min.css")
    print tidy.Output()
    #print tidy._import