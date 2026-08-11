# frozen_string_literal: true

require_relative "../../lib/jwt_auth_header"

# Validates environment configuration at boot time (production only).
# Warnings appear in the application log immediately after startup, making
# misconfiguration visible before the first real request is served.
#
# To silence a warning intentionally, set the variable to a non-blank value
# or remove the check below once you have confirmed the default is acceptable.

return unless Rails.env.production?

warnings = []

# JWT signing key
# devise.rb falls back to secret_key_base when this is absent, which is safe
# but means the JWT key cannot be rotated independently of the master key.
unless ENV["DEVISE_JWT_SECRET_KEY"].present? ||
       Rails.application.credentials.devise_jwt_secret_key.present?
  warnings << "DEVISE_JWT_SECRET_KEY is not set in environment or credentials. " \
              "JWT tokens are being signed with secret_key_base. " \
              "Set DEVISE_JWT_SECRET_KEY for independent key rotation."
end

# Mailer sender
# config/initializers/devise.rb reads DEVISE_MAILER_SENDER and falls back to a
# placeholder (noreply@example.com) when it is unset. We flag the placeholder
# here so outbound emails never silently come from an example.com address.
if defined?(Devise) && Devise.mailer_sender.to_s.include?("example.com")
  warnings << "Devise.mailer_sender is using the placeholder address " \
              "(#{Devise.mailer_sender}) because DEVISE_MAILER_SENDER is unset. " \
              "Outbound emails (password resets, confirmations, etc.) would be " \
              "sent from this placeholder address. " \
              "Set the DEVISE_MAILER_SENDER environment variable to your real " \
              "sender address; no code change is required."
end

# JWT transport header
# The access JWT normally travels in the standard `Authorization` header. A
# provider that reserves that header (e.g. Beam.cloud) can move it to a custom
# one via JWT_AUTH_HEADER. Log the effective header name (never the token) so
# the transport is verifiable from the logs at boot.
jwt_auth_header = JwtAuthHeader.name
if jwt_auth_header != "Authorization"
  Rails.logger.info "[EnvironmentCheck] JWT authentication header is set to #{jwt_auth_header}."
end

warnings.each do |msg|
  Rails.logger.warn "[EnvironmentCheck] #{msg}"
end
