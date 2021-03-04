#!/usr/bin/env python

import tlnb
import sys

if __name__ == "__main__":
    role = "task"
    if len(sys.argv) > 1:
        role = sys.argv[1]
    # tlnb.main(role=role, role2="ec2task")
    tlnb.main(role=role)
    