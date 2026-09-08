ARG RAILS_IMAGE=ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-1d842b1
FROM ${RAILS_IMAGE}

ENV RAILS_ENV=production \
    PORT=7860 \
    RAILS_LOG_TO_STDOUT=true \
    JWT_AUTH_HEADER=Authorization

EXPOSE 7860

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:7860/up || exit 1

CMD ["./bin/rails", "server", "-e", "production", "-b", "0.0.0.0", "-p", "7860"]
