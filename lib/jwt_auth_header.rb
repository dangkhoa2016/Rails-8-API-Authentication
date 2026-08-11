# frozen_string_literal: true

# Single source of truth for the HTTP header that transports the access JWT.
#
# Used by both the Devise JWT strategy (config/initializers/devise.rb) and the
# CORS initializer (config/initializers/cors.rb) so that a provider that
# reserves the standard `Authorization` header (e.g. Beam.cloud) only needs to
# set `JWT_AUTH_HEADER` once.
module JwtAuthHeader
  DEFAULT = "Authorization"

  # Conservative HTTP token-name charset (RFC 7230 `token`), which rejects
  # CR/LF injection, empty values, and other malformed header names.
  HEADER_NAME_PATTERN = /\A[A-Za-z0-9!#$%&'*+\-.^_`|~]+\z/

  module_function

  # Returns the configured JWT transport header, falling back to the standard
  # `Authorization` header when `JWT_AUTH_HEADER` is unset, blank, or made up
  # of whitespace only. Raises when the value is not a valid header name.
  def name
    raw = ENV.fetch("JWT_AUTH_HEADER", DEFAULT).to_s.strip
    return DEFAULT if raw.empty?

    unless raw.match?(HEADER_NAME_PATTERN)
      raise ArgumentError,
        "JWT_AUTH_HEADER #{raw.inspect} is not a valid HTTP header name"
    end

    raw
  end
end
