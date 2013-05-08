from django.contrib.admin.options import ModelAdmin
from django.contrib.admin.views.main import ChangeList, SEARCH_VAR
from django.core.exceptions import PermissionDenied
from django.core.paginator import Paginator, InvalidPage
from django.shortcuts import render_to_response
from django import template
from django.utils.encoding import force_unicode
from django.utils.translation import ungettext
from haystack import connections
from haystack.query import SearchQuerySet
try:
    from django.contrib.admin.options import csrf_protect_m
except ImportError:
    from haystack.utils.decorators import method_decorator

    # Do nothing on Django 1.1 and below.
    def csrf_protect(view):
        def wraps(request, *args, **kwargs):
            return view(request, *args, **kwargs)
        return wraps

    csrf_protect_m = method_decorator(csrf_protect)

def list_max_show_all(changelist):
    """
    Returns the maximum amount of results a changelist can have for the
    "Show all" link to be displayed in a manner compatible with both Django
    1.4 and 1.3. See Django ticket #15997 for details.
    """
    try:
        # This import is available in Django 1.3 and below
        from django.contrib.admin.views.main import MAX_SHOW_ALL_ALLOWED
        return MAX_SHOW_ALL_ALLOWED
    except ImportError:
        return changelist.list_max_show_all


class SearchChangeList(ChangeList):
    def get_results(self, request):
        if not SEARCH_VAR in request.GET:
            return super(SearchChangeList, self).get_results(request)

        # Note that pagination is 0-based, not 1-based.
        sqs = SearchQuerySet().models(self.model).auto_query(request.GET[SEARCH_VAR]).load_all()

        paginator = Paginator(sqs, self.list_per_page)
        # Get the number of objects, with admin filters applied.
        result_count = paginator.count
        full_result_count = SearchQuerySet().models(self.model).all().count()

        can_show_all = result_count <= list_max_show_all(self)
        multi_page = result_count > self.list_per_page

        # Get the list of objects to display on this page.
        try:
            result_list = paginator.page(self.page_num+1).object_list
            # Grab just the Django models, since that's what everything else is
            # expecting.
            result_list = [result.object for result in result_list]
        except InvalidPage:
            result_list = ()

        self.result_count = result_count
        self.full_result_count = full_result_count
        self.result_list = result_list
        self.can_show_all = can_show_all
        self.multi_page = multi_page
        self.paginator = paginator


class SearchModelAdmin(ModelAdmin):
    @csrf_protect_m
    def changelist_view(self, request, extra_context=None):
        if not self.has_change_permission(request, None):
            raise PermissionDenied

        if not SEARCH_VAR in request.GET:
            # Do the usual song and dance.
            return super(SearchModelAdmin, self).changelist_view(request, extra_context)

        # Do a search of just this model and populate a Changelist with the
        # returned bits.
        if not self.model in connections['default'].get_unified_index().get_indexed_models():
            # Oops. That model isn't being indexed. Return the usual
            # behavior instead.
            return super(SearchModelAdmin, self).changelist_view(request, extra_context)

        # So. Much. Boilerplate.
        # Why copy-paste a few lines when you can copy-paste TONS of lines?
        list_display = list(self.list_display)

        kwargs = {
            'request': request,
            'model': self.model,
            'list_display': list_display,
            'list_display_links': self.list_display_links,
            'list_filter': self.list_filter,
            'date_hierarchy': self.date_hierarchy,
            'search_fields': self.search_fields,
            'list_select_related': self.list_select_related,
            'list_per_page': self.list_per_page,
            'list_editable': self.list_editable,
            'model_admin': self
        }

        # Django 1.4 compatibility.
        if hasattr(self, 'list_max_show_all'):
            kwargs['list_max_show_all'] = self.list_max_show_all

        changelist = SearchChangeList(**kwargs)
        formset = changelist.formset = None
        media = self.media

        # Build the action form and populate it with available actions.
        # Check actions to see if any are available on this changelist
        actions = self.get_actions(request)
        if actions:
            action_form = self.action_form(auto_id=None)
            action_form.fields['action'].choices = self.get_action_choices(request)
        else:
            action_form = None

        selection_note = ungettext('0 of %(count)d selected',
            'of %(count)d selected', len(changelist.result_list))
        selection_note_all = ungettext('%(total_count)s selected',
            'All %(total_count)s selected', changelist.result_count)

        context = {
            'module_name': force_unicode(self.model._meta.verbose_name_plural),
            'selection_note': selection_note % {'count': len(changelist.result_list)},
            'selection_note_all': selection_note_all % {'total_count': changelist.result_count},
            'title': changelist.title,
            'is_popup': changelist.is_popup,
            'cl': changelist,
            'media': media,
            'has_add_permission': self.has_add_permission(request),
            # More Django 1.4 compatibility
            'root_path': getattr(self.admin_site, 'root_path', None),
            'app_label': self.model._meta.app_label,
            'action_form': action_form,
            'actions_on_top': self.actions_on_top,
            'actions_on_bottom': self.actions_on_bottom,
            'actions_selection_counter': getattr(self, 'actions_selection_counter', 0),
        }
        context.update(extra_context or {})
        context_instance = template.RequestContext(request, current_app=self.admin_site.name)
        return render_to_response(self.change_list_template or [
            'admin/%s/%s/change_list.html' % (self.model._meta.app_label, self.model._meta.object_name.lower()),
            'admin/%s/change_list.html' % self.model._meta.app_label,
            'admin/change_list.html'
        ], context, context_instance=context_instance)

