FROM fireflyiii/core@sha256:fe4ecec4c2ba2b2978a32b3defaf270407f9fddf0e789a18648121ab84bb68d2

RUN pecl install opentelemetry \
    && docker-php-ext-enable opentelemetry \
    && rm -rf /tmp/pear /tmp/download
