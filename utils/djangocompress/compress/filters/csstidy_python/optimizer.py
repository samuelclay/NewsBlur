# CSSTidy - CSS Optimizer
#
# CSS Optimizer class
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
from tools import SortedDict


class CSSOptimizer(object):
    def __init__(self, parser):
        #raw_css is a dict
        self.parser = parser
        self._optimized_css = SortedDict


#PUBLIC METHODS
    def optimize(self, raw_css):
        if self.parser.getSetting('preserve_css'):
            return raw_css

        self._optimized_css = raw_css

        if self.parser.getSetting('merge_selectors') == 2:
            self.__merge_selectors()

        ##OPTIMIZE##
        for media, css in self._optimized_css.iteritems():
            for selector, cssdata in css.iteritems():
                if self.parser.getSetting('optimise_shorthands') >= 1:
                    cssdata = self.__merge_4value_shorthands(cssdata)

                if self.parser.getSetting('optimise_shorthands') >= 2:
                    cssdata = self.__merge_bg(cssdata)

                for item, value in cssdata.iteritems():
                    value = self.__compress_numbers(item, value)
                    value = self.__compress_important(value)

                    if item in data.color_values and self.parser.getSetting('compress_colors'):
                        old = value[:]
                        value = self.__compress_color(value)
                        if old != value:
                            self.parser.log('In "' + selector + '" Optimised ' + item + ': Changed ' + old + ' to ' + value, 'Information')

                    if item == 'font-weight' and self.parser.getSetting('compress_font-weight'):
                        if value  == 'bold':
                            value = '700'
                            self.parser.log('In "' + selector + '" Optimised font-weight: Changed "bold" to "700"', 'Information')

                        elif value == 'normal':
                            value = '400'
                            self.parser.log('In "' + selector + '" Optimised font-weight: Changed "normal" to "400"', 'Information')

                    self._optimized_css[media][selector][item] = value


        return self._optimized_css


#PRIVATE METHODS
    def __merge_bg(self, cssdata):
        """
            Merges all background properties
            @cssdata (dict) is a dictionary of the selector properties
        """
        #Max number of background images. CSS3 not yet fully implemented
        img = 1
        clr = 1
        bg_img_list = []
        if cssdata.has_key('background-image'):
            img = len(cssdata['background-image'].split(','))
            bg_img_list = self.parser.gvw_important(cssdata['background-image']).split(',')

        elif cssdata.has_key('background-color'):
            clr = len(cssdata['background-color'].split(','))


        number_of_values = max(img, clr, 1)

        new_bg_value = ''
        important = ''

        for i in xrange(number_of_values):
            for bg_property, default_value in data.background_prop_default.iteritems():
                #Skip if property does not exist
                if not cssdata.has_key(bg_property):
                    continue

                cur_value = cssdata[bg_property]

                #Skip some properties if there is no background image
                if (len(bg_img_list) > i and bg_img_list[i] == 'none') and bg_property in frozenset(['background-size', 'background-position', 'background-attachment', 'background-repeat']):
                    continue

                #Remove !important
                if self.parser.is_important(cur_value):
                    important = ' !important'
                    cur_value = self.parser.gvw_important(cur_value)

                #Do not add default values
                if cur_value == default_value:
                    continue

                temp = cur_value.split(',')

                if len(temp) > i:
                    if bg_property == 'background-size':
                        new_bg_value += '(' + temp[i] + ') '

                    else:
                        new_bg_value += temp[i] + ' '

            new_bg_value = new_bg_value.strip()
            if i != (number_of_values-1):
                new_bg_value += ','

        #Delete all background-properties
        for bg_property, default_value in data.background_prop_default.iteritems():
            try:
                del cssdata[bg_property]
            except:
                pass

        #Add new background property
        if new_bg_value != '':
            cssdata['background'] = new_bg_value + important

        return cssdata

    def __merge_4value_shorthands(self, cssdata):
        """
            Merges Shorthand properties again, the opposite of dissolve_4value_shorthands()
            @cssdata (dict) is a dictionary of the selector properties
        """
        for key, value in data.shorthands.iteritems():
            important = ''
            if value != 0 and cssdata.has_key(value[0]) and cssdata.has_key(value[1]) and cssdata.has_key(value[2]) and cssdata.has_key(value[3]):
                cssdata[key] = ''

                for i in xrange(4):
                    val = cssdata[value[i]]
                    if self.parser.is_important(val):
                        important = '!important'
                        cssdata[key] += self.parser.gvw_important(val) + ' '

                    else:
                        cssdata[key] += val + ' '

                    del cssdata[value[i]]
            if cssdata.has_key(key):
                cssdata[key] = self.__shorthand(cssdata[key] + important.strip())

        return cssdata


    def __merge_selectors(self):
        """
            Merges selectors with same properties. Example: a{color:red} b{color:red} . a,b{color:red}
            Very basic and has at least one bug. Hopefully there is a replacement soon.
            @selector_one (string) is the current selector
            @value_one (dict) is a dictionary of the selector properties
            Note: Currently is the elements of a selector are identical, but in a different order, they are not merged
        """

        ##OPTIMIZE##
        ##FIX##

        raw_css = self._optimized_css.copy()
        delete = []
        add = SortedDict()
        for media, css in raw_css.iteritems():
            for selector_one, value_one in css.iteritems():
                newsel = selector_one

                for selector_two, value_two in css.iteritems():
                    if selector_one == selector_two:
                        #We need to skip self
                        continue

                    if value_one == value_two:
                        #Ok, we need to merge these two selectors
                        newsel += ', ' + selector_two
                        delete.append((media, selector_two))


        if not add.has_key(media):
            add[media] = SortedDict()

        add[media][newsel] = value_one
        delete.append((media, selector_one))

        for item in delete:
            try:
                del self._optimized_css[item[0]][item[1]]
            except:
                #Must have already been deleted
                continue

        for media, css in add.iteritems():
            self._optimized_css[media].update(css)



    def __shorthand(self, value):
        """
            Compresses shorthand values. Example: margin:1px 1px 1px 1px . margin:1px
            @value (string)
        """

        ##FIX##

        important = '';
        if self.parser.is_important(value):
            value_list = self.parser.gvw_important(value)
            important = '!important'
        else:
            value_list = value

        ret = value
        value_list = value_list.split(' ')

        if len(value_list) == 4:
            if value_list[0] == value_list[1] and value_list[0] == value_list[2] and value_list[0] == value_list[3]:
                ret = value_list[0] + important

            elif value_list[1] == value_list[3] and value_list[0] == value_list[2]:
                ret = value_list[0] + ' ' + value_list[1] + important

            elif value_list[1] == value_list[3]:
                ret = value_list[0] + ' ' + value_list[1] + ' ' + value_list[2] + important

        elif len(value_list) == 3:
            if value_list[0] == value_list[1] and value_list[0] == value_list[2]:
                ret = value_list[0] + important

            elif value_list[0] == value_list[2]:
                return value_list[0] + ' ' + value_list[1] + important

        elif len(value_list) == 2:
            if value_list[0] == value_list[1]:
                ret = value_list[0] + important

        if ret != value:
            self.parser.log('Optimised shorthand notation: Changed "' + value + '" to "' + ret + '"', 'Information')

        return ret

    def __compress_important(self, value):
        """
            Removes unnecessary whitespace in ! important
            @value (string)
        """
        if self.parser.is_important(value):
            value = self.parser.gvw_important(value) + '!important'

        return value

    def __compress_numbers(self, prop, value):
        """
            Compresses numbers (ie. 1.0 becomes 1 or 1.100 becomes 1.1 )
            @value (string) is the posible number to be compressed
        """

        ##FIX##

        value = value.split('/')

        for l in xrange(len(value)):
            #continue if no numeric value
            if not (len(value[l]) > 0 and (value[l][0].isdigit() or value[l][0] in ('+', '-') )):
                continue

            #Fix bad colors
            if prop in data.color_values:
                value[l] = '#' + value[l]

            is_floatable = False
            try:
                float(value[l])
                is_floatable = True
            except:
                pass

            if is_floatable and float(value[l]) == 0:
                value[l] = '0'

            elif value[l][0] != '#':
                unit_found = False
                for unit in data.units:
                    pos = value[l].lower().find(unit)
                    if pos != -1 and prop not in data.shorthands:
                        value[l] = self.__remove_leading_zeros(float(value[l][:pos])) + unit
                        unit_found = True
                        break;

                if not unit_found and prop in data.unit_values and prop not in data.shorthands:
                    value[l] = self.__remove_leading_zeros(float(value[l])) + 'px'

                elif not unit_found and prop not in data.shorthands:
                    value[l] = self.__remove_leading_zeros(float(value[l]))


        if len(value) > 1:
            return '/'.join(value)

        return value[0]

    def __remove_leading_zeros(self, float_val):
        """
            Removes the leading zeros from a float value
            @float_val (float)
            @returns (string)
        """
        #Remove leading zero
        if abs(float_val) < 1:
            if float_val < 0:
                float_val = '-' . str(float_val)[2:]
            else:
                float_val = str(float_val)[1:]

        return str(float_val)

    def __compress_color(self, color):
        """
            Color compression function. Converts all rgb() values to #-values and uses the short-form if possible. Also replaces 4 color names by #-values.
            @color (string) the {posible} color to change
        """

        #rgb(0,0,0) . #000000 (or #000 in this case later)
        if color[:4].lower() == 'rgb(':
            color_tmp = color[4:(len(color)-5)]
            color_tmp = color_tmp.split(',')

            for c in color_tmp:
                c = c.strip()
                if c[:-1] == '%':
                    c = round((255*color_tmp[i])/100)

                if color_tmp[i] > 255:
                    color_tmp[i] = 255

            color = '#'

            for i in xrange(3):
                if color_tmp[i] < 16:
                    color += '0' + str(hex(color_tmp[i])).replace('0x', '')
                else:
                    color += str(hex(color_tmp[i])).replace('0x', '')

        #Fix bad color names
        if data.replace_colors.has_key(color.lower()):
            color = data.replace_colors[color.lower()]

        #aabbcc . #abc
        if len(color) == 7:
            color_temp = color.lower()
            if color_temp[0] == '#' and color_temp[1] == color_temp[2] and color_temp[3] == color_temp[4] and color_temp[5] == color_temp[6]:
                color = '#' + color[1] + color[3] + color[5]

        if data.optimize_colors.has_key(color.lower()):
            color = data.optimize_colors[color.lower()]

        return color