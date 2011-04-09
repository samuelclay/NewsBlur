# Add auto-completion and a stored history file of commands to your Python
# interactive interpreter. Requires Python 2.0+, readline. Autocomplete is
# bound to the Esc key by default (you can change it - see readline docs).
#
# Store the file in ~/.pystartup, and set an environment variable to point
# to it, e.g. "export PYTHONSTARTUP=/max/home/itamar/.pystartup" in bash.
#
# Note that PYTHONSTARTUP does *not* expand "~", so you have to put in the
# full path to your home directory.

import atexit
import os
import readline
import rlcompleter

historyPath = os.path.expanduser("~/.pyhistory")
historyTmp = os.path.expanduser("~/.pyhisttmp.py")

endMarkerStr= "# # # histDUMP # # #"

saveMacro= "import readline; readline.write_history_file('"+historyTmp+"'); \
    print '####>>>>>>>>>>'; print ''.join(filter(lambda lineP: \
    not lineP.strip().endswith('"+endMarkerStr+"'),  \
    open('"+historyTmp+"').readlines())[:])+'####<<<<<<<<<<'"+endMarkerStr

readline.parse_and_bind('tab: complete')
readline.parse_and_bind('\C-w: "'+saveMacro+'"')

def save_history(historyPath=historyPath, endMarkerStr=endMarkerStr):
    import readline
    readline.write_history_file(historyPath)
    # Now filter out those line containing the saveMacro
    lines= filter(lambda lineP, endMarkerStr=endMarkerStr:
                      not lineP.strip().endswith(endMarkerStr), open(historyPath).readlines())
    open(historyPath, 'w+').write(''.join(lines))

if os.path.exists(historyPath):
    readline.read_history_file(historyPath)

atexit.register(save_history)

del os, atexit, readline, rlcompleter, save_history, historyPath
del historyTmp, endMarkerStr, saveMacro