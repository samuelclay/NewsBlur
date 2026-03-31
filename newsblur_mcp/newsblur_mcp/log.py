"""Structured logging with ANSI colors matching NewsBlur's web request logs.

Produces output identical to utils/log.py from the main Django app:
  ---> [   MCP] [0.1234s] [username^] newsblur_list_feeds

Color codes use the same ~XX notation as the Django logger.
"""

import logging
import re

logger = logging.getLogger("newsblur.mcp")

COLOR_ESC = "\033["


class AnsiCodes:
    def __init__(self, codes):
        for name in dir(codes):
            if not name.startswith("_"):
                value = getattr(codes, name)
                setattr(self, name, COLOR_ESC + str(value) + "m")


class AnsiFore:
    BLACK = 30
    RED = 31
    GREEN = 32
    YELLOW = 33
    BLUE = 34
    MAGENTA = 35
    CYAN = 36
    WHITE = 37
    RESET = 39


class AnsiBack:
    BLACK = 40
    RED = 41
    GREEN = 42
    YELLOW = 43
    BLUE = 44
    MAGENTA = 45
    CYAN = 46
    WHITE = 47
    RESET = 49


class AnsiStyle:
    BRIGHT = 1
    DIM = 2
    UNDERLINE = 4
    BLINK = 5
    NORMAL = 22
    RESET_ALL = 0


Fore = AnsiCodes(AnsiFore)
Back = AnsiCodes(AnsiBack)
Style = AnsiCodes(AnsiStyle)

COLORS = {
    "~SB": Style.BRIGHT,
    "~SD": Style.DIM,
    "~SN": Style.NORMAL,
    "~SK": Style.BLINK,
    "~SU": Style.UNDERLINE,
    "~ST": Style.RESET_ALL,
    "~FK": Fore.BLACK,
    "~FR": Fore.RED,
    "~FG": Fore.GREEN,
    "~FY": Fore.YELLOW,
    "~FB": Fore.BLUE,
    "~FM": Fore.MAGENTA,
    "~FC": Fore.CYAN,
    "~FW": Fore.WHITE,
    "~FT": Fore.RESET,
    "~BK": Back.BLACK,
    "~BR": Back.RED,
    "~BG": Back.GREEN,
    "~BY": Back.YELLOW,
    "~BB": Back.BLUE,
    "~BM": Back.MAGENTA,
    "~BC": Back.CYAN,
    "~BW": Back.WHITE,
    "~BT": Back.RESET,
}

# Same bracket/arrow colorization rules as the Django logger
PARAMS = {
    r"\-\-\->": "~FB~SB--->~FW",
    r"\*\*\*>": "~FB~SB~BB--->~BT~FW",
    r"\[": "~SB~FB[~SN~FM",
    r"AnonymousUser": "~FBAnonymousUser",
    r"\*\]": r"~SN~FR*~FB~SB]",
    r"\^\]": r"~SN~FR^~FB~SB]",
    r"\]": "~FB~SB]~FW~SN",
}


def colorize(msg: str) -> str:
    for pattern, replacement in PARAMS.items():
        msg = re.sub(pattern, replacement, msg)
    msg = msg + "~ST~FW~BT"
    for code, ansi in COLORS.items():
        msg = msg.replace(code, ansi)
    return msg


def info(msg: str):
    logger.info(colorize(msg))


def log_request(username: str, premium: str, seconds: float, tool_name: str):
    """Log an MCP tool invocation in the same format as Django request logs.

    Format: ---> [   MCP] [0.1234s] [username*] tool_name
    """
    color = "~FB"
    if seconds >= 5:
        color = "~FR"
    elif seconds > 1:
        color = "~FY"
    time_elapsed = "[%s%.4ss~SB] " % (color, seconds)

    if username:
        info(
            " ---> [~FB~SN%-6s~SB] %s[%s%s] ~FC%s"
            % ("MCP", time_elapsed, username, premium, tool_name)
        )
    else:
        info(
            " ---> [~FB~SN%-6s~SB] %s[anonymous] ~FC%s"
            % ("MCP", time_elapsed, tool_name)
        )
