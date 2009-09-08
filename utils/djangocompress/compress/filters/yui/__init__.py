import subprocess

from django.conf import settings

from compress.filter_base import FilterBase, FilterError

BINARY = getattr(settings, 'COMPRESS_YUI_BINARY', 'java -jar yuicompressor.jar')
CSS_ARGUMENTS = getattr(settings, 'COMPRESS_YUI_CSS_ARGUMENTS', '')
JS_ARGUMENTS = getattr(settings, 'COMPRESS_YUI_JS_ARGUMENTS', '')

class YUICompressorFilter(FilterBase):

    def filter_common(self, content, type_, arguments):
        command = '%s --type=%s %s' % (BINARY, type_, arguments)

        if self.verbose:
            command += ' --verbose'

        p = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
        p.stdin.write(content)
        p.stdin.close()

        filtered_css = p.stdout.read()
        p.stdout.close()

        err = p.stderr.read()
        p.stderr.close()

        if p.wait() != 0:
            if not err:
                err = 'Unable to apply YUI Compressor filter'

            raise FilterError(err)

        if self.verbose:
            print err

        return filtered_css

    def filter_js(self, js):
        return self.filter_common(js, 'js', JS_ARGUMENTS)

    def filter_css(self, css):
        return self.filter_common(css, 'css', CSS_ARGUMENTS)