# frozen_string_literal: true

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

    assert_response :forbidden
    assert_equal(
      { "error" => "You must be an administrator to perform this action" },
      json_response
    )
  end

  test "non admin user cannot update another user" do
    owner = confirmed_user("owner@example.local")
    other = confirmed_user("other@example.local")
    sign_in owner

    put user_url(other), params: {
      user: { first_name: "Hacked" }
    }, as: :json

    assert_response :forbidden
  end

  test "non admin user can update own profile" do
    owner = confirmed_user("self_update@example.local")
    sign_in owner

    put user_url(owner), params: {
      user: { first_name: "Updated" }
    }, as: :json

    assert_response :success
    assert_equal "Updated", json_response["first_name"]
  end

  test "unconfirmed user cannot sign in" do
    user = User.create!(
      email: "pending@example.local",
      username: "pending_user",
      password: "Password1!",
      password_confirmation: "Password1!"
    )

    post "/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password1!"
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

    assert_response :unauthorized
    assert_equal({ "error" => "Invalid token" }, json_response)
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
    assert JwtDenylist.exists?(jti: payload.fetch("jti"))
  end
end
