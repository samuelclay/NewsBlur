"""Entry point for `python -m newsblur_mcp`.

Imports from the canonical module to avoid the double-import problem
that occurs when `python -m` loads the module as __main__ while tool
sub-modules import from newsblur_mcp.server.
"""

from newsblur_mcp.server import main

main()
