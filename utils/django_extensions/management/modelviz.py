#!/usr/bin/env python
"""Django model to DOT (Graphviz) converter
by Antonio Cavedoni <antonio@cavedoni.org>

Make sure your DJANGO_SETTINGS_MODULE is set to your project or
place this script in the same directory of the project and call
the script like this:

$ python modelviz.py [-h] [-a] [-d] [-g] [-i <model_names>] <app_label> ... <app_label> > <filename>.dot
$ dot <filename>.dot -Tpng -o <filename>.png

options:
    -h, --help
    show this help message and exit.

    -a, --all_applications
    show models from all applications.

    -d, --disable_fields
    don't show the class member fields.

    -g, --group_models
    draw an enclosing box around models from the same app.

    -i, --include_models=User,Person,Car
    only include selected models in graph.
"""
__version__ = "0.9"
__svnid__ = "$Id$"
__license__ = "Python"
__author__ = "Antonio Cavedoni <http://cavedoni.com/>"
__contributors__ = [
   "Stefano J. Attardi <http://attardi.org/>",
   "limodou <http://www.donews.net/limodou/>",
   "Carlo C8E Miron",
   "Andre Campos <cahenan@gmail.com>",
   "Justin Findlay <jfindlay@gmail.com>",
   "Alexander Houben <alexander@houben.ch>",
   "Bas van Oostveen <v.oostveen@gmail.com>",
]

import getopt, sys

from django.core.management import setup_environ

try:
    import settings
except ImportError:
    pass
else:
    setup_environ(settings)

from django.utils.safestring import mark_safe
from django.template import Template, Context
from django.db import models
from django.db.models import get_models
from django.db.models.fields.related import \
    ForeignKey, OneToOneField, ManyToManyField

try:
    from django.db.models.fields.generic import GenericRelation
except ImportError:
    from django.contrib.contenttypes.generic import GenericRelation

head_template = """
digraph name {
  fontname = "Helvetica"
  fontsize = 8

  node [
    fontname = "Helvetica"
    fontsize = 8
    shape = "plaintext"
  ]
  edge [
    fontname = "Helvetica"
    fontsize = 8
  ]

"""

body_template = """
{% if use_subgraph %}
subgraph {{ cluster_app_name }} {
  label=<
        <TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">
        <TR><TD COLSPAN="2" CELLPADDING="4" ALIGN="CENTER"
        ><FONT FACE="Helvetica Bold" COLOR="Black" POINT-SIZE="12"
        >{{ app_name }}</FONT></TD></TR>
        </TABLE>
        >
  color=olivedrab4
  style="rounded"
{% endif %}

  {% for model in models %}
    {{ model.app_name }}_{{ model.name }} [label=<
    <TABLE BGCOLOR="palegoldenrod" BORDER="0" CELLBORDER="0" CELLSPACING="0">
     <TR><TD COLSPAN="2" CELLPADDING="4" ALIGN="CENTER" BGCOLOR="olivedrab4"
     ><FONT FACE="Helvetica Bold" COLOR="white"
     >{{ model.name }}{% if model.abstracts %}<BR/>&lt;<FONT FACE="Helvetica Italic">{{ model.abstracts|join:"," }}</FONT>&gt;{% endif %}</FONT></TD></TR>

    {% if not disable_fields %}
        {% for field in model.fields %}
        <TR><TD ALIGN="LEFT" BORDER="0"
        ><FONT {% if field.blank %}COLOR="#7B7B7B" {% endif %}FACE="Helvetica {% if field.abstract %}Italic{% else %}Bold{% endif %}">{{ field.name }}</FONT
        ></TD>
        <TD ALIGN="LEFT"
        ><FONT {% if field.blank %}COLOR="#7B7B7B" {% endif %}FACE="Helvetica {% if field.abstract %}Italic{% else %}Bold{% endif %}">{{ field.type }}</FONT
        ></TD></TR>
        {% endfor %}
    {% endif %}
    </TABLE>
    >]
  {% endfor %}

{% if use_subgraph %}
}
{% endif %}
"""

rel_template = """
  {% for model in models %}
    {% for relation in model.relations %}
    {% if relation.needs_node %}
    {{ relation.target_app }}_{{ relation.target }} [label=<
        <TABLE BGCOLOR="palegoldenrod" BORDER="0" CELLBORDER="0" CELLSPACING="0">
        <TR><TD COLSPAN="2" CELLPADDING="4" ALIGN="CENTER" BGCOLOR="olivedrab4"
        ><FONT FACE="Helvetica Bold" COLOR="white"
        >{{ relation.target }}</FONT></TD></TR>
        </TABLE>
        >]
    {% endif %}
    {{ model.app_name }}_{{ model.name }} -> {{ relation.target_app }}_{{ relation.target }}
    [label="{{ relation.name }}"] {{ relation.arrows }};
    {% endfor %}
  {% endfor %}
"""

tail_template = """
}
"""

def generate_dot(app_labels, **kwargs):
    disable_fields = kwargs.get('disable_fields', False)
    include_models = kwargs.get('include_models', [])
    all_applications = kwargs.get('all_applications', False)
    use_subgraph = kwargs.get('group_models', False)

    dot = head_template

    apps = []
    if all_applications:
        apps = models.get_apps()

    for app_label in app_labels:
        app = models.get_app(app_label)
        if not app in apps:
            apps.append(app)

    graphs = []
    for app in apps:
        graph = Context({
            'name': '"%s"' % app.__name__,
            'app_name': "%s" % '.'.join(app.__name__.split('.')[:-1]),
            'cluster_app_name': "cluster_%s" % app.__name__.replace(".", "_"),
            'disable_fields': disable_fields,
            'use_subgraph': use_subgraph,
            'models': []
        })

        for appmodel in get_models(app):
            abstracts = [e.__name__ for e in appmodel.__bases__ if hasattr(e, '_meta') and e._meta.abstract]
            abstract_fields = []
            for e in appmodel.__bases__:
                if hasattr(e, '_meta') and e._meta.abstract:
                    abstract_fields.extend(e._meta.fields)
            model = {
                'app_name': app.__name__.replace(".", "_"),
                'name': appmodel.__name__,
                'abstracts': abstracts,
                'fields': [],
                'relations': []
            }

            # consider given model name ?
            def consider(model_name):
                return not include_models or model_name in include_models

            if not consider(appmodel._meta.object_name):
                continue

            # model attributes
            def add_attributes(field):
                model['fields'].append({
                    'name': field.name,
                    'type': type(field).__name__,
                    'blank': field.blank,
                    'abstract': field in abstract_fields,
                })

            for field in appmodel._meta.fields:
                add_attributes(field)

            if appmodel._meta.many_to_many:
                for field in appmodel._meta.many_to_many:
                    add_attributes(field)

            # relations
            def add_relation(field, extras=""):
                _rel = {
                    'target_app': field.rel.to.__module__.replace('.','_'),
                    'target': field.rel.to.__name__,
                    'type': type(field).__name__,
                    'name': field.name,
                    'arrows': extras,
                    'needs_node': True
                }
                if _rel not in model['relations'] and consider(_rel['target']):
                    model['relations'].append(_rel)

            for field in appmodel._meta.fields:
                if isinstance(field, ForeignKey):
                    add_relation(field)
                elif isinstance(field, OneToOneField):
                    add_relation(field, '[arrowhead=none arrowtail=none]')

            if appmodel._meta.many_to_many:
                for field in appmodel._meta.many_to_many:
                    if isinstance(field, ManyToManyField) and getattr(field, 'creates_table', False):
                        add_relation(field, '[arrowhead=normal arrowtail=normal]')
                    elif isinstance(field, GenericRelation):
                        add_relation(field, mark_safe('[style="dotted"] [arrowhead=normal arrowtail=normal]'))
            graph['models'].append(model)
        graphs.append(graph)

    nodes = []
    for graph in graphs:
        nodes.extend([e['name'] for e in graph['models']])

    for graph in graphs:
        # don't draw duplication nodes because of relations
        for model in graph['models']:
            for relation in model['relations']:
                if relation['target'] in nodes:
                    relation['needs_node'] = False
        # render templates
        t = Template(body_template)
        dot += '\n' + t.render(graph)

    for graph in graphs:
        t = Template(rel_template)
        dot += '\n' + t.render(graph)

    dot += '\n' + tail_template
    return dot

def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hadgi:",
                    ["help", "all_applications", "disable_fields", "group_models", "include_models="])
    except getopt.GetoptError, error:
        print __doc__
        sys.exit(error)
    
    kwargs = {}
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print __doc__
            sys.exit()
        if opt in ("-a", "--all_applications"):
            kwargs['all_applications'] = True
        if opt in ("-d", "--disable_fields"):
            kwargs['disable_fields'] = True
        if opt in ("-g", "--group_models"):
            kwargs['group_models'] = True
        if opt in ("-i", "--include_models"):
            kwargs['include_models'] = arg.split(',')

    if not args and not kwargs.get('all_applications', False):
        print __doc__
        sys.exit()

    print generate_dot(args, **kwargs)

if __name__ == "__main__":
    main()
