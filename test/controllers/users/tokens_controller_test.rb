# frozen_string_literal: true

require "test_helper"

class Users::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("tokens_test@example.com", first_name: "Tokens", last_name: "Test")
  end

  test "refresh rotates the token and returns a new access token" do
    raw_token, original_record = RefreshToken.generate_for(@user)

    post users_tokens_refresh_url, params: { refresh_token: raw_token }, as: :json

    assert_response :ok
    body = json_response
    assert_equal @user.email, body.dig("user", "email")
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_not_equal raw_token, body["refresh_token"]

    original_record.reload
    assert original_record.revoked?

    new_record = RefreshToken.find_by_raw_token(body["refresh_token"])
    assert new_record.present?
    assert_equal original_record.family_id, new_record.family_id
  end

  test "refresh accepts the refresh token via header" do
    raw_token, = RefreshToken.generate_for(@user)

    post users_tokens_refresh_url, headers: { "X-Refresh-Token" => raw_token }, as: :json

    assert_response :ok
    assert json_response["access_token"].present?
  end

  test "refresh accepts the refresh token via HttpOnly cookie" do
    post user_session_url, params: {
      user: { email: "tokens_test@example.com", password: "Password1!" }
    }, as: :json

    assert_response :ok
    assert cookies["refresh_token"].present?

    post users_tokens_refresh_url, as: :json

    assert_response :ok
    assert json_response["access_token"].present?
  end

  test "refresh returns unauthorized when token is missing" do
    post users_tokens_refresh_url, as: :json

    assert_response :unauthorized
    assert_equal "Refresh token is missing", json_response["error"]
  end

  test "refresh returns unauthorized for an unknown token" do
    post users_tokens_refresh_url, params: { refresh_token: "unknown-token" }, as: :json

    assert_response :unauthorized
    assert_equal "Invalid refresh token", json_response["error"]
  end

  test "refresh detects reuse and revokes the whole family" do
    raw_token, record = RefreshToken.generate_for(@user)
    sibling_raw, sibling = RefreshToken.generate_for(@user, family_id: record.family_id)
    record.revoke!

    post users_tokens_refresh_url, params: { refresh_token: raw_token }, as: :json

    assert_response :unauthorized
    assert_match(/reuse detected/i, json_response["error"])
    assert RefreshToken.find(sibling.id).revoked?
    assert_not RefreshToken.find_by_raw_token(sibling_raw).active?
  end

  test "refresh returns unauthorized for an expired token" do
    raw_token, record = RefreshToken.generate_for(@user)
    record.update!(expires_at: 1.hour.ago)

    post users_tokens_refresh_url, params: { refresh_token: raw_token }, as: :json

    assert_response :unauthorized
    assert_equal "Refresh token has expired", json_response["error"]
    assert RefreshToken.find(record.id).revoked?
  end

  test "refresh returns unauthorized when the user account is inactive" do
    @user.update!(active: false)
    raw_token, record = RefreshToken.generate_for(@user)

    post users_tokens_refresh_url, params: { refresh_token: raw_token }, as: :json

    assert_response :unauthorized
    assert_equal "User account is inactive", json_response["error"]
    assert RefreshToken.find(record.id).revoked?
  end

  test "sign in sets the refresh token cookie" do
    post user_session_url, params: {
      user: { email: "tokens_test@example.com", password: "Password1!" }
    }, as: :json

    assert_response :ok
    assert cookies["refresh_token"].present?
    assert_equal 1, RefreshToken.count
  end

  test "sign out revokes the refresh token" do
    raw_token, record = RefreshToken.generate_for(@user)
    sign_in @user

    delete destroy_user_session_url, params: { refresh_token: raw_token }, as: :json

    assert_response :ok
    assert RefreshToken.find(record.id).revoked?
  end

  test "sign out accepts the refresh token via header" do
    raw_token, record = RefreshToken.generate_for(@user)
    sign_in @user

    delete destroy_user_session_url, headers: { "X-Refresh-Token" => raw_token }, as: :json

    assert_response :ok
    assert record.reload.revoked?
  end
end
