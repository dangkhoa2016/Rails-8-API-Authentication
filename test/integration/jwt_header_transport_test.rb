# frozen_string_literal: true

require "test_helper"

class JwtHeaderTransportTest < ActionDispatch::IntegrationTest
  setup do
    @user = confirmed_user("jwt-transport@example.local")
  end

  test "configured token header is applied to Warden and Devise config" do
    expected = JwtAuthHeader.name

    assert_equal expected, Devise::JWT.config.token_header
    assert_equal expected, Warden::JWTAuth.config.token_header
  end

  test "valid JWT through the configured header returns 200 on /user/me" do
    headers = jwt_auth_headers_for(@user)

    get "/user/me", headers: headers, as: :json

    assert_response :ok
    assert_equal @user.id, json_response.dig("user", "id")
    assert_equal @user.id.to_s, json_response.dig("token_info", "user_id").to_s
  end

  test "token is placed in the configured header as Bearer" do
    configured_header = Warden::JWTAuth.config.token_header
    headers = jwt_auth_headers_for(@user)

    assert headers.key?(configured_header)
    assert_match(/\ABearer\s+\S+\z/, headers.fetch(configured_header))
  end

  test "alternate header does not authenticate the local app" do
    configured_header = Warden::JWTAuth.config.token_header
    alternate_header = configured_header == "Authorization" ? "X-Authorization" : "Authorization"

    token = bearer_token_from_headers(jwt_auth_headers_for(@user))

    get "/user/me", headers: json_headers.merge(alternate_header => "Bearer #{token}"), as: :json

    assert_response :unprocessable_entity
    assert_nil json_response["user"]
  end

  test "invalid JWT through the configured header is rejected" do
    get "/user/me", headers: authorization_headers("invalid-token"), as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Invalid token" }, json_response)
  end

  test "sign in dispatches the token in the configured response header" do
    post "/users/sign_in", params: {
      user: { email: @user.email, password: "Password1!" }
    }, as: :json

    assert_response :ok

    configured_header = Warden::JWTAuth.config.token_header
    header_token = response.headers.fetch(configured_header).delete_prefix("Bearer ")
    body_token = json_response.fetch("token")

    assert_equal body_token, header_token
  end

  test "refresh returns an access token usable through the configured header" do
    raw_refresh_token, = RefreshToken.generate_for(@user)

    post "/users/tokens/refresh", headers: { "X-Refresh-Token" => raw_refresh_token }, as: :json

    assert_response :ok
    access_token = json_response.fetch("access_token")

    get "/user/me", headers: authorization_headers(access_token), as: :json

    assert_response :ok
    assert_equal @user.id, json_response.dig("user", "id")
  end
end
