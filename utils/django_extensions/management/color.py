"""
Sets up the terminal color scheme.
"""

from django.core.management import color
from django.utils import termcolors

def color_style():
    style = color.color_style()
    style.URL = termcolors.make_style(fg='green', opts=('bold',))
    style.MODULE = termcolors.make_style(fg='yellow')
    style.MODULE_NAME = termcolors.make_style(opts=('bold',))
    return style
