FROM postgres:13

RUN apt update && apt install -y openssh-client rsync

RUN usermod -u 1000 postgres
RUN groupmod -g 1001 postgres
