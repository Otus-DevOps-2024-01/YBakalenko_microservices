FROM fluent/fluentd:v1.17-1

USER root

RUN apk add --no-cache --update --virtual .build-deps \
    sudo build-base ruby-dev && \
    gem install fluent-plugin-elasticsearch --no-document && \
    gem install fluent-plugin-grok-parser --no-document
ADD fluent.conf /fluentd/etc

USER fluent
