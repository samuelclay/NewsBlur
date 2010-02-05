import memcache
import re
import sys
from settings import CACHE_BACKEND
#gfranxman

verbose = False

if not CACHE_BACKEND.startswith( 'memcached://' ):
    print "you are not configured to use memcched as your django cache backend"
else:
    m = re.search( r'//(.+:\d+)', CACHE_BACKEND )
    cache_host =  m.group(1)

    h = memcache._Host( cache_host )
    h.connect()
    h.send_cmd( 'stats' )

    stats = {}

    pat = re.compile( r'STAT (\w+) (\w+)' )

    l = '' ;
    while l.find( 'END' ) < 0 :
        l = h.readline()
        if verbose:
            print l
        m = pat.match( l )
        if m :
            stats[ m.group(1) ] =  m.group(2)


    h.close_socket()

    if verbose:
        print stats

    items = int( stats[ 'curr_items' ] )
    bytes = int( stats[ 'bytes' ] )
    limit_maxbytes = int( stats[ 'limit_maxbytes' ] ) or bytes
    current_conns = int( stats[ 'curr_connections' ] )

    print "MemCache status for %s" % ( CACHE_BACKEND )
    print "%d items using %d of %d" % ( items, bytes, limit_maxbytes )
    print "%5.2f%% full" % ( 100.0 * bytes / limit_maxbytes )
    print "%d connections being handled" % ( current_conns )
    print