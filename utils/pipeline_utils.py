import logging
import re

from django.conf import settings
from pipeline.finders import AppDirectoriesFinder as PipelineAppDirectoriesFinder
from pipeline.finders import FileSystemFinder as PipelineFileSystemFinder
from pipeline.storage import GZIPMixin, PipelineManifestStorage

# Debug glob expansion (commented out - uncomment to debug asset glob patterns)
# from pipeline.packager import Package
# from pipeline.glob import glob as pipeline_glob_func
# from django.contrib.staticfiles.finders import find
#
# logger = logging.getLogger(__name__)
#
# _original_sources_fget = Package.sources.fget
#
# def debug_sources(self):
#     """Wrapper around Package.sources that adds debugging."""
#     if not self._sources:
#         paths = []
#         for pattern in self.config.get('source_filenames', []):
#             print(f"[GLOB DEBUG] Processing pattern: {pattern}")
#             matches = list(pipeline_glob_func(pattern))
#             print(f"[GLOB DEBUG] Pattern '{pattern}' matched: {matches}")
#             for path in matches:
#                 if path not in paths and find(path):
#                     paths.append(str(path))
#         self._sources = paths
#     return self._sources
#
# Package.sources = property(debug_sources)


class PipelineStorage(PipelineManifestStorage):
    def url(self, *args, **kwargs):
        if settings.DEBUG_ASSETS:
            # print(f"Pre-Pipeline storage: {args} {kwargs}")
            kwargs["name"] = re.sub(r"\.[a-f0-9]{12}\.(css|js)$", r".\1", args[0])
            args = args[1:]
        url = super().url(*args, **kwargs)
        if settings.DEBUG_ASSETS:
            url = url.replace(settings.STATIC_URL, settings.MEDIA_URL)
            url = re.sub(r"\.[a-f0-9]{12}\.(css|js)$", r".\1", url)
        # print(f"Pipeline storage: {args} {kwargs} {url}")
        return url


class GzipPipelineStorage(GZIPMixin, PipelineManifestStorage):
    pass


class AppDirectoriesFinder(PipelineAppDirectoriesFinder):
    """
    Like AppDirectoriesFinder, but doesn't return any additional ignored patterns

    This allows us to concentrate/compress our components without dragging
    the raw versions in too.
    """

    ignore_patterns = [
        # '*.js',
        # '*.css',
        "*.less",
        "*.scss",
        "*.styl",
        "*.sh",
        "*.html",
        "*.ttf",
        "*.md",
        "*.markdown",
        "*.php",
        "*.txt",
        # '*.gif', # due to django_extensions/css/jquery.autocomplete.css: django_extensions/img/indicator.gif
        "*.png",
        "*.jpg",
        # '*.svg', # due to admin/css/base.css: admin/img/sorting-icons.svg
        "*.ico",
        "*.icns",
        "*.psd",
        "*.ai",
        "*.sketch",
        "*.emf",
        "*.eps",
        "*.pdf",
        "*.xml",
        "*LICENSE*",
        "*README*",
    ]

    def find_files(self, storage, path=None, all=False):
        """
        Override to properly handle wildcard patterns like 'underscore-*.js'
        """
        import logging
        logger = logging.getLogger(__name__)

        path = path or ""
        logger.debug(f"[AppDirectoriesFinder] find_files called with path: {path}")
        for pattern in self.find_pattern_matches(path):
            logger.debug(f"[AppDirectoriesFinder] Pattern match: {pattern}")
            for path in storage.listdir(pattern[0])[1]:
                if self.is_ignored(path, pattern[0]):
                    logger.debug(f"[AppDirectoriesFinder] Ignored: {path}")
                    continue
                logger.debug(f"[AppDirectoriesFinder] Yielding: {path}")
                yield path, storage


class FileSystemFinder(PipelineFileSystemFinder):
    """
    Like FileSystemFinder, but doesn't return any additional ignored patterns

    This allows us to concentrate/compress our components without dragging
    the raw versions in too.
    """

    ignore_patterns = [
        # '*.js',
        # '*.css',
        # '*.less',
        # '*.scss',
        # '*.styl',
        "*.sh",
        "*.html",
        "*.ttf",
        "*.md",
        "*.markdown",
        "*.php",
        "*.txt",
        "*.gif",
        "*.png",
        "*.jpg",
        "*media/**/*.svg",
        "*.ico",
        "*.icns",
        "*.psd",
        "*.ai",
        "*.sketch",
        "*.emf",
        "*.eps",
        "*.pdf",
        "*.xml",
        "*embed*",
        "blog*",
        # # '*bookmarklet*',
        # # '*circular*',
        # # '*embed*',
        "*css/mobile*",
        "*extensions*",
        "fonts/*/*.css",
        "*flash*",
        # '*jquery-ui*',
        # 'mobile*',
        "*safari*",
        # # '*social*',
        # # '*vendor*',
        # 'Makefile*',
        # 'Gemfile*',
        "node_modules",
    ]

    def find_files(self, storage, path=None, all=False):
        """
        Override to properly handle wildcard patterns like 'underscore-*.js'
        """
        import logging
        logger = logging.getLogger(__name__)

        path = path or ""
        logger.debug(f"[FileSystemFinder] find_files called with path: {path}")
        for pattern in self.find_pattern_matches(path):
            logger.debug(f"[FileSystemFinder] Pattern match: {pattern}")
            for path in storage.listdir(pattern[0])[1]:
                if self.is_ignored(path, pattern[0]):
                    logger.debug(f"[FileSystemFinder] Ignored: {path}")
                    continue
                logger.debug(f"[FileSystemFinder] Yielding: {path}")
                yield path, storage
