require "test_helper"

class AuthNegativeTest < ActionDispatch::IntegrationTest
  test "unauthenticated user cannot access users index" do
    get "/users", as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, json_response)
  end

  test "non admin user cannot access users index" do
    user = confirmed_user("member@example.local")
    sign_in user

    get "/users", as: :json

    assert_response :unauthorized
    assert_equal(
      { "error" => "You must be an administrator to perform this action" },
      json_response
    )
  end

  test "unconfirmed user cannot sign in" do
    user = User.create!(
      email: "pending@example.local",
      password: "password",
      password_confirmation: "password"
    )

    post "/users/sign_in", params: {
      user: {
        email: user.email,
        password: "password"
      }
    }, as: :json

    assert_response :unauthorized
    assert_equal(
      { "error" => "You have to confirm your email address before continuing." },
      json_response
    )
  end

  test "invalid token returns decode error" do
    get "/user/profile", headers: authorization_headers("not-a-jwt"), as: :json

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Invalid token" }, json_response)
  end

  test "expired token returns token metadata with expired flag" do
    user = confirmed_user("expired@example.local")
    token, payload = expired_token_for(user)

    get "/user/profile", headers: authorization_headers(token), as: :json

    assert_response :unprocessable_entity
    body = json_response
    assert_nil body["user"]
    assert_equal token, body.dig("token_info", "token")
    assert_equal payload["sub"], body.dig("token_info", "user_id")
    assert_equal payload["jti"], body.dig("token_info", "jti")
    assert_equal true, body.dig("token_info", "expired")
    assert_operator body.dig("token_info", "expired_in"), :<, 0
  end

  test "revoked token cannot be reused for profile access" do
    user = confirmed_user("revoked@example.local")
    headers = jwt_auth_headers_for(user)
    token = bearer_token_from_headers(headers)
    payload = decode_jwt(token)

    assert_difference("JwtDenylist.count", 1) do
      delete "/users/sign_out", headers: headers, as: :json
    end

    assert_response :ok

    get "/user/profile", headers: headers, as: :json

    assert_response :unprocessable_entity
    body = json_response
    assert_nil body["user"]
    assert_equal token, body.dig("token_info", "token")
    assert_equal payload.fetch("jti"), body.dig("token_info", "jti")
    assert_equal false, body.dig("token_info", "expired")
    assert JwtDenylist.exists?(jti: payload.fetch("jti"))
  end
end
