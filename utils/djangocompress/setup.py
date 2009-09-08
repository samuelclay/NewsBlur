from distutils.core import setup
import os

# Compile the list of packages available, because distutils doesn't have
# an easy way to do this.
packages, data_files = [], []
root_dir = os.path.dirname(__file__)
if root_dir:
    os.chdir(root_dir)

# snippet from http://django-registration.googlecode.com/svn/trunk/setup.py
for dirpath, dirnames, filenames in os.walk('compress'):
    # Ignore dirnames that start with '.'
    for i, dirname in enumerate(dirnames):
        if dirname.startswith('.'): del dirnames[i]
    if '__init__.py' in filenames:
        pkg = dirpath.replace(os.path.sep, '.')
        if os.path.altsep:
            pkg = pkg.replace(os.path.altsep, '.')
        packages.append(pkg)
    elif filenames:
        prefix = dirpath[9:] # Strip "registration/" or "registration\"
        for f in filenames:
            data_files.append(os.path.join(prefix, f))

setup(
    name='django-compress',
    version='1.0.1',
    description='django-compress provides an automated system for compressing CSS and JavaScript files',
    author='Andreas Pelme',
    author_email='Andreas Pelme <andreas@pelme.se>',
    url='http://code.google.com/p/django-compress/',
    packages = packages,
    package_data = {'compress': data_files,},
    classifiers=[
        'Environment :: Web Environment',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python',
        'Topic :: Utilities',
    ]
)
