FROM       python:2.7-slim
MAINTAINER julien@rottenberg.info


WORKDIR   /opt/newsblur
ENV       PYTHONPATH=/opt/newsblur

CMD       ["gunicorn", "--bind", "0.0.0.0:8000", "wsgi"]
EXPOSE    8000

COPY      config/requirements.txt /opt/newsblur/
RUN       set -ex \
          && rundDeps=' \
                  libpq5 \
                  libjpeg62 \
                  libxslt1.1 \
                            ' \
          && buildDeps=' \
                    patch \
                    python-dev \
                    gfortran \
                    lib32ncurses5-dev  \
                    libblas-dev \
			              libffi-dev \
                    libjpeg-dev \
                    libmysqlclient-dev \
                    libpq-dev \
                    libreadline6-dev \
                    liblapack-dev \
                    libxml2-dev \
                    libxslt1-dev \
                    ncurses-dev \
                    zlib1g-dev \
                            ' \
            && apt-get update \
            && apt-get install -y $rundDeps $buildDeps --no-install-recommends \
            && pip install -r requirements.txt \
            && apt-get purge -y --auto-remove ${buildDeps} \
            && rm -rf /var/lib/apt/lists/*


COPY      . /opt/newsblur/
RUN       cp docker/local_settings.py .
