#!/usr/bin/env python
import os
import sys

if __name__ == "__main__":
    # Auto-detect test environment and use test_settings
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", "newsblur_web.test_settings")
    else:
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", "newsblur_web.settings")

    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)
