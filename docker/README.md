Docker related informations
===========================

Install
-------


for PIL (image) libjpeg-dev

DEVELOPMENT just based on presence of /Users in code dir

Missing from template : REDIS_SESSIONS, postgresql_psycopg2


## One time setup

On newsblur :
docker-compose run newsblur ./manage.py syncdb --all --noinput

docker-compose run newsblur ./manage.py loaddata docker/data.json

docker-compose run -e PGPASSWORD=newsblur   postgres pg_dump -h newsblur_postgres_1 -U newsblur newsblur  | gzip > docker/postgres/init.sql.gz



pip numpy, scipy + apt gfortran libblas-dev liblapack-dev for ./manage.py refresh_feeds --force
