Docker related informations
===========================

Install
-------

pip and requests https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=744145

for PIL (image) libjpeg-dev

DEVELOPMENT just based on presence of /Users in code dir

psycopg2 commented out ?

Missing from template : REDIS_SESSIONS, postgresql_psycopg2

./manage.py syncdb --all --noinput && ./manage.py loaddata docker/data.json

pip numpy , scipy + apt gfortran libblas-dev liblapack-dev for ./manage.py refresh_feeds --force
