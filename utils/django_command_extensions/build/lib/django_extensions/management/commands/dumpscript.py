#!/usr/bin/env python
# -*- coding: UTF-8 -*-
"""
      Title: Dumpscript management command
    Project: Hardytools (queryset-refactor version)
     Author: Will Hardy (http://willhardy.com.au)
       Date: June 2008
      Usage: python manage.py dumpscript appname > scripts/scriptname.py
  $Revision: 217 $

Description: 
    Generates a Python script that will repopulate the database using objects.
    The advantage of this approach is that it is easy to understand, and more
    flexible than directly populating the database, or using XML.

    * It also allows for new defaults to take effect and only transfers what is
      needed.
    * If a new database schema has a NEW ATTRIBUTE, it is simply not
      populated (using a default value will make the transition smooth :)
    * If a new database schema REMOVES AN ATTRIBUTE, it is simply ignored
      and the data moves across safely (I'm assuming we don't want this
      attribute anymore.
    * Problems may only occur if there is a new model and is now a required
      ForeignKey for an existing model. But this is easy to fix by editing the
      populate script :)

Improvements:
    See TODOs and FIXMEs scattered throughout :-)

"""

import sys
from django.db import models
from django.core.exceptions import ObjectDoesNotExist
from django.core.management.base import BaseCommand
from django.utils.encoding import smart_unicode, force_unicode
from django.contrib.contenttypes.models import ContentType

class Command(BaseCommand):
    help = 'Dumps the data as a customised python script.'
    args = '[appname ...]'

    def handle(self, *app_labels, **options):

        # Get the models we want to export
        models = get_models(app_labels)

        # A dictionary is created to keep track of all the processed objects,
        # so that foreign key references can be made using python variable names.
        # This variable "context" will be passed around like the town bicycle.
        context = {}

        # Create a dumpscript object and let it format itself as a string
        print Script(models=models, context=context)


def get_models(app_labels):
    """ Gets a list of models for the given app labels, with some exceptions. 
        TODO: If a required model is referenced, it should also be included.
        Or at least discovered with a get_or_create() call.
    """

    from django.db.models import get_app, get_apps, get_model
    from django.db.models import get_models as get_all_models

    # These models are not to be output, e.g. because they can be generated automatically
    # TODO: This should be "appname.modelname" string
    from django.contrib.contenttypes.models import ContentType
    EXCLUDED_MODELS = (ContentType, )

    models = []

    # If no app labels are given, return all
    if not app_labels:
        for app in get_apps():
            models += [ m for m in get_all_models(app) if m not in EXCLUDED_MODELS ]

    # Get all relevant apps
    for app_label in app_labels:
        # If a specific model is mentioned, get only that model
        if "." in app_label:
            app_label, model_name = app_label.split(".", 1)
            models.append(get_model(app_label, model_name))
        # Get all models for a given app
        else:
            models += [ m for m in get_all_models(get_app(app_label)) if m not in EXCLUDED_MODELS ]

    return models



class Code(object):
    """ A snippet of python script. 
        This keeps track of import statements and can be output to a string.
        In the future, other features such as custom indentation might be included
        in this class.
    """

    def __init__(self):
        self.imports = {}
        self.indent = -1 

    def __str__(self):
        """ Returns a string representation of this script. 
        """
        if self.imports:
            sys.stderr.write(repr(self.import_lines))
            return flatten_blocks([""] + self.import_lines + [""] + self.lines, num_indents=self.indent)
        else:
            return flatten_blocks(self.lines, num_indents=self.indent)

    def get_import_lines(self):
        """ Takes the stored imports and converts them to lines
        """
        if self.imports:
            return [ "from %s import %s" % (value, key) for key, value in self.imports.items() ]
        else:
            return []
    import_lines = property(get_import_lines)


class ModelCode(Code):
    " Produces a python script that can recreate data for a given model class. "

    def __init__(self, model, context={}):
        self.model = model
        self.context = context
        self.instances = []
        self.indent = 0

    def get_imports(self):
        """ Returns a dictionary of import statements, with the variable being
            defined as the key. 
        """
        return { self.model.__name__: smart_unicode(self.model.__module__) }
    imports = property(get_imports)

    def get_lines(self):
        """ Returns a list of lists or strings, representing the code body. 
            Each list is a block, each string is a statement.
        """
        code = []

        for counter, item in enumerate(self.model.objects.all()):
            instance = InstanceCode(instance=item, id=counter+1, context=self.context)
            self.instances.append(instance)
            if instance.waiting_list:
                code += instance.lines
 
        # After each instance has been processed, try again.
        # This allows self referencing fields to work.
        for instance in self.instances:
            if instance.waiting_list:
                code += instance.lines

        return code

    lines = property(get_lines)


class InstanceCode(Code):
    " Produces a python script that can recreate data for a given model instance. "

    def __init__(self, instance, id, context={}):
        """ We need the instance in question and an id """

        self.instance = instance
        self.model = self.instance.__class__
        self.context = context
        self.variable_name = "%s_%s" % (self.instance._meta.db_table, id)
        self.skip_me = None
        self.instantiated = False

        self.indent  = 0 
        self.imports = {}

        self.waiting_list = list(self.model._meta.fields)

        self.many_to_many_waiting_list = {} 
        for field in self.model._meta.many_to_many:
            self.many_to_many_waiting_list[field] = list(getattr(self.instance, field.name).all())

    def get_lines(self, force=False):
        """ Returns a list of lists or strings, representing the code body. 
            Each list is a block, each string is a statement.
            
            force (True or False): if an attribute object cannot be included, 
            it is usually skipped to be processed later. With 'force' set, there
            will be no waiting: a get_or_create() call is written instead.
        """
        code_lines = []

        # Don't return anything if this is an instance that should be skipped
        if self.skip():
            return []

        # Initialise our new object
        # e.g. model_name_35 = Model()
        code_lines += self.instantiate()

        # Add each field
        # e.g. model_name_35.field_one = 1034.91
        #      model_name_35.field_two = "text"
        code_lines += self.get_waiting_list()

        if force:
            # TODO: Check that M2M are not affected
            code_lines += self.get_waiting_list(force=force)

        # Print the save command for our new object
        # e.g. model_name_35.save()
        if code_lines:
            code_lines.append("%s.save()\n" % (self.variable_name))

        code_lines += self.get_many_to_many_lines(force=force)

        return code_lines
    lines = property(get_lines)

    def skip(self):
        """ Determine whether or not this object should be skipped.
            If this model is a parent of a single subclassed instance, skip it.
            The subclassed instance will create this parent instance for us.

            TODO: Allow the user to force its creation?
        """

        if self.skip_me is not None:
            return self.skip_me

        try:
            # Django trunk since r7722 uses CollectedObjects instead of dict
            from django.db.models.query import CollectedObjects
            sub_objects = CollectedObjects()
        except ImportError:
            # previous versions don't have CollectedObjects
            sub_objects = {}
        self.instance._collect_sub_objects(sub_objects)
        if reduce(lambda x, y: x+y, [self.model in so._meta.parents for so in sub_objects.keys()]) == 1:
            pk_name = self.instance._meta.pk.name
            key = '%s_%s' % (self.model.__name__, getattr(self.instance, pk_name))
            self.context[key] = None
            self.skip_me = True
        else:
            self.skip_me = False

        return self.skip_me

    def instantiate(self):
        " Write lines for instantiation "
        # e.g. model_name_35 = Model()
        code_lines = []

        if not self.instantiated:
            code_lines.append("%s = %s()" % (self.variable_name, self.model.__name__))
            self.instantiated = True

            # Store our variable name for future foreign key references
            pk_name = self.instance._meta.pk.name
            key = '%s_%s' % (self.model.__name__, getattr(self.instance, pk_name))
            self.context[key] = self.variable_name

        return code_lines


    def get_waiting_list(self, force=False):
        " Add lines for any waiting fields that can be completed now. "

        code_lines = []

        # Process normal fields
        for field in list(self.waiting_list):
            try:
                # Find the value, add the line, remove from waiting list and move on
                value = get_attribute_value(self.instance, field, self.context, force=force)
                code_lines.append('%s.%s = %s' % (self.variable_name, field.name, value))
                self.waiting_list.remove(field)
            except SkipValue, e:
                # Remove from the waiting list and move on
                self.waiting_list.remove(field)
                continue
            except DoLater, e:
                # Move on, maybe next time
                continue


        return code_lines


    def get_many_to_many_lines(self, force=False):
        """ Generates lines that define many to many relations for this instance. """

        lines = []

        for field, rel_items in self.many_to_many_waiting_list.items():
            for rel_item in list(rel_items):
                try:
                    pk_name = rel_item._meta.pk.name
                    key = '%s_%s' % (rel_item.__class__.__name__, getattr(rel_item, pk_name))
                    value = "%s" % self.context[key]
                    lines.append('%s.%s.add(%s)' % (self.variable_name, field.name, value))
                    self.many_to_many_waiting_list[field].remove(rel_item)
                except KeyError:
                    if force:
                        value = "%s.objects.get(%s=%s)" % (rel_item._meta.object_name, pk_name, getattr(rel_item, pk_name))
                        lines.append('%s.%s.add(%s)' % (self.variable_name, field.name, value))
                        self.many_to_many_waiting_list[field].remove(rel_item)

        if lines:
            lines.append("")

        return lines


class Script(Code):
    " Produces a complete python script that can recreate data for the given apps. "

    def __init__(self, models, context={}):
        self.models = models
        self.context = context

        self.indent = -1 
        self.imports = {}

    def get_lines(self):
        """ Returns a list of lists or strings, representing the code body. 
            Each list is a block, each string is a statement.
        """
        code = [ self.FILE_HEADER.strip() ]

        # Queue and process the required models
        for model_class in queue_models(self.models, context=self.context):
            sys.stderr.write('Processing model: %s\n' % model_class.model.__name__)
            code.append(model_class.import_lines)
            code.append("")
            code.append(model_class.lines)

        # Process left over foreign keys from cyclic models
        for model in self.models:
            sys.stderr.write('Re-processing model: %s\n' % model.model.__name__)
            for instance in model.instances:
                if instance.waiting_list or instance.many_to_many_waiting_list:
                    code.append(instance.get_lines(force=True))

        return code

    lines = property(get_lines)

    # A user-friendly file header
    FILE_HEADER = """

#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This file has been automatically generated, changes may be lost if you
# go and generate it again. It was generated with the following command:
# %s

import datetime
from decimal import Decimal
from django.contrib.contenttypes.models import ContentType

def run():

""" % " ".join(sys.argv)



# HELPER FUNCTIONS
#-------------------------------------------------------------------------------

def flatten_blocks(lines, num_indents=-1):
    """ Takes a list (block) or string (statement) and flattens it into a string
        with indentation. 
    """

    # The standard indent is four spaces
    INDENTATION = " " * 4

    if not lines:
        return ""

    # If this is a string, add the indentation and finish here
    if isinstance(lines, basestring):
        return INDENTATION * num_indents + lines

    # If this is not a string, join the lines and recurse
    return "\n".join([ flatten_blocks(line, num_indents+1) for line in lines ])




def get_attribute_value(item, field, context, force=False):
    """ Gets a string version of the given attribute's value, like repr() might. """

    # Find the value of the field, catching any database issues
    try:
        value = getattr(item, field.name)
    except ObjectDoesNotExist:
        raise SkipValue('Could not find object for %s.%s, ignoring.\n' % (item.__class__.__name__, field.name))

    # AutoField: We don't include the auto fields, they'll be automatically recreated
    if isinstance(field, models.AutoField):
        raise SkipValue()

    # Some databases (eg MySQL) might store boolean values as 0/1, this needs to be cast as a bool
    elif isinstance(field, models.BooleanField) and value is not None:
        return repr(bool(value))

    # Post file-storage-refactor, repr() on File/ImageFields no longer returns the path
    elif isinstance(field, models.FileField):
        return repr(force_unicode(value))

    # ForeignKey fields, link directly using our stored python variable name
    elif isinstance(field, models.ForeignKey) and value is not None:

        # Special case for contenttype foreign keys: no need to output any
        # content types in this script, as they can be generated again 
        # automatically.
        # NB: Not sure if "is" will always work
        if field.rel.to is ContentType:
            return 'ContentType.objects.get(app_label="%s", model="%s")' % (value.app_label, value.model)

        # Generate an identifier (key) for this foreign object
        pk_name = value._meta.pk.name
        key = '%s_%s' % (value.__class__.__name__, getattr(value, pk_name))

        if key in context:
            variable_name = context[key]
            # If the context value is set to None, this should be skipped.
            # This identifies models that have been skipped (inheritance)
            if variable_name is None:
                raise SkipValue()
            # Return the variable name listed in the context 
            return "%s" % variable_name
        elif force:
            return "%s.objects.get(%s=%s)" % (value._meta.object_name, pk_name, getattr(value, pk_name))
        else:
            raise DoLater('(FK) %s.%s\n' % (item.__class__.__name__, field.name))


    # A normal field (e.g. a python built-in)
    else:
        return repr(value)

def queue_models(models, context):
    """ Works an an appropriate ordering for the models.
        This isn't essential, but makes the script look nicer because 
        more instances can be defined on their first try.
    """

    # Max number of cycles allowed before we call it an infinite loop.
    MAX_CYCLES = 5

    model_queue = []
    number_remaining_models = len(models)
    allowed_cycles = MAX_CYCLES

    while number_remaining_models > 0:
        previous_number_remaining_models = number_remaining_models

        model = models.pop(0)
        
        # If the model is ready to be processed, add it to the list
        if check_dependencies(model, model_queue):
            model_class = ModelCode(model=model, context=context)
            model_queue.append(model_class)

        # Otherwise put the model back at the end of the list
        else:
            models.append(model)

        # Check for infinite loops. 
        # This means there is a cyclic foreign key structure
        # That cannot be resolved by re-ordering
        number_remaining_models = len(models)
        if number_remaining_models == previous_number_remaining_models:
            allowed_cycles -= 1
            if allowed_cycles <= 0:
                # Add the remaining models, but do not remove them from the model list
                missing_models = [ ModelCode(model=m, context=context) for m in models ]
                model_queue += missing_models
                # Replace the models with the model class objects 
                # (sure, this is a little bit of hackery)
                models[:] = missing_models
                break
        else:
            allowed_cycles = MAX_CYCLES

    return model_queue


def check_dependencies(model, model_queue):
    " Check that all the depenedencies for this model are already in the queue. "

    # A list of allowed links: existing fields, itself and the special case ContentType
    allowed_links = [ m.model.__name__ for m in model_queue ] + [model.__name__, 'ContentType']

    # For each ForeignKey or ManyToMany field, check that a link is possible
    for field in model._meta.fields + model._meta.many_to_many:
        if field.rel and field.rel.to.__name__ not in allowed_links:
            return False

    return True



# EXCEPTIONS
#-------------------------------------------------------------------------------

class SkipValue(Exception):
    """ Value could not be parsed or should simply be skipped. """

class DoLater(Exception):
    """ Value could not be parsed or should simply be skipped. """
