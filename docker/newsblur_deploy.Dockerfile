FROM newsblur/newsblur_python3
ENV DOCKERBUILD=True

RUN apt update
RUN apt install -y curl nodejs npm

# Install terser for JS minification (replaces Closure Compiler)
RUN npm install -g terser

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
    if [ "$JS_SIZE" -lt 1000 ]; then echo "ERROR: common.js is empty or too small (${JS_SIZE} bytes) - terser likely crashed"; exit 1; fi && \
    echo "Static assets validated successfully"
