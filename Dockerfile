FROM jruby:9.1.2-alpine

RUN apk add --update git && apk add curl && rm -rf /var/cache/apk/*

RUN mkdir /opt/ernest-libraries/ && cd /opt/ernest-libraries && git clone https://github.com/r3labs/myst

ADD . /opt/ernest/network-deleter-vcloud-connector
WORKDIR /opt/ernest/network-deleter-vcloud-connector

RUN curl https://s3-eu-west-1.amazonaws.com/ernest-tools/bash-nats -o /bin/bash-nats && chmod +x /bin/bash-nats
RUN jruby -S bundle install --gemfile=Gemfile-Docker

ENTRYPOINT ./run.sh
