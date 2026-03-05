ARG BASE_IMAGE=newsblur/newsblur_python3
FROM ${BASE_IMAGE}
ENV DOCKERBUILD=True

RUN apt update
RUN apt install -y curl

# Install Java
# Install OpenJDK-11
RUN apt install -y default-jre
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64/
RUN export JAVA_HOME
WORKDIR /tmp
RUN apt install -y wget unzip
RUN wget "https://dl.google.com/closure-compiler/compiler-20200719.zip"
RUN unzip "compiler-20200719.zip"
RUN mv closure-compiler-v20200719.jar /usr/local/bin/compiler.jar

# Install lightningcss for CSS compression (replaces yuglify)
RUN uv pip install lightningcss

# Cleanup
RUN apt-get clean

WORKDIR /srv/newsblur
CMD python manage.py collectstatic --no-input --clear -v 1 -l && \
    echo "Validating static assets..." && \
    CSS_SIZE=$(stat -c%s /srv/newsblur/static/css/common.css 2>/dev/null || echo 0) && \
    JS_SIZE=$(stat -c%s /srv/newsblur/static/js/common.js 2>/dev/null || echo 0) && \
    echo "common.css: ${CSS_SIZE} bytes, common.js: ${JS_SIZE} bytes" && \
    if [ "$CSS_SIZE" -lt 1000 ]; then echo "ERROR: common.css is empty or too small (${CSS_SIZE} bytes) - CSS compression failed"; exit 1; fi && \
    if [ "$JS_SIZE" -lt 1000 ]; then echo "ERROR: common.js is empty or too small (${JS_SIZE} bytes) - closure compiler likely crashed"; exit 1; fi && \
    echo "Static assets validated successfully"
