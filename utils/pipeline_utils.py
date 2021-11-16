from pipeline.finders import FileSystemFinder as PipelineFileSystemFinder


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
