# frozen_string_literal: true

require "test_helper"

class PasswordResetInstructionsTest < ActiveSupport::TestCase
  test "builds a portable canonical API reset request" do
    token = "reset-token-_safe"
    instructions = PasswordResetInstructions.new(token)
    payload = JSON.parse(instructions.payload_json)

    assert_equal "http://example.com/users/password", instructions.endpoint_url
    assert_equal token, payload.dig("user", "reset_password_token")
    assert_equal "<NEW_PASSWORD>", payload.dig("user", "password")
    assert_equal "<NEW_PASSWORD>", payload.dig("user", "password_confirmation")
    refute payload.dig("user").key?("new_password")
    refute payload.dig("user").key?("new_password_confirmation")
    refute_includes instructions.plain_text, "/users/password/edit?reset_password_token="
  end
end
