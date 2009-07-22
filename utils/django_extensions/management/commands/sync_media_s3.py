"""
Sync Media to S3
================

Django command that scans all files in your settings.MEDIA_ROOT folder and
uploads them to S3 with the same directory structure.

This command can optionally do the following but it is off by default:
* gzip compress any CSS and Javascript files it finds and adds the appropriate
  'Content-Encoding' header.
* set a far future 'Expires' header for optimal caching.

Note: This script requires the Python boto library and valid Amazon Web
Services API keys.

Required settings.py variables:
AWS_ACCESS_KEY_ID = ''
AWS_SECRET_ACCESS_KEY = ''
AWS_BUCKET_NAME = ''

Command options are:
  -p PREFIX, --prefix=PREFIX
                        The prefix to prepend to the path on S3.
  --gzip                Enables gzipping CSS and Javascript files.
  --expires             Enables setting a far future expires header.
  --force               Skip the file mtime check to force upload of all
                        files.
  --filter-list         Override default directory and file exclusion
                        filters. (enter as comma seperated line)

TODO:
 * Use fnmatch (or regex) to allow more complex FILTER_LIST rules.

"""
import datetime
import email
import mimetypes
import optparse
import os
import sys
import time

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

# Make sure boto is available
try:
    import boto
    import boto.exception
except ImportError:
    raise ImportError, "The boto Python library is not installed."

class Command(BaseCommand):

    # Extra variables to avoid passing these around
    AWS_ACCESS_KEY_ID = ''
    AWS_SECRET_ACCESS_KEY = ''
    AWS_BUCKET_NAME = ''
    DIRECTORY = ''
    FILTER_LIST = ['.DS_Store', '.svn', '.hg', '.git', 'Thumbs.db']
    GZIP_CONTENT_TYPES = (
        'text/css',
        'application/javascript',
        'application/x-javascript'
    )

    upload_count = 0
    skip_count = 0

    option_list = BaseCommand.option_list + (
        optparse.make_option('-p', '--prefix',
            dest='prefix', default='',
            help="The prefix to prepend to the path on S3."),
        optparse.make_option('-d', '--dir',
            dest='dir', default=settings.MEDIA_ROOT,
            help="The root directory to use instead of your MEDIA_ROOT"),
        optparse.make_option('--gzip',
            action='store_true', dest='gzip', default=False,
            help="Enables gzipping CSS and Javascript files."),
        optparse.make_option('--expires',
            action='store_true', dest='expires', default=False,
            help="Enables setting a far future expires header."),
        optparse.make_option('--force',
            action='store_true', dest='force', default=False,
            help="Skip the file mtime check to force upload of all files."),
        optparse.make_option('--filter-list', dest='filter_list',
            action='store', default='',
            help="Override default directory and file exclusion filters. (enter as comma seperated line)"),
    )

    help = 'Syncs the complete MEDIA_ROOT structure and files to S3 into the given bucket name.'
    args = 'bucket_name'

    can_import_settings = True

    def handle(self, *args, **options):

        # Check for AWS keys in settings
        if not hasattr(settings, 'AWS_ACCESS_KEY_ID') or \
           not hasattr(settings, 'AWS_SECRET_ACCESS_KEY'):
           raise CommandError('Missing AWS keys from settings file.  Please' +
                     'supply both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.')
        else:
            self.AWS_ACCESS_KEY_ID = settings.AWS_ACCESS_KEY_ID
            self.AWS_SECRET_ACCESS_KEY = settings.AWS_SECRET_ACCESS_KEY

        if not hasattr(settings, 'AWS_BUCKET_NAME'):
            raise CommandError('Missing bucket name from settings file. Please' +
                ' add the AWS_BUCKET_NAME to your settings file.')
        else:
            if not settings.AWS_BUCKET_NAME:
                raise CommandError('AWS_BUCKET_NAME cannot be empty.')
        self.AWS_BUCKET_NAME = settings.AWS_BUCKET_NAME

        if not hasattr(settings, 'MEDIA_ROOT'):
            raise CommandError('MEDIA_ROOT must be set in your settings.')
        else:
            if not settings.MEDIA_ROOT:
                raise CommandError('MEDIA_ROOT must be set in your settings.')

        self.verbosity = int(options.get('verbosity'))
        self.prefix = options.get('prefix')
        self.do_gzip = options.get('gzip')
        self.do_expires = options.get('expires')
        self.do_force = options.get('force')
        self.DIRECTORY = options.get('dir')
        self.FILTER_LIST = getattr(settings, 'FILTER_LIST', self.FILTER_LIST)
        filter_list = options.get('filter_list').split(',')
        if filter_list:
            # command line option overrides default filter_list and
            # settings.filter_list
            self.FILTER_LIST = filter_list

        # Now call the syncing method to walk the MEDIA_ROOT directory and
        # upload all files found.
        self.sync_s3()

        print
        print "%d files uploaded." % (self.upload_count)
        print "%d files skipped." % (self.skip_count)

    def sync_s3(self):
        """
        Walks the media directory and syncs files to S3
        """
        bucket, key = self.open_s3()
        os.path.walk(self.DIRECTORY, self.upload_s3,
            (bucket, key, self.AWS_BUCKET_NAME, self.DIRECTORY))

    def compress_string(self, s):
        """Gzip a given string."""
        import cStringIO, gzip
        zbuf = cStringIO.StringIO()
        zfile = gzip.GzipFile(mode='wb', compresslevel=6, fileobj=zbuf)
        zfile.write(s)
        zfile.close()
        return zbuf.getvalue()

    def open_s3(self):
        """
        Opens connection to S3 returning bucket and key
        """
        conn = boto.connect_s3(self.AWS_ACCESS_KEY_ID, self.AWS_SECRET_ACCESS_KEY)
        try:
            bucket = conn.get_bucket(self.AWS_BUCKET_NAME)
        except boto.exception.S3ResponseError:
            bucket = conn.create_bucket(self.AWS_BUCKET_NAME)
        return bucket, boto.s3.key.Key(bucket)

    def upload_s3(self, arg, dirname, names):
        """
        This is the callback to os.path.walk and where much of the work happens
        """
        bucket, key, bucket_name, root_dir = arg # expand arg tuple

        # Skip directories we don't want to sync
        if os.path.basename(dirname) in self.FILTER_LIST:
            # prevent walk from processing subfiles/subdirs below the ignored one
            del names[:]
            return 

        # Later we assume the MEDIA_ROOT ends with a trailing slash
        if not root_dir.endswith(os.path.sep):
            root_dir = root_dir + os.path.sep

        for file in names:
            headers = {}

            if file in self.FILTER_LIST:
                continue # Skip files we don't want to sync

            filename = os.path.join(dirname, file)
            if os.path.isdir(filename):
                continue # Don't try to upload directories

            file_key = filename[len(root_dir):]
            if self.prefix:
                file_key = '%s/%s' % (self.prefix, file_key)

            # Check if file on S3 is older than local file, if so, upload
            if not self.do_force:
                s3_key = bucket.get_key(file_key)
                if s3_key:
                    s3_datetime = datetime.datetime(*time.strptime(
                        s3_key.last_modified, '%a, %d %b %Y %H:%M:%S %Z')[0:6])
                    local_datetime = datetime.datetime.utcfromtimestamp(
                        os.stat(filename).st_mtime)
                    if local_datetime < s3_datetime:
                        self.skip_count += 1
                        if self.verbosity > 1:
                            print "File %s hasn't been modified since last " \
                                "being uploaded" % (file_key)
                        continue

            # File is newer, let's process and upload
            if self.verbosity > 0:
                print "Uploading %s..." % (file_key)

            content_type = mimetypes.guess_type(filename)[0]
            if content_type:
                headers['Content-Type'] = content_type
            file_obj = open(filename, 'rb')
            file_size = os.fstat(file_obj.fileno()).st_size
            filedata = file_obj.read()
            if self.do_gzip:
                # Gzipping only if file is large enough (>1K is recommended) 
                # and only if file is a common text type (not a binary file)
                if file_size > 1024 and content_type in self.GZIP_CONTENT_TYPES:
                    filedata = self.compress_string(filedata)
                    headers['Content-Encoding'] = 'gzip'
                    if self.verbosity > 1:
                        print "\tgzipped: %dk to %dk" % \
                            (file_size/1024, len(filedata)/1024)
            if self.do_expires:
                # HTTP/1.0
                headers['Expires'] = '%s GMT' % (email.Utils.formatdate(
                    time.mktime((datetime.datetime.now() +
                    datetime.timedelta(days=365*2)).timetuple())))
                # HTTP/1.1
                headers['Cache-Control'] = 'max-age %d' % (3600 * 24 * 365 * 2)
                if self.verbosity > 1:
                    print "\texpires: %s" % (headers['Expires'])
                    print "\tcache-control: %s" % (headers['Cache-Control'])

            try:
                key.name = file_key
                key.set_contents_from_string(filedata, headers, replace=True)
                key.set_acl('public-read')
            except boto.s3.connection.S3CreateError, e:
                print "Failed: %s" % e
            except Exception, e:
                print e
                raise
            else:
                self.upload_count += 1

            file_obj.close()

# Backwards compatibility for Django r9110
if not [opt for opt in Command.option_list if opt.dest=='verbosity']:
    Command.option_list += (
        optparse.make_option('-v', '--verbosity',
            dest='verbosity', default=1, action='count',
            help="Verbose mode. Multiple -v options increase the verbosity."),
    )
