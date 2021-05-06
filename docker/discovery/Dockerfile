FROM      newsblur/newsblur_python3:latest
WORKDIR   /srv/newsblur
ENV       PYTHONPATH=/srv/newsblur
COPY      config/requirements.discovery.txt /srv/newsblur/
RUN       pip install -r requirements.discovery.txt
