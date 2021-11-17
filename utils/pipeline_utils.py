from django.conf import settings
from pipeline.finders import FileSystemFinder as PipelineFileSystemFinder
from pipeline.storage import GZIPMixin
from pipeline.storage import PipelineManifestStorage

class PipelineStorage(PipelineManifestStorage):
    def url(self, *args, **kwargs):
        url = super().url(*args, **kwargs)
        if settings.DEBUG_ASSETS:
            url = url.replace(settings.STATIC_URL, settings.MEDIA_URL)
        print(f"Pipeline storage: {args} {kwargs} {url}")
        return url

class GzipPipelineStorage(GZIPMixin, PipelineStorage):
    pass

class FileSystemFinder(PipelineFileSystemFinder):
    """
    Like FileSystemFinder, but doesn't return any additional ignored patterns

    This allows us to concentrate/compress our components without dragging
    the raw versions in too.
    """
    ignore_patterns = [
        # '*.js',
        # '*.css',
        '*.less',
        '*.scss',
        '*.styl',
        '*.sh',
        '*.html',
        '*.md',
        '*.markdown',
        '*.php',
        '*.txt',
        '*.gif',
        '*.png',
        '*.jpg',
        '*.svg',
        '*.ico',
        '*.psd',
        '*.ai',
        '*.sketch',
        '*.emf',
        '*.eps',
        '*.pdf',
        '*.xml',
        'README*',
        'LICENSE*',
        '*examples*',
        '*test*',
        '*bin*',
        '*samples*',
        '*docs*',
        '*build*',
        '*demo*',
        '*admin*',
        '*android*',
        '*blog*',
        # '*bookmarklet*',
        # '*circular*',
        # '*embed*',
        '*extensions*',
        '*ios*',
        '*android*',
        '*flash*',
        '*fonts*',
        '*images*',
        # '*jquery-ui*',
        '*mobile*',
        '*safari*',
        # '*social*',
        # '*vendor*',
        'Makefile*',
        'Gemfile*',
        'node_modules',
    ]
