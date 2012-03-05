from django import forms
from django.core.exceptions import NON_FIELD_ERRORS
from django.utils.dates import MONTHS

from zebra.conf import options
from zebra.widgets import NoNameSelect, NoNameTextInput


class MonospaceForm(forms.Form):
    def addError(self, message):
        self._errors[NON_FIELD_ERRORS] = self.error_class([message])


class CardForm(MonospaceForm):
    last_4_digits = forms.CharField(required=True, min_length=4, max_length=4,
        widget=forms.HiddenInput())
    stripe_token = forms.CharField(required=True, widget=forms.HiddenInput())


class StripePaymentForm(CardForm):
    def __init__(self, *args, **kwargs):
        super(StripePaymentForm, self).__init__(*args, **kwargs)
        self.fields['card_cvv'].label = "Card CVC"
        self.fields['card_cvv'].help_text = "Card Verification Code; see rear of card."
        months = [ (m[0], u'%02d - %s' % (m[0], unicode(m[1])))
                    for m in sorted(MONTHS.iteritems()) ]
        self.fields['card_expiry_month'].choices = months

    card_number = forms.CharField(required=False, max_length=20,
        widget=NoNameTextInput())
    card_cvv = forms.CharField(required=False, max_length=4,
        widget=NoNameTextInput())
    card_expiry_month = forms.ChoiceField(required=False, widget=NoNameSelect(),
        choices=MONTHS.iteritems())
    card_expiry_year = forms.ChoiceField(required=False, widget=NoNameSelect(),
        choices=options.ZEBRA_CARD_YEARS_CHOICES)
