import os
import re
import django_extensions
from django.core.management.base import CommandError, LabelCommand, _make_writeable
from optparse import make_option

class Command(LabelCommand):
    option_list = LabelCommand.option_list + (
        make_option('--template', '-t', action='store', dest='app_template', 
            help='The path to the app template'),
        make_option('--parent_path', '-p', action='store', dest='parent_path', 
            help='The parent path of the app to be created'),
    )
    
    help = ("Creates a Django application directory structure based on the specified template directory.")
    args = "[appname]"
    label = 'application name'
    
    requires_model_validation = False
    can_import_settings = True
    
    def handle_label(self, label, **options):
        project_dir = os.getcwd()
        project_name = os.path.split(project_dir)[-1]
        app_name =label
        app_template = options.get('app_template') or os.path.join(django_extensions.__path__[0], 'conf', 'app_template')
        app_dir = os.path.join(options.get('parent_path') or project_dir, app_name)
                
        if not os.path.exists(app_template):
            raise CommandError("The template path, %r, does not exist." % app_template)
        
        if not re.search(r'^\w+$', label):
            raise CommandError("%r is not a valid application name. Please use only numbers, letters and underscores." % label)
        try:
            os.makedirs(app_dir)
        except OSError, e:
            raise CommandError(e)
        
        copy_template(app_template, app_dir, project_name, app_name)
        
def copy_template(app_template, copy_to, project_name, app_name):
    """copies the specified template directory to the copy_to location"""
    import shutil
    
    # walks the template structure and copies it
    for d, subdirs, files in os.walk(app_template):
        relative_dir = d[len(app_template)+1:]
        if relative_dir and not os.path.exists(os.path.join(copy_to, relative_dir)):
            os.mkdir(os.path.join(copy_to, relative_dir))
        for i, subdir in enumerate(subdirs):
            if subdir.startswith('.'):
                del subdirs[i]
        for f in files:
            if f.endswith('.pyc') or f.startswith('.DS_Store'):
                continue
            path_old = os.path.join(d, f)
            path_new = os.path.join(copy_to, relative_dir, f.replace('app_name', app_name))
            if os.path.exists(path_new):
                path_new = os.path.join(copy_to, relative_dir, f)
                if os.path.exists(path_new):
                    continue
            path_new = path_new.rstrip(".tmpl")
            fp_old = open(path_old, 'r')
            fp_new = open(path_new, 'w')
            fp_new.write(fp_old.read().replace('{{ app_name }}', app_name).replace('{{ project_name }}', project_name))
            fp_old.close()
            fp_new.close()
            try:
                shutil.copymode(path_old, path_new)
                _make_writeable(path_new)
            except OSError:
                sys.stderr.write(style.NOTICE("Notice: Couldn't set permission bits on %s. You're probably using an uncommon filesystem setup. No problem.\n" % path_new))
