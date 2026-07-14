# frozen_string_literal: true

require "test_helper"

class PasswordResetInstructionsMailerTest < ActionMailer::TestCase
  test "reset email contains API instructions in text and HTML without a reset link" do
    user = confirmed_user("password-reset-mailer@example.com")
    token = user.send_reset_password_instructions
    email = ActionMailer::Base.deliveries.last

    assert_not_nil email

    [ email.text_part.body.decoded, email.html_part.body.decoded ].each do |body|
      assert_includes body, token
      assert_includes body, "PUT"
      assert_includes body, "/users/password"
      assert_includes body, "reset_password_token"
      assert_includes body, "password_confirmation"
      assert_includes body, "curl"
      refute_includes body, "/users/password/edit?reset_password_token="
      refute_includes body, "Change my password"
    end
  end
end
