FROM fireflyiii/core@sha256:783676cad3a9aed58539ae270d6849f15abefc4300175f1526b3f46b74ad96ce

USER root

RUN pecl install opentelemetry \
    && docker-php-ext-enable opentelemetry \
    && rm -rf /tmp/pear /tmp/download

USER www-data
