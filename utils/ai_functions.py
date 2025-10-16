import logging
import re
from html import unescape

import openai
import tiktoken
from django.conf import settings


def setup_openai_model(openai_model):
    openai.api_key = settings.OPENAI_API_KEY
    try:
        encoding = tiktoken.encoding_for_model(openai_model)
    except KeyError:
        logging.debug(f"Could not find encoding for model {openai_model}, using cl100k_base")
        encoding = tiktoken.get_encoding("cl100k_base")

    return encoding
