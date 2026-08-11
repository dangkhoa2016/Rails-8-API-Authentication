# frozen_string_literal: true

require "test_helper"

class JwtAuthHeaderTest < ActiveSupport::TestCase
  test "defaults to Authorization when unset" do
    with_jwt_auth_header(nil) do
      assert_equal "Authorization", JwtAuthHeader.name
    end
  end

  test "returns the configured header" do
    with_jwt_auth_header("X-Authorization") do
      assert_equal "X-Authorization", JwtAuthHeader.name
    end
  end

  test "falls back to Authorization for blank or whitespace-only values" do
    [ "", "   ", "\t" ].each do |value|
      with_jwt_auth_header(value) do
        assert_equal "Authorization", JwtAuthHeader.name
      end
    end
  end

  test "rejects malformed header names" do
    [ "bad header", "header\r\nInjected", "header\nInjected", "émojis" ].each do |value|
      with_jwt_auth_header(value) do
        error = assert_raises(ArgumentError) { JwtAuthHeader.name }
        assert_match(/not a valid HTTP header name/, error.message)
      end
    end
  end

  private

  def with_jwt_auth_header(value, &block)
    original = ENV["JWT_AUTH_HEADER"]
    value.nil? ? ENV.delete("JWT_AUTH_HEADER") : ENV["JWT_AUTH_HEADER"] = value
    block.call
  ensure
    original.nil? ? ENV.delete("JWT_AUTH_HEADER") : ENV["JWT_AUTH_HEADER"] = original
  end
end
