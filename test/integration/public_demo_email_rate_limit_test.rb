# frozen_string_literal: true

require "test_helper"

class PublicDemoEmailRateLimitTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }.freeze

  setup do
    @previous_guard = ENV["PUBLIC_DEMO_EMAIL_GUARD"]
    ENV["PUBLIC_DEMO_EMAIL_GUARD"] = "true"
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  teardown do
    Rack::Attack.cache.store.clear
    @previous_guard.nil? ? ENV.delete("PUBLIC_DEMO_EMAIL_GUARD") : ENV["PUBLIC_DEMO_EMAIL_GUARD"] = @previous_guard
  end

  test "registration rejects an unsupported domain before creating a user" do
    assert_no_difference("User.count") do
      post "/users",
        params: {
          user: {
            email: "reviewer@example.com",
            username: "unsupported_reviewer",
            password: "Password1!",
            password_confirmation: "Password1!"
          }
        }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => "31.31.31.31" }
    end

    assert_response :unprocessable_entity
    assert json_response.fetch("errors").any? { |message| message.include?("supported public-demo provider") }
  end

  test "registration accepts a supported provider" do
    assert_difference("User.count", 1) do
      post "/users",
        params: {
          user: {
            email: "public-demo-#{SecureRandom.hex(4)}@gmail.com",
            username: "supported_#{SecureRandom.hex(4)}",
            password: "Password1!",
            password_confirmation: "Password1!"
          }
        }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => "32.32.32.32" }
    end

    assert_response :created
  end

  test "same recipient is limited to three explicit email requests per hour" do
    email = "nobody-#{SecureRandom.hex(4)}@gmail.com"

    3.times do |index|
      post "/users/password",
        params: { user: { email: email } }.to_json,
        headers: JSON_HEADERS,
        env: { "REMOTE_ADDR" => "33.33.33.#{index + 1}" }
      assert_not_equal 429, response.status
    end

    post "/users/password",
      params: { user: { email: email } }.to_json,
      headers: JSON_HEADERS,
      env: { "REMOTE_ADDR" => "33.33.33.99" }

    assert_response 429
    assert_equal "Too many requests. Please try again later.", json_response.fetch("error")
  end
end
