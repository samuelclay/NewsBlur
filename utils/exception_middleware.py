"""Django middleware that prints full exception tracebacks to the console.

Useful during development to see detailed exception information directly
in the terminal without relying on Django's HTML error pages.
"""

import inspect
import sys
import traceback
from pprint import pprint


class ConsoleExceptionMiddleware:
    def process_exception(self, request, exception):
        exc_info = sys.exc_info()
        print("######################## Exception #############################")
        print(("\n".join(traceback.format_exception(*(exc_info or sys.exc_info())))))
        print("----------------------------------------------------------------")
        # pprint(inspect.trace()[-1][0].f_locals)
        print("################################################################")

        # pprint(request)
        # print "################################################################"

    def __init__(self, get_response=None):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        return response
