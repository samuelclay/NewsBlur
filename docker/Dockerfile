FROM       debian:jessie
MAINTAINER julien@rottenberg.info


WORKDIR  /opt/newsblur
#
RUN       apt-get update && apt-get install -y python-pip python-requests-whl python-dev libxslt1-dev libxml2-dev zlib1g-dev  lib32ncurses5-dev  libjpeg-dev libpq-dev libblas-dev liblapack-dev gfortran
COPY      requirements.txt /opt/newsblur/
RUN       pip install -r requirements.txt; pip install image psycopg2 numpy scipy

COPY      . /opt/newsblur/
RUN       cp docker/local_settings.py .
CMD       gunicorn_django --bind 0.0.0.0:8000
