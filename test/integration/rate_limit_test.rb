# frozen_string_literal: true

require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }.freeze
  SIGN_IN_PATH = "/users/sign_in"
  REGISTRATION_PATH = "/users"
  PASSWORD_PATH = "/users/password"

  setup do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  teardown do
    Rack::Attack.cache.store.clear
  end

  test "sign in allows up to 5 requests per IP per 60s then throttles" do
    discriminator = "signin-ip-#{SecureRandom.hex(4)}"
    ip = "1.1.1.#{(rand * 200).to_i + 1}"
    payload = { user: { email: "any-#{discriminator}@example.local", password: "wrong" } }.to_json

    5.times do
      post SIGN_IN_PATH, params: payload, headers: JSON_HEADERS, env: { "REMOTE_ADDR" => ip }
      assert_not_equal 429, response.status, "Expected request to pass but got 429 on attempt #{_1 + 1}"
    end

    post SIGN_IN_PATH, params: payload, headers: JSON_HEADERS, env: { "REMOTE_ADDR" => ip }
    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
    assert response.headers.key?("Retry-After")
  end

  test "sign in throttle is per IP - different IP is not affected" do
    discriminator = "signin-perip-#{SecureRandom.hex(4)}"
    throttle_ip = "2.2.2.#{(rand * 200).to_i + 1}"
    other_ip = "3.3.3.#{(rand * 200).to_i + 1}"
    payload = { user: { email: "any-#{discriminator}@example.local", password: "wrong" } }.to_json

    5.times do
      post SIGN_IN_PATH, params: payload, headers: JSON_HEADERS, env: { "REMOTE_ADDR" => throttle_ip }
    end

    post SIGN_IN_PATH, params: payload, headers: JSON_HEADERS, env: { "REMOTE_ADDR" => other_ip }
    assert_not_equal 429, response.status
  end

  test "sign in throttles 10 attempts per email across different IPs" do
    discriminator = "email-#{SecureRandom.hex(4)}"
    email = "victim-#{discriminator}@example.local"

    10.times do |i|
      ip = "10.10.10.#{i + 1}"
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
      env: { "REMOTE_ADDR" => "10.10.10.99" }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end

  test "registration allows up to 10 requests per IP per hour then throttles" do
    discriminator = "reg-#{SecureRandom.hex(4)}"
    ip = "4.4.4.#{(rand * 200).to_i + 1}"

    10.times do |i|
      post REGISTRATION_PATH,
        params: { user: {
          email: "reg-#{i}-#{discriminator}@example.local",
          username: "reg-user-#{i}-#{discriminator}",
          password: "Password1!",
          password_confirmation: "Password1!"
        } }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => ip }
      assert_not_equal 429, response.status,
        "Expected request to pass but got 429 on attempt #{i + 1}"
    end

    post REGISTRATION_PATH,
      params: { user: {
        email: "reg-overflow-#{discriminator}@example.local",
        username: "reg-overflow-#{discriminator}",
        password: "Password1!",
        password_confirmation: "Password1!"
      } }.to_json,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => ip }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end

  test "password reset allows up to 5 requests per IP per hour then throttles" do
    discriminator = "pwd-#{SecureRandom.hex(4)}"
    ip = "5.5.5.#{(rand * 200).to_i + 1}"

    5.times do |i|
      post PASSWORD_PATH,
        params: { user: { email: "user-#{i}-#{discriminator}@example.local" } }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => ip }
      assert_not_equal 429, response.status,
        "Expected request to pass but got 429 on attempt #{i + 1}"
    end

    post PASSWORD_PATH,
      params: { user: { email: "overflow-#{discriminator}@example.local" } }.to_json,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => ip }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end

  test "health check endpoint is never rate limited" do
    ip = "6.6.6.#{(rand * 200).to_i + 1}"
    20.times do
      get "/up", env: { "REMOTE_ADDR" => ip }
      assert_not_equal 429, response.status
    end
  end
end
