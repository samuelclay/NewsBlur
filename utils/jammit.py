import os
from fnmatch import fnmatch
import yaml
from django.conf import settings

DATA_URI_START = "<!--[if (!IE)|(gte IE 8)]><!-->"
DATA_URI_END = "<!--<![endif]-->"
MHTML_START = "<!--[if lte IE 7]>"
MHTML_END = "<![endif]-->"

class JammitAssets:

    ASSET_FILENAME = 'assets.yml'
    
    def __init__(self, assets_dir):
        """
        Initializes the Jammit object by reading the assets.yml file and
        stores all javascripts and stylesheets in memory for easy lookup
        in templates.
        """
        self.assets_dir = assets_dir
        self.assets = self.read_assets()
        
    def read_assets(self):
        """
        Read the assets from the YAML and store it as a lookup dictionary.
        """
        filepath = os.path.join(self.assets_dir, self.ASSET_FILENAME)

        with open(filepath, 'r') as yaml_file:
            return yaml.safe_load(yaml_file)
    
    def render_tags(self, asset_type, asset_package):
        """
        Returns rendered <script> and <link> tags for the given package name. Will
        either be a single tag or a list of tags as a string, depending on 
        `use_compressed_assets` profile setting.
        """
        tags = []
        if not getattr(settings, 'DEBUG_ASSETS', settings.DEBUG):
            if asset_type == 'javascripts':
                asset_type_ext = 'js'
            elif asset_type == 'stylesheets':
                asset_type_ext = 'css'
            if asset_type == 'javascripts':
                tag = self.javascript_tag_compressed(asset_package, asset_type_ext)
            elif asset_type == 'stylesheets':
                tag = self.stylesheet_tag_compressed(asset_package, asset_type_ext)
            tags.append(tag)
        else:
            patterns = self.assets[asset_type][asset_package]
            for pattern in patterns:
                paths = FileFinder.filefinder(pattern)
                for path in paths:
                    if asset_type == 'javascripts':
                        tag = self.javascript_tag(path)
                    elif asset_type == 'stylesheets':
                        tag = self.stylesheet_tag(path)
                    tags.append(tag)
        tags = self.uniquify(tags)
        return '\n'.join(tags)
    
    def render_code(self, asset_type, asset_package):
        text = []
        patterns = self.assets[asset_type][asset_package]
        
        for pattern in patterns:
            paths = FileFinder.filefinder(pattern)
            for path in paths:
                newsblur_dir = settings.NEWSBLUR_DIR
                abs_filename = os.path.join(newsblur_dir, path)
                f = open(abs_filename, 'r')
                code = f.read()
                if asset_type == 'stylesheets':
                    code = code.replace('\"', '\\"').replace('\n', ' ')
                text.append(code)
        
        return ''.join(text)
    
    def uniquify(self, tags):
        """
        Returns a uniquified list of script/link tags, preserving order.
        """
        seen = set()
        unique = []
        
        for tag in tags:
            if tag not in seen:
                unique.append(tag)
                seen.add(tag)

        return unique
    
    def javascript_tag(self, path):
        return '<script src="/%s" type="text/javascript" charset="utf-8"></script>' % path
    
    def javascript_tag_compressed(self, asset_package, asset_type_ext):
        filename = 'static/%s.%s' % (asset_package, asset_type_ext)
        asset_mtime = int(os.path.getmtime(filename))
        path = '%s?%s' % (filename, asset_mtime)
        return self.javascript_tag(path)
    
    def stylesheet_tag(self, path):
        return '<link rel="stylesheet" href="/%s" type="text/css" charset="utf-8">' % path

    def stylesheet_tag_compressed(self, asset_package, asset_type_ext):
        datauri_filename = 'static/%s-datauri.%s' % (asset_package, asset_type_ext)
        original_filename = 'static/%s.%s' % (asset_package, asset_type_ext)
        asset_mtime = int(os.path.getmtime(datauri_filename))
        datauri_path = '%s?%s' % (datauri_filename, asset_mtime)
        original_path = '%s?%s' % (original_filename, asset_mtime)
        
        return '\n'.join([
            DATA_URI_START,
            self.stylesheet_tag(datauri_path),
            DATA_URI_END,
            MHTML_START,
            self.stylesheet_tag(original_path),
            MHTML_END,
        ])

class FileFinder:

    @classmethod
    def filefinder(cls, pattern):
        paths = []
        if '**' in pattern:
            folder, wild, pattern = pattern.partition('/**/')
            for f in cls.recursive_find_files(folder, pattern):
                paths.append(f)
        else:
            folder, pattern = os.path.split(pattern)
            for f in cls.find_files(folder, pattern):
                # print f, paths
                paths.append(f)
        return paths

    @classmethod
    def recursive_find_files(cls, folder, pattern):
        for root, dirs, files in os.walk(folder):
            for f in files:
                if fnmatch(f, pattern):
                    yield os.path.join(root, f)

    @classmethod
    def find_files(cls, folder, pattern):
        listdir = os.listdir(folder)
        listdir.sort()
        for entry in listdir:
            if not os.path.isdir(entry) and fnmatch(entry, pattern):
                yield os.path.join(folder, entry)
