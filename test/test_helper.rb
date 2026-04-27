if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-console"
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Console
  ])

  SimpleCov.start "rails" do
    coverage_dir "public/coverage"
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"
  end
end

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
    parallelize(workers: :number_of_processors) unless ENV["COVERAGE"]

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
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

  def jwt_auth_headers_for(user, headers = json_headers)
    Devise::JWT::TestHelpers.auth_headers(headers, user)
  end

  def bearer_token_from_headers(headers)
    headers.fetch("Authorization").delete_prefix("Bearer ")
  end

  def bearer_token_from_response
    response.headers.fetch("Authorization", "").delete_prefix("Bearer ")
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

  def confirmed_user(email, password: "password", **attributes)
    attributes[:username] ||= email.split("@").first.gsub(/[^\w]/, "_") + "_#{SecureRandom.hex(4)}"
    User.create!(
      {
        email: email,
        password: password,
        password_confirmation: password,
        confirmed_at: Time.current
      }.merge(attributes)
    )
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
