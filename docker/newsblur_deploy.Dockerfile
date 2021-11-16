FROM newsblur/newsblur_python3
ENV DOCKERBUILD=True

RUN apt update
RUN apt install -y curl
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt install -y nodejs build-essential
RUN	npm -g install yuglify

WORKDIR /srv/newsblur
CMD python manage.py collectstatic --no-input