require "test_helper"
require "cgi"

class AuthFlowTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "user can register confirm sign in view profile and sign out" do
    email = "flow.user@example.local"
    password = "password"

    assert_difference("User.count", 1) do
      post "/users", params: {
        user: {
          email: email,
          password: password,
          password_confirmation: password
        }
      }, as: :json
    end

    assert_response :success
    registration_body = json_response
    assert_equal email, registration_body.dig("user", "email")
    assert_match(/confirmation link has been sent/i, registration_body.fetch("message"))

    user = User.find_by!(email: email)
    assert_not user.confirmed?
    assert_equal 1, ActionMailer::Base.deliveries.size

    get "/users/confirmation", params: {
      confirmation_token: confirmation_token_from_last_email
    }

    assert_response :success
    user.reload
    assert user.confirmed?

    post "/users/sign_in", params: {
      user: {
        email: email,
        password: password
      }
    }, as: :json

    assert_response :created
    sign_in_body = json_response
    assert_equal email, sign_in_body.fetch("email")

    token = bearer_token_from_response
    assert token.present?
    payload, = JWT.decode(
      token,
      Warden::JWTAuth.config.secret,
      true,
      algorithm: Warden::JWTAuth.config.algorithm
    )
    assert_equal user.id.to_s, payload.fetch("sub")

    get "/user/profile", headers: authorization_headers(token), as: :json

    assert_response :success
    profile_body = json_response
    assert_equal email, profile_body.dig("user", "email")
    assert_equal token, profile_body.dig("token_info", "token")
    assert_equal user.id.to_s, profile_body.dig("token_info", "user_id")

    jti = profile_body.dig("token_info", "jti")
    assert jti.present?

    assert_difference("JwtDenylist.count", 1) do
      delete "/users/sign_out", headers: authorization_headers(token), as: :json
    end

    assert_response :ok
    sign_out_body = json_response
    assert_equal "Your account: #{email} has been signed out successfully", sign_out_body.fetch("message")
    assert_equal jti, payload.fetch("jti")
    assert JwtDenylist.exists?(jti: jti)
  end

  private

  def json_response
    JSON.parse(response.body)
  end

  def authorization_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def bearer_token_from_response
    response.headers.fetch("Authorization", "").delete_prefix("Bearer ")
  end

  def confirmation_token_from_last_email
    body = ActionMailer::Base.deliveries.last.body.encoded
    match = body.match(/confirmation_token=([^\"]+)/)

    assert_not_nil match, "Expected confirmation token in email body"

    CGI.unescape(match[1])
  end
end