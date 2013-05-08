from optparse import make_option
import sys

from django.core.exceptions import ImproperlyConfigured
from django.core.management.base import BaseCommand
from django.template import loader, Context
from haystack.backends.solr_backend import SolrSearchBackend
from haystack.constants import ID, DJANGO_CT, DJANGO_ID, DEFAULT_OPERATOR, DEFAULT_ALIAS


class Command(BaseCommand):
    help = "Generates a Solr schema that reflects the indexes."
    base_options = (
        make_option("-f", "--filename", action="store", type="string", dest="filename",
                    help='If provided, directs output to a file instead of stdout.'),
        make_option("-u", "--using", action="store", type="string", dest="using", default=DEFAULT_ALIAS,
                    help='If provided, chooses a connection to work with.'),
    )
    option_list = BaseCommand.option_list + base_options

    def handle(self, **options):
        """Generates a Solr schema that reflects the indexes."""
        using = options.get('using')
        schema_xml = self.build_template(using=using)

        if options.get('filename'):
            self.write_file(options.get('filename'), schema_xml)
        else:
            self.print_stdout(schema_xml)

    def build_context(self, using):
        from haystack import connections, connection_router
        backend = connections[using].get_backend()

        if not isinstance(backend, SolrSearchBackend):
            raise ImproperlyConfigured("'%s' isn't configured as a SolrEngine)." % backend.connection_alias)

        content_field_name, fields = backend.build_schema(connections[using].get_unified_index().all_searchfields())
        return Context({
            'content_field_name': content_field_name,
            'fields': fields,
            'default_operator': DEFAULT_OPERATOR,
            'ID': ID,
            'DJANGO_CT': DJANGO_CT,
            'DJANGO_ID': DJANGO_ID,
        })

    def build_template(self, using):
        t = loader.get_template('search_configuration/solr.xml')
        c = self.build_context(using=using)
        return t.render(c)

    def print_stdout(self, schema_xml):
        sys.stderr.write("\n")
        sys.stderr.write("\n")
        sys.stderr.write("\n")
        sys.stderr.write("Save the following output to 'schema.xml' and place it in your Solr configuration directory.\n")
        sys.stderr.write("--------------------------------------------------------------------------------------------\n")
        sys.stderr.write("\n")
        print schema_xml

    def write_file(self, filename, schema_xml):
        schema_file = open(filename, 'w')
        schema_file.write(schema_xml)
        schema_file.close()
