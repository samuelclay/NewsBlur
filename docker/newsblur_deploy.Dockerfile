FROM newsblur/newsblur_python3
ENV DOCKERBUILD=True

RUN apt update
RUN apt install -y curl

# Install Java
# Install OpenJDK-11
RUN apt install -y openjdk-11-jre-headless
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64/
RUN export JAVA_HOME
WORKDIR /tmp
RUN apt install wget unzip
RUN wget "https://dl.google.com/closure-compiler/compiler-20200719.zip"
RUN unzip "compiler-20200719.zip"
RUN mv closure-compiler-v20200719.jar /usr/local/bin/compiler.jar

# Install Node
RUN curl -fsSL https://deb.nodesource.com/setup_current.x | bash -
RUN apt install -y nodejs build-essential
RUN	npm -g install yuglify

# Cleanup
RUN apt-get clean

WORKDIR /srv/newsblur
CMD python manage.py collectstatic --no-input --clear -v 1 -l
