FROM centos

RUN yum update -y

# Install RVM + Ruby
RUN yum install -y which tar git
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN \curl -L https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install ruby-2.4.1"
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

#ADD . /app
#
#CMD ./launch.sh

RUN mkdir -p /app && cd app && git clone https://github.com/square/kochiku-worker.git
WORKDIR /app/kochiku-worker

RUN mkdir -p tmp/build-partition
RUN /bin/bash -l -c "bundle install"

COPY launch.sh .
RUN chmod a+x launch.sh

ENV KOCHIKUMASTER_PORT_80_TCP_ADDR kochiku-master-test-1
ENV KOCHIKUMASTER_PORT_80_TCP_PORT 80
ENV KOCHIKU_REDIS_HOST kochiku-master-test-1
ENV KOCHIKU_REDIS_PORT 6379

CMD ./launch.sh
