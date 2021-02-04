import os
from glob import glob
import subprocess
playbooks = glob('*setup_*.yml')
playbooks.remove('setup_www.yml')
os.chdir('..')
[subprocess.call(f'ansible-playbook ansible/{playbook}', shell=True) for playbook in playbooks ]
