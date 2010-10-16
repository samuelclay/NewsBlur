#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Adapted from:
    - http://www.djangosnippets.org/snippets/764/
    - http://www.satchmoproject.com/trac/browser/satchmo/trunk/satchmo/apps/satchmo_utils/views.py
    - http://tinyurl.com/shoppify-credit-cards
"""
import re


# Well known card regular expressions.
CARDS = {
    'Visa': re.compile(r"^4\d{12}(\d{3})?$"),
    'Mastercard': re.compile(r"(5[1-5]\d{4}|677189)\d{10}$"),
    'Dinersclub': re.compile(r"^3(0[0-5]|[68]\d)\d{11}"),
    'Amex': re.compile("^3[47]\d{13}$"),
    'Discover': re.compile("^(6011|65\d{2})\d{12}$"),
}

# Well known test numbers
TEST_NUMBERS = [
    "378282246310005", "371449635398431", "378734493671000", "30569309025904",
    "38520000023237", "6011111111111117", "6011000990139424", "555555555554444",
    "5105105105105100", "4111111111111111", "4012888888881881", "4222222222222"
]

def verify_credit_card(number):
    """Returns the card type for given card number or None if invalid."""
    return CreditCard(number).verify()

class CreditCard(object):
    def __init__(self, number):
        self.number = number
	
    def is_number(self):
        """True if there is at least one digit in number."""
        self.number = re.sub(r'[^\d]', '', self.number)
        return self.number.isdigit()

    def is_mod10(self):
        """Returns True if number is valid according to mod10."""
        double = 0
        total = 0
        for i in range(len(self.number) - 1, -1, -1):
            for c in str((double + 1) * int(self.number[i])):
                total = total + int(c)
            double = (double + 1) % 2
        return (total % 10) == 0

    def is_test(self):
        """Returns True if number is a test card number."""
        return self.number in TEST_NUMBERS

    def get_type(self):
        """Return the type if it matches one of the cards."""
        for card, pattern in CARDS.iteritems():
            if pattern.match(self.number):
                return card
        return None

    def verify(self):
        """Returns the card type if valid else None."""
        if self.is_number() and not self.is_test() and self.is_mod10():
            return self.get_type()
        return None