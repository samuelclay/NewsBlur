FROM newsblur/newsblur_python3
ENV DOCKERBUILD=True

RUN apt update
RUN apt install -y curl
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt install -y nodejs build-essential
RUN	npm -g install yuglify
RUN	npm -g install google-closure-compiler

WORKDIR /srv/newsblur
CMD python manage.py collectstatic --no-input --clear -v 3 -l
# CMD python manage.py findstatic -v 3 js/newsblur/reader/reader_admin.js
