#!/usr/bin/env python

import tlnb
import sys

if __name__ == "__main__":
    role = "task"
    command = None
    if len(sys.argv) > 1:
        role = sys.argv[1]
    if len(sys.argv) > 2:
        command = sys.argv[2]
    tlnb.main(roles=[role], command=command)
    