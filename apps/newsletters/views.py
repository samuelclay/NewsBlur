import json
from pprint import pprint

from django.conf import settings
from django.http import Http404, HttpResponse

from apps.newsletters.models import EmailNewsletter
from apps.rss_feeds.models import Feed, MStory
from utils import log as logging


def _normalize_improvmx_to_mailgun(improvmx_data):
    """
    Convert ImprovMX JSON format to Mailgun-compatible params.
    apps/newsletters/views.py:11
    """
    params = {}

    # Extract recipient from 'to' array
    if improvmx_data.get("to") and len(improvmx_data["to"]) > 0:
        params["recipient"] = improvmx_data["to"][0].get("email", "")

    # Convert 'from' object to "Name <email>" format
    from_data = improvmx_data.get("from", {})
    from_name = from_data.get("name", "")
    from_email = from_data.get("email", "")
    if from_name:
        params["from"] = f"{from_name} <{from_email}>"
    else:
        params["from"] = from_email

    # Map other fields
    params["subject"] = improvmx_data.get("subject", "")
    params["body-html"] = improvmx_data.get("html", "")
    params["body-plain"] = improvmx_data.get("text", "")
    params["timestamp"] = str(improvmx_data.get("timestamp", ""))

    # Use message-id as signature (unique identifier)
    params["signature"] = improvmx_data.get("message-id", "")

    return params


def newsletter_receive(request):
    """
    This function is called by email providers' (Mailgun, ImprovMX) receive email webhook.
    This is a private API used for the newsletter app.
    apps/newsletters/views.py:47
    """
    params = request.POST
    provider = "mailgun"

    # If POST is empty, try parsing JSON body (ImprovMX)
    if not params or not len(params.keys()):
        try:
            body_data = json.loads(request.body)
            # Check if it looks like ImprovMX format
            if "to" in body_data and "from" in body_data and isinstance(body_data.get("to"), list):
                params = _normalize_improvmx_to_mailgun(body_data)
                provider = "improvmx"
                logging.debug(" ---> Email newsletter from ImprovMX (normalized)")
            else:
                logging.debug(" ***> Email newsletter unknown format. Body: %s" % request.body)
                raise Http404
        except (json.JSONDecodeError, ValueError) as e:
            logging.debug(" ***> Email newsletter blank/invalid body: %s, error: %s" % (request.body, e))
            raise Http404

    response = HttpResponse("OK")

    if settings.DEBUG or "samuel" in params.get("To", ""):
        logging.debug(" ---> Email newsletter (%s): %s" % (provider, params))

    # Final validation
    if not params or not len(params.keys()):
        logging.debug(" ***> Email newsletter blank params after processing")
        raise Http404

    email_newsletter = EmailNewsletter()
    story = email_newsletter.receive_newsletter(params)

    if not story:
        raise Http404

    return response


def newsletter_story(request, story_hash):
    try:
        story = MStory.objects.get(story_hash=story_hash)
    except MStory.DoesNotExist:
        raise Http404

    story = Feed.format_story(story)
    return HttpResponse(story["story_content"])
