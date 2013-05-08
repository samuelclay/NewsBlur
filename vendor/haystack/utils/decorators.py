# Backport of Django 1.2's ``django.utils.decorators``.
try:
    from functools import wraps, update_wrapper, WRAPPER_ASSIGNMENTS
except ImportError:
    from django.utils.functional import wraps, update_wrapper, WRAPPER_ASSIGNMENTS  # Python 2.4 fallback.


def method_decorator(decorator):
    """
    Converts a function decorator into a method decorator
    """
    def _dec(func):
        def _wrapper(self, *args, **kwargs):
            def bound_func(*args2, **kwargs2):
                return func(self, *args2, **kwargs2)
            # bound_func has the signature that 'decorator' expects i.e.  no
            # 'self' argument, but it is a closure over self so it can call
            # 'func' correctly.
            return decorator(bound_func)(*args, **kwargs)
        return wraps(func)(_wrapper)
    update_wrapper(_dec, decorator)
    # Change the name to aid debugging.
    _dec.__name__ = 'method_decorator(%s)' % decorator.__name__
    return _dec