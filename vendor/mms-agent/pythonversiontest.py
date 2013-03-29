import sys
major_version=sys.version_info[0]
if major_version == 2:
    sys.exit(0)
else:
    sys.exit(-1)
