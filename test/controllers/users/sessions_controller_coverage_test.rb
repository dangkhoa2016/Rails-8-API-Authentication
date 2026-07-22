# frozen_string_literal: true

require "test_helper"

class SessionsControllerCoverageTest < ActionDispatch::IntegrationTest
  test "show returns user profile when signed in" do
    user = confirmed_user("profile@example.local", role: "user",
                          first_name: "Profile", last_name: "User",
                          confirmed_at: Time.current)
    sign_in user

    get "/user/profile", as: :json
    assert_response :success
    body = json_response
    assert body.key?("user")
    assert body.key?("token_info")
  end

  test "show returns error when not signed in" do
    get "/user/profile", as: :json
    assert_response :unprocessable_entity
    body = json_response
    assert_nil body["user"]
  end

  test "destroy returns error when not signed in" do
    delete "/users/sign_out", as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("message")
  end
end
