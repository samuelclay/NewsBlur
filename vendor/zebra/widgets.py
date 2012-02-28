from django.forms.widgets import Select, TextInput
from django.utils.safestring import mark_safe


class NoNameWidget(object):

    def _update_to_noname_class_name(self, name, kwargs_dict):
        if "attrs" in kwargs_dict:
            if "class" in kwargs_dict["attrs"]:
                kwargs_dict["attrs"]["class"] += " %s" % (name.replace("_", "-"), )
            else:
                kwargs_dict["attrs"].update({'class': name.replace("_", "-")})
        else:
            kwargs_dict["attrs"] = {'class': name.replace("_", "-")}

        return kwargs_dict

    def _strip_name_attr(self, widget_string, name):
        return widget_string.replace("name=\"%s\"" % (name,), "")

    class Media:
        css = {
            'all': ('zebra/card-form.css',)
        }
        js = ('zebra/card-form.js', 'https://js.stripe.com/v1/')



class NoNameTextInput(TextInput, NoNameWidget):

    def render(self, name, *args, **kwargs):
        kwargs = self._update_to_noname_class_name(name, kwargs)
        return mark_safe(self._strip_name_attr(super(NoNameTextInput, self).render(name, *args, **kwargs), name))


class NoNameSelect(Select, NoNameWidget):

    def render(self, name, *args, **kwargs):
        kwargs = self._update_to_noname_class_name(name, kwargs)
        return mark_safe(self._strip_name_attr(super(NoNameSelect, self).render(name, *args, **kwargs), name))
