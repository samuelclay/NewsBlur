#!/usr/bin/env python

import tlnb
import sys

if __name__ == "__main__":
    role = "work"
    if len(sys.argv) > 1:
        role = sys.argv[1]
    tlnb.main(roles=[role])
    