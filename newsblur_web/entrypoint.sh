#!/usr/bin/env sh

if [[ -z "${TEST}" && "${TEST}" = "True"  ]]
then echo "starting test env"
else gunicorn --bind :8000 newsblur_web.wsgi:application
fi
