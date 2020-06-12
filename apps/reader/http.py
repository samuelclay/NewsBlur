from django.shortcuts import render

def respond(request, template_name, context_dict, **kwargs):
    """
    Use this function rather than render_to_response directly. The idea is to ensure
    that we're always using RequestContext. It's too easy to forget.
    """
    return render(request, template_name, context_dict, **kwargs)