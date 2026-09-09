ARG RAILS_IMAGE=ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
FROM ${RAILS_IMAGE}

ENV RAILS_ENV=production \
    PORT=7860 \
    RAILS_LOG_TO_STDOUT=true \
    JWT_AUTH_HEADER=Authorization

EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:7860/up || exit 1

CMD ["./bin/thrust", "./bin/rails", "server"]
