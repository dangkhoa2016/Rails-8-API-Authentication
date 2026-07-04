# frozen_string_literal: true

require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("password_test@example.com", role: "user")
  end

  test "request password reset instructions" do
    post user_password_url, params: {
      user: { email: "password_test@example.com" }
    }, as: :json

    assert_response :success
    assert json_response["message"].present?
  end

  test "request password reset for non-existent email returns error" do
    post user_password_url, params: {
      user: { email: "nonexistent@example.com" }
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "update password with valid token" do
    raw_token = @user.send_reset_password_instructions
    @user.reload

    put user_password_url, params: {
      user: {
        reset_password_token: raw_token,
        password: "NewPassword1!",
        password_confirmation: "NewPassword1!"
      }
    }, as: :json

    assert_response :success
    assert json_response["message"].present?
  end

  test "update password with invalid token" do
    put user_password_url, params: {
      user: {
        reset_password_token: "invalid_token",
        password: "NewPassword1!",
        password_confirmation: "NewPassword1!"
      }
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "update password with mismatch confirmation" do
    raw_token = @user.send_reset_password_instructions
    @user.reload

    put user_password_url, params: {
      user: {
        reset_password_token: raw_token,
        password: "NewPassword1!",
        password_confirmation: "Different1!"
      }
    }, as: :json

    assert_response :unprocessable_entity
  end
end
