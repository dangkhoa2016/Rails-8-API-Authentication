require "test_helper"

# Tests for Rack::Attack rate limiting on auth endpoints.
#
# Strategy:
# - Rack::Attack is enabled globally; the safelist excludes 127.0.0.1 / ::1
#   (the default IP for ActionDispatch::Integration tests).
# - We spoof distinct remote IP addresses using the REMOTE_ADDR env key so
#   each test exercises a unique IP that is not in the localhost safelist.
# - The cache is reset in setup so counter state does not bleed between tests.
class RateLimitTest < ActionDispatch::IntegrationTest
  THROTTLE_IP      = "1.2.3.4"
  OTHER_IP         = "5.6.7.8"
  JSON_HEADERS     = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }.freeze
  SIGN_IN_PATH     = "/users/sign_in"
  REGISTRATION_PATH = "/users"
  PASSWORD_PATH    = "/users/password"

  setup do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  teardown do
    Rack::Attack.cache.store.clear
  end

  # ── Sign-in / IP throttle ─────────────────────────────────────────────────

  test "sign in allows up to 5 requests per IP per 60s then throttles" do
    payload = { user: { email: "any@example.local", password: "wrong" } }.to_json

    5.times do
      post SIGN_IN_PATH,
        params: payload,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => THROTTLE_IP }
      assert_not_equal 429, response.status, "Expected request to pass but got 429 on attempt #{_1 + 1}"
    end

    post SIGN_IN_PATH,
      params: payload,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => THROTTLE_IP }

    assert_response 429
    body = json_response
    assert_equal "Too many requests. Please try again later.", body.fetch("error")
    assert response.headers.key?("Retry-After"), "Expected Retry-After header"
  end

  test "sign in throttle is per IP - different IP is not affected" do
    payload = { user: { email: "any@example.local", password: "wrong" } }.to_json

    5.times do
      post SIGN_IN_PATH,
        params: payload,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => THROTTLE_IP }
    end

    # A completely different IP must still be allowed
    post SIGN_IN_PATH,
      params: payload,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => OTHER_IP }

    assert_not_equal 429, response.status
  end

  # ── Sign-in / email throttle ──────────────────────────────────────────────

  test "sign in throttles 10 attempts per email across different IPs" do
    email = "victim@example.local"

    # Use 10 distinct IPs (each IP gets its own IP-throttle counter).
    10.times do |i|
      ip = "10.0.0.#{i + 1}"
      post SIGN_IN_PATH,
        params: { user: { email: email, password: "wrong" } }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => ip }
      assert_not_equal 429, response.status,
        "Expected request to pass but got 429 on attempt #{i + 1} from IP #{ip}"
    end

    post SIGN_IN_PATH,
      params: { user: { email: email, password: "wrong" } }.to_json,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => "10.0.0.99" }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end

  # ── Registration throttle ─────────────────────────────────────────────────

  test "registration allows up to 10 requests per IP per hour then throttles" do
    10.times do |i|
      post REGISTRATION_PATH,
        params: { user: {
          email: "reg#{i}@example.local",
          password: "password",
          password_confirmation: "password"
        } }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => THROTTLE_IP }
      assert_not_equal 429, response.status,
        "Expected request to pass but got 429 on attempt #{i + 1}"
    end

    post REGISTRATION_PATH,
      params: { user: {
        email: "reg_overflow@example.local",
        password: "password",
        password_confirmation: "password"
      } }.to_json,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => THROTTLE_IP }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end

  # ── Password reset throttle ───────────────────────────────────────────────

  test "password reset allows up to 5 requests per IP per hour then throttles" do
    5.times do |i|
      post PASSWORD_PATH,
        params: { user: { email: "user#{i}@example.local" } }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => THROTTLE_IP }
      assert_not_equal 429, response.status,
        "Expected request to pass but got 429 on attempt #{i + 1}"
    end

    post PASSWORD_PATH,
      params: { user: { email: "overflow@example.local" } }.to_json,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => THROTTLE_IP }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end

  # ── Health check is never throttled ──────────────────────────────────────

  test "health check endpoint is never rate limited" do
    20.times do
      get "/up", env: { "REMOTE_ADDR" => THROTTLE_IP }
      assert_not_equal 429, response.status
    end
  end
end
