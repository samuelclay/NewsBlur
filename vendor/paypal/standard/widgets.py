#!/usr/bin/env python
# -*- coding: utf-8 -*-
from django import forms
try:
    from django.forms.utils import flatatt # Django 1.7 and later
except ImportError:
    from django.forms.util import flatatt # earlier

from django.utils.safestring import mark_safe
from django.utils.encoding import force_text


class ValueHiddenInput(forms.HiddenInput):
    """
    Widget that renders only if it has a value.
    Used to remove unused fields from PayPal buttons.
    """

    def render(self, name, value, attrs=None):
        if value is None:
            return u''
        else:
            return super(ValueHiddenInput, self).render(name, value, attrs)


class ReservedValueHiddenInput(ValueHiddenInput):
    """
    Overrides the default name attribute of the form.
    Used for the PayPal `return` field.
    """

    def render(self, name, value, attrs=None):
        if value is None:
            value = ''
        final_attrs = self.build_attrs(attrs, type=self.input_type)
        if value != '':
            final_attrs['value'] = force_text(value)
        return mark_safe(u'<input%s />' % flatatt(final_attrs))
