import json
from pprint import pprint

from django.conf import settings
from django.http import Http404, HttpResponse

from apps.newsletters.models import EmailNewsletter
from apps.rss_feeds.models import Feed, MStory
from utils import log as logging


def fix_newsletter_encoding(params):
    """
    Fix encoding issues in newsletter email params.

    Sometimes email content is sent as UTF-8 but gets misinterpreted as Windows-1252,
    causing characters like smart quotes and dashes to be corrupted. This function
    detects and fixes those cases.

    Args:
        params: Dictionary containing email fields (subject, body-html, body-plain, etc.)

    Returns:
        Fixed params dictionary
    """
    # Common patterns that indicate UTF-8 was decoded as Windows-1252:
    # â€™ = ' (right single quotation mark, U+2019)
    # â€" = – (en dash, U+2013)
    # â€" = — (em dash, U+2014)
    # â€œ = " (left double quotation mark, U+201C)
    # â€ = " (right double quotation mark, U+201D)
    utf8_as_win1252_patterns = ["â€™", 'â€"', 'â€"', "â€œ", "â€", "â€˜", "â€¦"]

    def needs_fixing(text):
        if not text or not isinstance(text, str):
            return False
        return any(pattern in text for pattern in utf8_as_win1252_patterns)

    def fix_string(s):
        if not s or not isinstance(s, str):
            return s
        if not needs_fixing(s):
            return s
        try:
            # Re-encode as Windows-1252 to get the original bytes, then decode as UTF-8
            return s.encode("windows-1252", errors="ignore").decode("utf-8", errors="replace")
        except (UnicodeDecodeError, UnicodeEncodeError):
            return s

    # Fix all text fields in params
    fields_to_fix = ["subject", "body-html", "body-plain", "body-enriched", "stripped-html", "from"]
    fixed = False
    for field in fields_to_fix:
        if field in params and needs_fixing(params[field]):
            params[field] = fix_string(params[field])
            fixed = True

    if fixed:
        logging.debug(" ---> Fixed encoding in newsletter params")

    return params


def _normalize_improvmx_to_mailgun(improvmx_data):
    """
    Convert ImprovMX JSON format to Mailgun-compatible params.
    apps/newsletters/views.py:11
    """
    params = {}

    # Extract recipient from envelope (the actual NewsBlur newsletter address)
    envelope = improvmx_data.get("envelope", {})
    headers = improvmx_data.get("headers", {})

    # Debug logging to see what we're getting
    # logging.debug(" ---> ImprovMX envelope: %s" % json.dumps(envelope))
    logging.debug(" ---> ImprovMX Delivered-To header: %s" % headers.get("Delivered-To"))
    logging.debug(" ---> ImprovMX X-Forwarded-To header: %s" % headers.get("X-Forwarded-To"))

    if envelope.get("recipient"):
        params["recipient"] = envelope["recipient"]
    elif headers.get("Delivered-To"):
        delivered_to = headers["Delivered-To"]
        params["recipient"] = delivered_to.get("email") if isinstance(delivered_to, dict) else delivered_to

    # Debug: Check what recipient we extracted
    extracted_recipient = params.get("recipient", "")
    logging.debug(" ---> ImprovMX extracted recipient: %s" % extracted_recipient)

    # Check multiple places for samuel
    is_samuel = False
    if "samuel" in str(extracted_recipient).lower():
        is_samuel = True
    elif "samuel" in str(envelope).lower():
        is_samuel = True
    elif "samuel" in str(headers.get("X-Forwarded-To", "")).lower():
        is_samuel = True
    elif "samuel" in str(headers.get("X-Forwarded-For", "")).lower():
        is_samuel = True

    if is_samuel:
        logging.debug(" ---> Email newsletter raw ImprovMX data for samuel: %s" % json.dumps(improvmx_data))

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
            # ImprovMX sends: from (dict), envelope, headers, subject, html/text
            if "from" in body_data and isinstance(body_data.get("from"), dict) and "envelope" in body_data:
                params = _normalize_improvmx_to_mailgun(body_data)
                provider = "improvmx"
                logging.debug(" ---> Email newsletter from ImprovMX (normalized)")
            else:
                logging.debug(" ***> Email newsletter unknown format. Body: %s" % request.body)
                raise Http404
        except (json.JSONDecodeError, ValueError) as e:
            logging.debug(" ***> Email newsletter blank/invalid body: %s, error: %s" % (request.body, e))
            raise Http404
    else:
        # Convert QueryDict to regular dict for mutability
        params = dict(params)

    response = HttpResponse("OK")

    if settings.DEBUG or "samuel" in params.get("To", "") or "samuel" in params.get("recipient", ""):
        logging.debug(" ---> Email newsletter (%s): %s" % (provider, params))

    # Final validation
    if not params or not len(params.keys()):
        logging.debug(" ***> Email newsletter blank params after processing")
        raise Http404

    # Fix encoding issues before processing
    params = fix_newsletter_encoding(params)

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
    return HttpResponse(story["story_content"], content_type="text/html")
