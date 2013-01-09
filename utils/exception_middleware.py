import traceback
import sys
import inspect
from pprint import pprint

class ConsoleExceptionMiddleware:
    def process_exception(self, request, exception):
        exc_info = sys.exc_info()
        print "######################## Exception #############################"
        print '\n'.join(traceback.format_exception(*(exc_info or sys.exc_info())))
        print "----------------------------------------------------------------"
        pprint(inspect.trace()[-1][0].f_locals)
        print "################################################################"
        
        #pprint(request)
        #print "################################################################"
