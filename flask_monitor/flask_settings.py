"""
Shim module that exposes settings from newsblur.local_settings when available.
This replaces the previous symlink so linting does not fail when the target file
is missing (e.g. in development environments without secrets).
"""

try:
    from newsblur.local_settings import *  # noqa: F401,F403
except ImportError:
    # Allow linting and development environments to proceed without the private
    # settings file.
    pass
