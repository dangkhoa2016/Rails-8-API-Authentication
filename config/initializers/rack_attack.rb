# frozen_string_literal: true

require Rails.root.join("lib/rack_attack_cache_store")

# Rack::Attack – rate limiting for auth endpoints.
#
# Limits are intentionally conservative. All throttles key on req.ip unless
# noted; change to a trusted-proxy-aware IP extractor if the app is deployed
# behind a load balancer that sets X-Forwarded-For.
#
# Rack::Attack uses the Rails cache by default. Tests always use a MemoryStore
# so counters actually increment; deployments may explicitly request the same
# process-local store with RACK_ATTACK_CACHE_STORE=memory when their topology
# guarantees a single application process/container.

Rack::Attack.cache.store = RackAttackCacheStore.resolve(
  environment: Rails.env.to_s,
  requested: ENV["RACK_ATTACK_CACHE_STORE"],
  default_store: Rails.cache
)

class Rack::Attack
  # ── Safelists ──────────────────────────────────────────────────────────────

  # Never throttle the health check endpoint.
  safelist("allow health check") do |req|
    req.path == "/up"
  end

  # Never throttle requests from localhost (development / test / CI smoke runs).
  # The API test suites boot the server with RAILS_ENV=production
  # (scripts/test_ruby_versions.sh), so opt in via RACK_ATTACK_SAFELIST_LOCALHOST
  # to keep localhost unthrottled for CI smoke runs without weakening real
  # production deployments (which set no such flag).
  if Rails.env.development? || Rails.env.test? || ENV["RACK_ATTACK_SAFELIST_LOCALHOST"] == "true"
    safelist("allow localhost") do |req|
      req.ip == "127.0.0.1" || req.ip == "::1"
    end
  end

  # ── Throttles ──────────────────────────────────────────────────────────────

  # Global emergency ceiling: 300 requests per 60 s per IP across ordinary
  # application routes. /up remains safelisted above for health probes.
  throttle("api/ip", limit: 300, period: 60) do |req|
    req.ip unless req.path == "/up"
  end

  # Refresh-token rotation is unauthenticated and performs database work.
  throttle("refresh_token/ip", limit: 20, period: 60) do |req|
    req.ip if req.path == "/users/tokens/refresh" && req.post?
  end

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
      body = req.env["rack.input"].read(4096) || ""
      req.env["rack.input"].rewind
      email = begin
        JSON.parse(body).dig("user", "email").to_s.downcase.presence
      rescue JSON::ParserError
        nil
      end
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
