from logging import *

SUPPRESS_OUTPUT_ATTR = 'djangologging.suppress_output'

def getLevelNames():
    """
    Retrieves a list of the the defined levels. A list of tuples is returned,
    where the first element is the level number and the second is the level
    name. The list is sorted from lowest level to highest.
    """
    from logging import _acquireLock, _levelNames, _releaseLock

    names = {}
    _acquireLock()
    try:
        for key in _levelNames:
            try:
                if key == int(key):
                    names[key] = _levelNames[key]
            except ValueError:
                pass
        items = names.items()
        items.sort()
        return items
    finally:
        _releaseLock()