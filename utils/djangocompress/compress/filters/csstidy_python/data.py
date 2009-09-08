# Various CSS Data for CSSTidy
#
# This file is part of CSSTidy.
#
# CSSTidy is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# CSSTidy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CSSTidy; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# @license http://opensource.org/licenses/gpl-license.php GNU Public License
# @package csstidy
# @author Florian Schmitz (floele at gmail dot com) 2005

AT_START    = 1
AT_END      = 2
SEL_START   = 3
SEL_END     = 4
PROPERTY    = 5
VALUE       = 6
COMMENT     = 7
DEFAULT_AT  = 41

# All whitespace allowed in CSS
#
# @global array whitespace
# @version 1.0
whitespace = frozenset([' ',"\n","\t","\r","\x0B"])

# All CSS tokens used by csstidy
#
# @global string tokens
# @version 1.0
tokens = '/@}{;:=\'"(,\\!$%&)#+.<>?[]^`|~'

# All CSS units (CSS 3 units included)
#
# @see compress_numbers()
# @global array units
# @version 1.0
units = frozenset(['in','cm','mm','pt','pc','px','rem','em','%','ex','gd','vw','vh','vm','deg','grad','rad','ms','s','khz','hz'])

# Available at-rules
#
# @global array at_rules
# @version 1.0
at_rules = {'page':'is', 'font-face':'is', 'charset':'iv', 'import':'iv', 'namespace':'iv', 'media':'at'}

# Properties that need a value with unit
#
# @todo CSS3 properties
# @see compress_numbers()
# @global array unit_values
# @version 1.2
unit_values = frozenset(['background', 'background-position', 'border', 'border-top', 'border-right', 'border-bottom',
                                    'border-left', 'border-width', 'border-top-width', 'border-right-width', 'border-left-width',
                                    'border-bottom-width', 'bottom', 'border-spacing', 'font-size','height', 'left', 'margin', 'margin-top',
                                    'margin-right', 'margin-bottom', 'margin-left', 'max-height', 'max-width', 'min-height', 'min-width',
                                    'outline-width', 'padding', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left','position',
                                    'right', 'top', 'text-indent', 'letter-spacing', 'word-spacing', 'width'
                                    ])


# Properties that allow <color> as value
#
# @todo CSS3 properties
# @see compress_numbers()
# @global array color_values
# @version 1.0
color_values = frozenset(['background-color', 'border-color', 'border-top-color', 'border-right-color',
                                        'border-bottom-color', 'border-left-color', 'color', 'outline-color'])


# Default values for the background properties
#
# @todo Possibly property names will change during CSS3 development
# @global array background_prop_default
# @see dissolve_short_bg()
# @see merge_bg()
# @version 1.0
background_prop_default = {}
background_prop_default['background-image'] = 'none'
background_prop_default['background-size'] = 'auto'
background_prop_default['background-repeat'] = 'repeat'
background_prop_default['background-position'] = '0 0'
background_prop_default['background-attachment'] = 'scroll'
background_prop_default['background-clip'] = 'border'
background_prop_default['background-origin'] = 'padding'
background_prop_default['background-color'] = 'transparent'

# A list of non-W3C color names which get replaced by their hex-codes
#
# @global array replace_colors
# @see cut_color()
# @version 1.0
replace_colors = {}
replace_colors['aliceblue'] = '#F0F8FF'
replace_colors['antiquewhite'] = '#FAEBD7'
replace_colors['aquamarine'] = '#7FFFD4'
replace_colors['azure'] = '#F0FFFF'
replace_colors['beige'] = '#F5F5DC'
replace_colors['bisque'] = '#FFE4C4'
replace_colors['blanchedalmond'] = '#FFEBCD'
replace_colors['blueviolet'] = '#8A2BE2'
replace_colors['brown'] = '#A52A2A'
replace_colors['burlywood'] = '#DEB887'
replace_colors['cadetblue'] = '#5F9EA0'
replace_colors['chartreuse'] = '#7FFF00'
replace_colors['chocolate'] = '#D2691E'
replace_colors['coral'] = '#FF7F50'
replace_colors['cornflowerblue'] = '#6495ED'
replace_colors['cornsilk'] = '#FFF8DC'
replace_colors['crimson'] = '#DC143C'
replace_colors['cyan'] = '#00FFFF'
replace_colors['darkblue'] = '#00008B'
replace_colors['darkcyan'] = '#008B8B'
replace_colors['darkgoldenrod'] = '#B8860B'
replace_colors['darkgray'] = '#A9A9A9'
replace_colors['darkgreen'] = '#006400'
replace_colors['darkkhaki'] = '#BDB76B'
replace_colors['darkmagenta'] = '#8B008B'
replace_colors['darkolivegreen'] = '#556B2F'
replace_colors['darkorange'] = '#FF8C00'
replace_colors['darkorchid'] = '#9932CC'
replace_colors['darkred'] = '#8B0000'
replace_colors['darksalmon'] = '#E9967A'
replace_colors['darkseagreen'] = '#8FBC8F'
replace_colors['darkslateblue'] = '#483D8B'
replace_colors['darkslategray'] = '#2F4F4F'
replace_colors['darkturquoise'] = '#00CED1'
replace_colors['darkviolet'] = '#9400D3'
replace_colors['deeppink'] = '#FF1493'
replace_colors['deepskyblue'] = '#00BFFF'
replace_colors['dimgray'] = '#696969'
replace_colors['dodgerblue'] = '#1E90FF'
replace_colors['feldspar'] = '#D19275'
replace_colors['firebrick'] = '#B22222'
replace_colors['floralwhite'] = '#FFFAF0'
replace_colors['forestgreen'] = '#228B22'
replace_colors['gainsboro'] = '#DCDCDC'
replace_colors['ghostwhite'] = '#F8F8FF'
replace_colors['gold'] = '#FFD700'
replace_colors['goldenrod'] = '#DAA520'
replace_colors['greenyellow'] = '#ADFF2F'
replace_colors['honeydew'] = '#F0FFF0'
replace_colors['hotpink'] = '#FF69B4'
replace_colors['indianred'] = '#CD5C5C'
replace_colors['indigo'] = '#4B0082'
replace_colors['ivory'] = '#FFFFF0'
replace_colors['khaki'] = '#F0E68C'
replace_colors['lavender'] = '#E6E6FA'
replace_colors['lavenderblush'] = '#FFF0F5'
replace_colors['lawngreen'] = '#7CFC00'
replace_colors['lemonchiffon'] = '#FFFACD'
replace_colors['lightblue'] = '#ADD8E6'
replace_colors['lightcoral'] = '#F08080'
replace_colors['lightcyan'] = '#E0FFFF'
replace_colors['lightgoldenrodyellow'] = '#FAFAD2'
replace_colors['lightgrey'] = '#D3D3D3'
replace_colors['lightgreen'] = '#90EE90'
replace_colors['lightpink'] = '#FFB6C1'
replace_colors['lightsalmon'] = '#FFA07A'
replace_colors['lightseagreen'] = '#20B2AA'
replace_colors['lightskyblue'] = '#87CEFA'
replace_colors['lightslateblue'] = '#8470FF'
replace_colors['lightslategray'] = '#778899'
replace_colors['lightsteelblue'] = '#B0C4DE'
replace_colors['lightyellow'] = '#FFFFE0'
replace_colors['limegreen'] = '#32CD32'
replace_colors['linen'] = '#FAF0E6'
replace_colors['magenta'] = '#FF00FF'
replace_colors['mediumaquamarine'] = '#66CDAA'
replace_colors['mediumblue'] = '#0000CD'
replace_colors['mediumorchid'] = '#BA55D3'
replace_colors['mediumpurple'] = '#9370D8'
replace_colors['mediumseagreen'] = '#3CB371'
replace_colors['mediumslateblue'] = '#7B68EE'
replace_colors['mediumspringgreen'] = '#00FA9A'
replace_colors['mediumturquoise'] = '#48D1CC'
replace_colors['mediumvioletred'] = '#C71585'
replace_colors['midnightblue'] = '#191970'
replace_colors['mintcream'] = '#F5FFFA'
replace_colors['mistyrose'] = '#FFE4E1'
replace_colors['moccasin'] = '#FFE4B5'
replace_colors['navajowhite'] = '#FFDEAD'
replace_colors['oldlace'] = '#FDF5E6'
replace_colors['olivedrab'] = '#6B8E23'
replace_colors['orangered'] = '#FF4500'
replace_colors['orchid'] = '#DA70D6'
replace_colors['palegoldenrod'] = '#EEE8AA'
replace_colors['palegreen'] = '#98FB98'
replace_colors['paleturquoise'] = '#AFEEEE'
replace_colors['palevioletred'] = '#D87093'
replace_colors['papayawhip'] = '#FFEFD5'
replace_colors['peachpuff'] = '#FFDAB9'
replace_colors['peru'] = '#CD853F'
replace_colors['pink'] = '#FFC0CB'
replace_colors['plum'] = '#DDA0DD'
replace_colors['powderblue'] = '#B0E0E6'
replace_colors['rosybrown'] = '#BC8F8F'
replace_colors['royalblue'] = '#4169E1'
replace_colors['saddlebrown'] = '#8B4513'
replace_colors['salmon'] = '#FA8072'
replace_colors['sandybrown'] = '#F4A460'
replace_colors['seagreen'] = '#2E8B57'
replace_colors['seashell'] = '#FFF5EE'
replace_colors['sienna'] = '#A0522D'
replace_colors['skyblue'] = '#87CEEB'
replace_colors['slateblue'] = '#6A5ACD'
replace_colors['slategray'] = '#708090'
replace_colors['snow'] = '#FFFAFA'
replace_colors['springgreen'] = '#00FF7F'
replace_colors['steelblue'] = '#4682B4'
replace_colors['tan'] = '#D2B48C'
replace_colors['thistle'] = '#D8BFD8'
replace_colors['tomato'] = '#FF6347'
replace_colors['turquoise'] = '#40E0D0'
replace_colors['violet'] = '#EE82EE'
replace_colors['violetred'] = '#D02090'
replace_colors['wheat'] = '#F5DEB3'
replace_colors['whitesmoke'] = '#F5F5F5'
replace_colors['yellowgreen'] = '#9ACD32'

#A list of optimized colors
optimize_colors = {}
optimize_colors['black'] = '#000'
optimize_colors['fuchsia'] = '#F0F'
optimize_colors['white'] = '#FFF'
optimize_colors['yellow'] = '#FF0'
optimize_colors['cyan'] = '#0FF'
optimize_colors['magenta'] = '#F0F'
optimize_colors['lightslategray'] = '#789'

optimize_colors['#800000'] = 'maroon'
optimize_colors['#FFA500'] = 'orange'
optimize_colors['#808000'] = 'olive'
optimize_colors['#800080'] = 'purple'
optimize_colors['#008000'] = 'green'
optimize_colors['#000080'] = 'navy'
optimize_colors['#008080'] = 'teal'
optimize_colors['#C0C0C0'] = 'silver'
optimize_colors['#808080'] = 'gray'
optimize_colors['#4B0082'] = 'indigo'
optimize_colors['#FFD700'] = 'gold'
optimize_colors['#A52A2A'] = 'brown'
optimize_colors['#00FFFF'] = 'cyan'
optimize_colors['#EE82EE'] = 'violet'
optimize_colors['#DA70D6'] = 'orchid'
optimize_colors['#FFE4C4'] = 'bisque'
optimize_colors['#F0E68C'] = 'khaki'
optimize_colors['#F5DEB3'] = 'wheat'
optimize_colors['#FF7F50'] = 'coral'
optimize_colors['#F5F5DC'] = 'beige'
optimize_colors['#F0FFFF'] = 'azure'
optimize_colors['#A0522D'] = 'sienna'
optimize_colors['#CD853F'] = 'peru'
optimize_colors['#FFFFF0'] = 'ivory'
optimize_colors['#DDA0DD'] = 'plum'
optimize_colors['#D2B48C'] = 'tan'
optimize_colors['#FFC0CB'] = 'pink'
optimize_colors['#FFFAFA'] = 'snow'
optimize_colors['#FA8072'] = 'salmon'
optimize_colors['#FF6347'] = 'tomato'
optimize_colors['#FAF0E6'] = 'linen'
optimize_colors['#F00'] = 'red'


# A list of all shorthand properties that are devided into four properties and/or have four subvalues
#
# @global array shorthands
# @todo Are there new ones in CSS3?
# @see dissolve_4value_shorthands()
# @see merge_4value_shorthands()
# @version 1.0
shorthands = {}
shorthands['border-color'] = ['border-top-color','border-right-color','border-bottom-color','border-left-color']
shorthands['border-style'] = ['border-top-style','border-right-style','border-bottom-style','border-left-style']
shorthands['border-width'] = ['border-top-width','border-right-width','border-bottom-width','border-left-width']
shorthands['margin'] = ['margin-top','margin-right','margin-bottom','margin-left']
shorthands['padding'] = ['padding-top','padding-right','padding-bottom','padding-left']
shorthands['-moz-border-radius'] = 0

# All CSS Properties. Needed for csstidy::property_is_next()
#
# @global array all_properties
# @todo Add CSS3 properties
# @version 1.0
# @see csstidy::property_is_next()
all_properties = {}
all_properties['background'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['background-color'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['background-image'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['background-repeat'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['background-attachment'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['background-position'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-top'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-right'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-bottom'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-left'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-color'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-top-color'] = 'CSS2.0,CSS2.1'
all_properties['border-bottom-color'] = 'CSS2.0,CSS2.1'
all_properties['border-left-color'] = 'CSS2.0,CSS2.1'
all_properties['border-right-color'] = 'CSS2.0,CSS2.1'
all_properties['border-style'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-top-style'] = 'CSS2.0,CSS2.1'
all_properties['border-right-style'] = 'CSS2.0,CSS2.1'
all_properties['border-left-style'] = 'CSS2.0,CSS2.1'
all_properties['border-bottom-style'] = 'CSS2.0,CSS2.1'
all_properties['border-width'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-top-width'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-right-width'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-left-width'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-bottom-width'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['border-collapse'] = 'CSS2.0,CSS2.1'
all_properties['border-spacing'] = 'CSS2.0,CSS2.1'
all_properties['bottom'] = 'CSS2.0,CSS2.1'
all_properties['caption-side'] = 'CSS2.0,CSS2.1'
all_properties['content'] = 'CSS2.0,CSS2.1'
all_properties['clear'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['clip'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['color'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['counter-reset'] = 'CSS2.0,CSS2.1'
all_properties['counter-increment'] = 'CSS2.0,CSS2.1'
all_properties['cursor'] = 'CSS2.0,CSS2.1'
all_properties['empty-cells'] = 'CSS2.0,CSS2.1'
all_properties['display'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['direction'] = 'CSS2.0,CSS2.1'
all_properties['float'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['font'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['font-family'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['font-style'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['font-variant'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['font-weight'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['font-stretch'] = 'CSS2.0'
all_properties['font-size-adjust'] = 'CSS2.0'
all_properties['font-size'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['height'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['left'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['line-height'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['list-style'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['list-style-type'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['list-style-image'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['list-style-position'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['margin'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['margin-top'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['margin-right'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['margin-bottom'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['margin-left'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['marks'] = 'CSS1.0,CSS2.0'
all_properties['marker-offset'] = 'CSS2.0'
all_properties['max-height'] = 'CSS2.0,CSS2.1'
all_properties['max-width'] = 'CSS2.0,CSS2.1'
all_properties['min-height'] = 'CSS2.0,CSS2.1'
all_properties['min-width'] = 'CSS2.0,CSS2.1'
all_properties['overflow'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['orphans'] = 'CSS2.0,CSS2.1'
all_properties['outline'] = 'CSS2.0,CSS2.1'
all_properties['outline-width'] = 'CSS2.0,CSS2.1'
all_properties['outline-style'] = 'CSS2.0,CSS2.1'
all_properties['outline-color'] = 'CSS2.0,CSS2.1'
all_properties['padding'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['padding-top'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['padding-right'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['padding-bottom'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['padding-left'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['page-break-before'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['page-break-after'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['page-break-inside'] = 'CSS2.0,CSS2.1'
all_properties['page'] = 'CSS2.0'
all_properties['position'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['quotes'] = 'CSS2.0,CSS2.1'
all_properties['right'] = 'CSS2.0,CSS2.1'
all_properties['size'] = 'CSS1.0,CSS2.0'
all_properties['speak-header'] = 'CSS2.0,CSS2.1'
all_properties['table-layout'] = 'CSS2.0,CSS2.1'
all_properties['top'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['text-indent'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['text-align'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['text-decoration'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['text-shadow'] = 'CSS2.0'
all_properties['letter-spacing'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['word-spacing'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['text-transform'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['white-space'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['unicode-bidi'] = 'CSS2.0,CSS2.1'
all_properties['vertical-align'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['visibility'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['width'] = 'CSS1.0,CSS2.0,CSS2.1'
all_properties['widows'] = 'CSS2.0,CSS2.1'
all_properties['z-index'] = 'CSS1.0,CSS2.0,CSS2.1'

# Speech #
all_properties['volume'] = 'CSS2.0,CSS2.1'
all_properties['speak'] = 'CSS2.0,CSS2.1'
all_properties['pause'] = 'CSS2.0,CSS2.1'
all_properties['pause-before'] = 'CSS2.0,CSS2.1'
all_properties['pause-after'] = 'CSS2.0,CSS2.1'
all_properties['cue'] = 'CSS2.0,CSS2.1'
all_properties['cue-before'] = 'CSS2.0,CSS2.1'
all_properties['cue-after'] = 'CSS2.0,CSS2.1'
all_properties['play-during'] = 'CSS2.0,CSS2.1'
all_properties['azimuth'] = 'CSS2.0,CSS2.1'
all_properties['elevation'] = 'CSS2.0,CSS2.1'
all_properties['speech-rate'] = 'CSS2.0,CSS2.1'
all_properties['voice-family'] = 'CSS2.0,CSS2.1'
all_properties['pitch'] = 'CSS2.0,CSS2.1'
all_properties['pitch-range'] = 'CSS2.0,CSS2.1'
all_properties['stress'] = 'CSS2.0,CSS2.1'
all_properties['richness'] = 'CSS2.0,CSS2.1'
all_properties['speak-punctuation'] = 'CSS2.0,CSS2.1'
all_properties['speak-numeral'] = 'CSS2.0,CSS2.1'