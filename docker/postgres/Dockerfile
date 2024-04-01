FROM postgres:13

RUN apt update && apt install -y openssh-client rsync

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
