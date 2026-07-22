# frozen_string_literal: true

require "test_helper"

class PasswordsControllerCoverageTest < ActionDispatch::IntegrationTest
  test "password reset create sends instructions" do
    user = User.create!(
      email: "reset@example.local",
      username: "reset_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )

    post user_password_path, params: {
      user: { email: user.email }
    }, as: :json
    assert_response :success
    body = json_response
    assert body.key?("message")
  end

  test "password update success" do
    user = User.create!(
      email: "pwupdate@example.local",
      username: "pwupdate_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )

    token = user.send_reset_password_instructions

    put user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "NewPassword1!",
        password_confirmation: "NewPassword1!"
      }
    }, as: :json
    assert_response :success
    body = json_response
    assert body.key?("message")
  end

  test "password update with mismatch returns errors" do
    user = User.create!(
      email: "pwupdate2@example.local",
      username: "pwupdate2_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )

    token = user.send_reset_password_instructions

    put user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "NewPassword1!",
        password_confirmation: "Different1!"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  end
end
