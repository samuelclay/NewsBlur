#!/usr/bin/env bash

if [[ -z "${TEST}" && "${TEST}" = "True"  ]]
then echo "starting test env"
else python3 manage.py check_db; gunicorn -c config/gunicorn_conf.py newsblur_web.wsgi:application
fi
