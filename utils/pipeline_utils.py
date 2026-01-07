import glob as python_glob

# Debug glob expansion - enables glob expansion in DEBUG_ASSETS mode
import logging
import os
import re

from django.conf import settings
from django.contrib.staticfiles.finders import find
from pipeline.finders import AppDirectoriesFinder as PipelineAppDirectoriesFinder
from pipeline.finders import FileSystemFinder as PipelineFileSystemFinder
from pipeline.packager import Package
from pipeline.storage import GZIPMixin, PipelineManifestStorage

logger = logging.getLogger(__name__)

_original_sources_fget = Package.sources.fget


def debug_sources(self):
    """Wrapper around Package.sources that expands globs using filesystem when in DEBUG mode."""
    if not self._sources:
        paths = []
        for pattern in self.config.get("source_filenames", []):
            if "*" in pattern:
                # Use filesystem glob since collectstatic hasn't been run
                # Try to find files in STATICFILES_DIRS (media directory)
                media_root = getattr(settings, "MEDIA_ROOT", "/srv/newsblur/media")
                full_pattern = os.path.join(media_root, pattern)
                matches = python_glob.glob(full_pattern)
                # Convert back to relative paths
                for match in matches:
                    rel_path = os.path.relpath(match, media_root)
                    if rel_path not in paths:
                        paths.append(rel_path)
                if settings.DEBUG_ASSETS and matches:
                    logger.debug(
                        f"[GLOB] Pattern '{pattern}' matched {len(matches)} files: {[os.path.relpath(m, media_root) for m in matches]}"
                    )
            else:
                # Not a glob pattern, add as-is if it exists
                if pattern not in paths and find(pattern):
                    paths.append(str(pattern))
        self._sources = paths
    return self._sources


if settings.DEBUG_ASSETS:
    Package.sources = property(debug_sources)


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
        path = path or ""
        for pattern in self.find_pattern_matches(path):
            for path in storage.listdir(pattern[0])[1]:
                if self.is_ignored(path, pattern[0]):
                    continue
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
        path = path or ""
        for pattern in self.find_pattern_matches(path):
            for path in storage.listdir(pattern[0])[1]:
                if self.is_ignored(path, pattern[0]):
                    continue
                yield path, storage
