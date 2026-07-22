# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "cgi"
require "devise"
require "devise/jwt/test_helpers"
require "securerandom"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def confirmed_user(email, password: "Password1!", **attributes)
      base = email.split("@").first.gsub(/[^w]/, "_")
      suffix = "_#{SecureRandom.hex(2)}"
      max_base = 25 - suffix.length
      attributes[:username] ||= base.length > max_base ? base[0, max_base] + suffix : base + suffix
      User.create!(
        {
          email: email,
          password: password,
          password_confirmation: password,
          confirmed_at: Time.current
        }.merge(attributes)
      )
    end

    def jwt_auth_headers_for(user, headers = nil)
      headers ||= { "Accept" => "application/json", "Content-Type" => "application/json" }
      Devise::JWT::TestHelpers.auth_headers(headers, user)
    end

    def decode_jwt(token)
      payload, = JWT.decode(
        token,
        Warden::JWTAuth.config.secret,
        true,
        algorithm: Warden::JWTAuth.config.algorithm
      )

      payload
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def json_response
    JSON.parse(response.body)
  end

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end

  def authorization_headers(token)
    json_headers.merge("Authorization" => "Bearer #{token}")
  end

  def bearer_token_from_headers(headers)
    headers.fetch("Authorization").delete_prefix("Bearer ")
  end

  def bearer_token_from_response
    response.headers.fetch("Authorization", "").delete_prefix("Bearer ")
  end

  def expired_token_for(user, issued_at: 2.hours.ago, expired_at: 1.hour.ago)
    payload = {
      "sub" => user.id.to_s,
      "scp" => "user",
      "aud" => nil,
      "iat" => issued_at.to_i,
      "exp" => expired_at.to_i,
      "jti" => SecureRandom.uuid
    }

    token = JWT.encode(payload, Warden::JWTAuth.config.secret, Warden::JWTAuth.config.algorithm)

    [ token, payload ]
  end

  def confirmation_token_from_last_email
    body = ActionMailer::Base.deliveries.last.body.encoded
    match = body.match(/confirmation_token=([^\"]+)/)

    assert_not_nil match, "Expected confirmation token in email body"

    CGI.unescape(match[1])
  end
end
