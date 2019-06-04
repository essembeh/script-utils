# termicolor - Ultra simple library to use terminal colors and styles
#
# License: Apache 2.0 (http://www.apache.org/licenses/LICENSE-2.0.txt)
#
# Usage:
# Colors and style are enabled only if stdout is a TTY and TERMICOLOR_DISABLE is not set in environment.
# Style and colors can be used in a *with* statement that will automatically reset the style after
# > with TermColor(Style.BOLD, Style.UNDERLINE, Style.HALF_BRIGHT, bg=Color.PURPLE, fg=Color.YELLOW):
# >     print("Hello style")
# Common methods allow printing single messages like the print function
# > print_red("Hello problem")
# > print_green("Hello solution")
# > print_style("Hello message", bg_color=Color.RED, fg_color=Color.WHITE, styles=[Style.UNDERLINE])
#
import os
import sys
from contextlib import ContextDecorator
from enum import Enum, IntEnum


class Style(Enum):
    '''
    Represent a terminal style.
    Note that _BG_COLOR and _FG_COLOR should not be used directly.
    '''
    BOLD = "bold"
    HALF_BRIGHT = "dim"
    UNDERLINE = "smul"
    NO_UNDERLINE = "rmul"
    REVERSE = "rev"
    STANDOUT = "smso"
    NO_STANDOUT = "rmso"
    RESET = "sgr0"
    _BG_COLOR = 'setab'
    _FG_COLOR = 'setaf'


class Color(Enum):
    '''
    Common terminal colors
    '''
    BLACK = 0
    RED = 1
    GREEN = 2
    YELLOW = 3
    BLUE = 4
    PURPLE = 5
    CYAN = 6
    WHITE = 7


class TermiColor():
    '''
    Used to set a custom style and reset it after a with statement.
    '''
    def __init__(self, *styles: Style, bg: Color = None, fg: Color = None):
        self.__bg = bg if isinstance(bg, Color) else None
        self.__fg = fg if isinstance(fg, Color) else None
        self.__styles = list(filter(lambda s: isinstance(s, Style), styles))
        self.__enabled = sys.stdout.isatty() and not os.getenv("TERMICOLOR_DISABLE")

    def __tput(self, style: Style, color: Color = None):
        if color:
            os.system("tput {style.value} {color.value}".format(style=style, color=color))
        else:
            os.system("tput {style.value}".format(style=style))

    def __enter__(self):
        if self.__enabled:
            sys.stdout.flush()
            self.__tput(Style.RESET)
            if self.__bg:
                self.__tput(Style._BG_COLOR, color=self.__bg)
            if self.__fg:
                self.__tput(Style._FG_COLOR, color=self.__fg)
            for s in self.__styles:
                self.__tput(s)

    def __exit__(self, *args):
        if self.__enabled:
            sys.stdout.flush()
            self.__tput(Style.RESET)


def print_style(*args, bg_color=None, fg_color=None, styles=None, **kwargs):
    '''
    print function replacement which can set colors and style.
    '''
    styleslist = []
    if isinstance(styles, list):
        styleslist += styles
    elif isinstance(styles, Style):
        styleslist.append(styles)
    with TermiColor(*styleslist, bg=bg_color, fg=fg_color):
        print(*args, **kwargs)


def print_red(*args, **kwargs):
    '''
    print function replacement which print the message in red
    '''
    print_style(*args, fg_color=Color.RED, **kwargs)


def print_green(*args, **kwargs):
    '''
    print function replacement which print the message in green
    '''
    print_style(*args, fg_color=Color.GREEN, **kwargs)


if __name__ == "__main__":
    '''
    Examples
    '''
    with TermiColor(Style.BOLD, Style.UNDERLINE, Style.HALF_BRIGHT, bg=Color.PURPLE, fg=Color.YELLOW):
        print("Hello style")
    print_red("Hello problem")
    print_green("Hello solution")
    print_style("Hello message", bg_color=Color.RED,fg_color=Color.WHITE, styles=[Style.UNDERLINE])
    print("Hello world")
