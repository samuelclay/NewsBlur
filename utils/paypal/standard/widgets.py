#!/usr/bin/env python
# -*- coding: utf-8 -*-
from django import forms
from django.forms.util import flatatt
from django.utils.safestring import mark_safe
from django.utils.encoding import force_unicode


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
            final_attrs['value'] = force_unicode(value)
        return mark_safe(u'<input%s />' % flatatt(final_attrs))