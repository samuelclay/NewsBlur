import os
import warnings
import tempfile

from django.conf import settings

from compress.filter_base import FilterBase

BINARY = getattr(settings, 'CSSTIDY_BINARY', 'csstidy')
ARGUMENTS = getattr(settings, 'CSSTIDY_ARGUMENTS', '--template=highest')

warnings.simplefilter('ignore', RuntimeWarning)

class CSSTidyFilter(FilterBase):
    def filter_css(self, css):
        tmp_file = tempfile.NamedTemporaryFile(mode='w+b')
        tmp_file.write(css)
        tmp_file.flush()

        output_file = tempfile.NamedTemporaryFile(mode='w+b')
        
        command = '%s %s %s %s' % (BINARY, tmp_file.name, ARGUMENTS, output_file.name)
        
        command_output = os.popen(command).read()
        
        filtered_css = output_file.read()
        output_file.close()
        tmp_file.close()
        
        if self.verbose:
            print command_output
        
        return filtered_css
