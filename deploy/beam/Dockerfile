ARG RAILS_IMAGE=ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
FROM ${RAILS_IMAGE}

USER root
HEALTHCHECK NONE

COPY --chown=1000:1000 entrypoint.sh /usr/local/bin/beam-entrypoint
COPY --chown=1000:1000 beam_logging.rb /rails/config/initializers/beam_logging.rb
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/beam-entrypoint \
    && sed -i 's/\r$//' /usr/local/bin/beam-entrypoint \
    && chmod 0755 /usr/local/bin/beam-entrypoint \
    && bash -n /usr/local/bin/beam-entrypoint \
    && ruby -c /rails/config/initializers/beam_logging.rb

USER 1000:1000
WORKDIR /rails
ENTRYPOINT ["/bin/bash", "/usr/local/bin/beam-entrypoint"]
