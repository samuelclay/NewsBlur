#!/usr/bin/env bash

if [[ -z "${TEST}" && "${TEST}" = "True"  ]]
then echo "starting test env"
else python3 manage.py check_db; gunicorn --bind :8000 newsblur_web.wsgi:application
fi
