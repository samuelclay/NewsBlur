import sys
try:
    import pymongo
    sys.exit(0)
except Exception as exc:
    sys.exit(-1)

