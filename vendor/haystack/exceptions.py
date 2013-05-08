class HaystackError(Exception):
    """A generic exception for all others to extend."""
    pass

class SearchBackendError(HaystackError):
    """Raised when a backend can not be found."""
    pass

class SearchFieldError(HaystackError):
    """Raised when a field encounters an error."""
    pass

class MissingDependency(HaystackError):
    """Raised when a library a backend depends on can not be found."""
    pass

class NotHandled(HaystackError):
    """Raised when a model is not handled by the router setup."""
    pass

class MoreLikeThisError(HaystackError):
    """Raised when a model instance has not been provided for More Like This."""
    pass

class FacetingError(HaystackError):
    """Raised when incorrect arguments have been provided for faceting."""
    pass

class SpatialError(HaystackError):
    """Raised when incorrect arguments have been provided for spatial."""
    pass
