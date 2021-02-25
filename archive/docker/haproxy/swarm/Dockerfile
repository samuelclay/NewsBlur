FROM newsblur/newsblur_python3
FROM haproxy:1.8.22
ENV PYTHONUNBUFFERED=1
ENV NEWSBLUR_PATH=/srv/newsblur
WORKDIR   /srv/newsblur

RUN /bin/bash -c 'echo "ENABLED=1" | tee /etc/default/haproxy'
RUN /bin/bash -c 'mkdir -p /srv/newsblur/config/certificates/'
COPY 'config/haproxy_rsyslog.conf' '/etc/rsyslog.d/49-haproxy.conf'
COPY 'docker/haproxy/swarm/haproxy.conf' '/usr/local/etc/haproxy/haproxy.cfg'
COPY '/docker/haproxy/haproxy.conf' '/usr/local/etc/haproxy/haproxy.conf'