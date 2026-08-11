# frozen_string_literal: true

require_relative "../../lib/jwt_auth_header"

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", nil)
if allowed_origins.nil? && Rails.env.production?
  raise "CORS_ALLOWED_ORIGINS environment variable is not set"
end

allowed_origins = (allowed_origins || "http://localhost:4000").split(",").map(&:strip).reject(&:empty?)

jwt_auth_header = JwtAuthHeader.name

# Explicitly allow the standard and legacy Beam headers as well as the
# configured one, so existing browser tooling and mixed environments keep
# working while arbitrary configured values are also accepted.
allowed_headers = %w[
  Content-Type
  Authorization
  X-Authorization
  X-Refresh-Token
  X-Requested-With
  Accept
  Origin
]
allowed_headers << jwt_auth_header
allowed_headers.uniq!

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins allowed_origins

    resource "*",
      headers: allowed_headers,
      expose: [ jwt_auth_header ],
      methods: [ :get, :post, :put, :patch, :delete, :options ]
  end
end
