# frozen_string_literal: true

require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("session_test@example.com", role: "user",
                           first_name: "Session", last_name: "Test")
  end

  test "login success with valid credentials" do
    post user_session_url, params: {
      user: { email: "session_test@example.com", password: "Password1!" }
    }, as: :json

    assert_response :success
  end

  test "login failure with invalid password" do
    post user_session_url, params: {
      user: { email: "session_test@example.com", password: "wrongpassword" }
    }, as: :json

    assert_response :unauthorized
  end

  test "login failure with non-existent email" do
    post user_session_url, params: {
      user: { email: "nonexistent@example.com", password: "Password1!" }
    }, as: :json

    assert_response :unauthorized
  end

  test "logout success" do
    sign_in @user
    delete destroy_user_session_url, as: :json

    assert_response :success
    assert json_response["message"].present?
  end

  test "logout when not signed in" do
    delete destroy_user_session_url, as: :json

    assert_response :unprocessable_entity
  end

  test "show profile when authenticated" do
    sign_in @user
    get user_profile_url, as: :json

    assert_response :success
    assert json_response["user"].present?
    assert json_response["token_info"].present?
  end

  test "show profile when not authenticated" do
    get user_profile_url, as: :json

    assert_response :unprocessable_entity
  end
end
