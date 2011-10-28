from django.http import Http404


def get_argument_or_404(request, param, method='REQUEST'):
    try:
        return getattr(request, method)[param]
    except KeyError:
        raise Http404