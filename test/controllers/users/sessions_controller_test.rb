# frozen_string_literal: true

require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("session_test@example.com", first_name: "Session", last_name: "Test")
  end

  test "login success with valid credentials" do
    post user_session_url, params: {
      user: { email: "session_test@example.com", password: "Password1!" }
    }, as: :json

    assert_response :success
    assert_equal "session_test@example.com", json_response.dig("user", "email")
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

  test "login failure triggers Warden::NotAuthenticated rescue" do
    warden_mock = Object.new
    warden_mock.define_singleton_method(:authenticate!) { |*| raise Warden::NotAuthenticated }

    Users::SessionsController.define_method(:warden) { warden_mock }

    post user_session_url, params: {
      user: { email: "any@example.com", password: "irrelevant" }
    }, as: :json

    assert_response :unauthorized
    assert_equal "Invalid email or password", json_response["errors"].first
  ensure
    Users::SessionsController.remove_method(:warden)
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
    assert_equal "No user is signed in", json_response["message"]
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
    assert_nil json_response["user"]
    assert_equal({ "token" => nil, "user_id" => nil, "expired" => true }, json_response["token_info"].slice("token", "user_id", "expired"))
  end
end
