#!/usr/bin/env python

import sys

import tlnb

if __name__ == "__main__":
    role = "task"
    if len(sys.argv) > 1:
        role = sys.argv[1]
    tlnb.main(roles=[role])
