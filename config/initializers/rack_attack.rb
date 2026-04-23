# frozen_string_literal: true

# Rack::Attack – rate limiting for auth endpoints.
#
# Limits are intentionally conservative. All throttles key on req.ip unless
# noted; change to a trusted-proxy-aware IP extractor if the app is deployed
# behind a load balancer that sets X-Forwarded-For.
#
# In test mode we swap in a MemoryStore so counters actually increment
# (the test environment uses null_store by default, which discards writes).

if Rails.env.test?
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

class Rack::Attack
  # ── Safelists ──────────────────────────────────────────────────────────────

  # Never throttle the health check endpoint.
  safelist("allow health check") do |req|
    req.path == "/up"
  end

  # Never throttle requests from localhost (development / CI smoke runs).
  safelist("allow localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # ── Throttles ──────────────────────────────────────────────────────────────

  # Sign-in: 5 attempts per 60 s per IP.
  # Defends against distributed brute-force campaigns.
  throttle("sign_in/ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # Sign-in: 10 attempts per 60 s per email address.
  # Defends against slow credential-stuffing directed at one account.
  throttle("sign_in/email", limit: 10, period: 60) do |req|
    if req.path == "/users/sign_in" && req.post?
      # Rack::Attack does not parse JSON bodies by default.
      # We read and parse here without mutating the env so the body remains
      # available to downstream middleware.
      body = req.env["rack.input"].read
      req.env["rack.input"].rewind
      email = JSON.parse(body).dig("user", "email").to_s.downcase.presence rescue nil
      email
    end
  end

  # Registration: 10 sign-ups per hour per IP.
  # Defends against account-creation spam.
  throttle("registration/ip", limit: 10, period: 3600) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  # Password reset: 5 requests per hour per IP.
  # Defends against email-enumeration and reset-link flooding.
  throttle("password_reset/ip", limit: 5, period: 3600) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # ── Throttled response ─────────────────────────────────────────────────────

  # Return a JSON body consistent with the app's error contract:
  # { "error": "..." }  (singular key, same as ApplicationController error handlers)
  #
  # rack-attack 6.x passes a Rack::Attack::Request object to throttled_responder,
  # not a raw Rack env Hash — access the env via req.env.
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    headers = {
      "Content-Type" => "application/json",
      "Retry-After"  => retry_after.to_s
    }
    body = { error: "Too many requests. Please try again later." }.to_json
    [ 429, headers, [ body ] ]
  end
end
