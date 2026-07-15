# frozen_string_literal: true

require "test_helper"

class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("password_test@example.com")
  end

  test "request password reset instructions" do
    post user_password_url, params: {
      user: { email: "password_test@example.com" }
    }, as: :json

    assert_response :success
    assert json_response["message"].present?
  end

  test "request password reset for non-existent email returns success (paranoid mode)" do
    post user_password_url, params: {
      user: { email: "nonexistent@example.com" }
    }, as: :json

    assert_response :ok
  end

  test "request password reset for non-existent email returns error (paranoid disabled)" do
    original = Devise.paranoid
    Devise.paranoid = false

    post user_password_url, params: {
      user: { email: "nonexistent@example.com" }
    }, as: :json

    assert_response :unprocessable_entity
    assert json_response["errors"].present?
  ensure
    Devise.paranoid = original
  end

  test "edit password gives API-only reset instructions without mutating the token" do
    token = "fixture-reset-token"

    get edit_user_password_url(reset_password_token: token)

    assert_response :ok
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "API-only"
    assert_includes response.body, "PUT"
    assert_includes response.body, "/users/password"
    assert_includes response.body, "reset_password_token"
    assert_includes response.body, "password_confirmation"
    assert_includes response.body, token
    assert_includes response.body, "curl"
    refute_includes response.body, "<form"
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "no-cache", response.headers.fetch("Pragma")
    assert_equal "no-referrer", response.headers.fetch("Referrer-Policy")
  end

  test "edit password requires a reset token" do
    get edit_user_password_url

    assert_response :unprocessable_entity
    assert_includes response.body, "reset_password_token is required"
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
    assert_not @user.reload.valid_password?("Password1!")
    assert @user.valid_password?("NewPassword1!")
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
    assert json_response["errors"].present?
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
