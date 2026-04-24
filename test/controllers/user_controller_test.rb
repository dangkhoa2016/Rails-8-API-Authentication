require "test_helper"

class UserControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    sign_in @user

    @user_test = users(:one)
    @other_user = users(:two)
  end

  test "should get index" do
    get users_url, as: :json
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      post users_create_url, params: {
        user: {
        email: "new@user.local",
        username: "new_user",
        password: "password" }
      }, as: :json
    end
  end

  test "should return parameter missing when creating user without payload" do
    post users_create_url, params: {}, as: :json

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Parameter missing" }, JSON.parse(@response.body))
  end

  test "should show user" do
    get user_url(@user_test), as: :json
    assert_response :success
    assert_equal @user_test.email, "user1@example.local"
    assert_equal @user_test.username, "user1"
    assert_equal @user_test.first_name, "User"
    assert_equal @user_test.role, "user"
  end

  test "should return record not found for missing user" do
    get user_url(999_999), as: :json

    assert_response :not_found
    assert_equal({ "error" => "Record not found" }, json_response)
  end

  test "should update user" do
    put user_url(@user_test), params: {
      user: {
        email: "user_1@example.local",
        username: "user_1",
        first_name: "User 1",
        role: "admin"
      }
    }, as: :json

    assert_response :success
    @user_test.reload
    assert_equal @user_test.email, "user1@example.local"
    assert_equal @user_test.unconfirmed_email, "user_1@example.local"
    assert_equal @user_test.username, "user_1"
    assert_equal @user_test.first_name, "User 1"
    assert_equal @user_test.role, "admin"
  end

  test "should return validation errors when update is invalid" do
    put user_url(@user_test), params: {
      user: {
        username: @other_user.username
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Username has already been taken"
  end

  test "should destroy user" do
    assert_difference("User.count", -1) do
      delete user_url(@user_test), as: :json
    end
  end

  test "should destroy current logged in user" do
    assert_difference("User.count", -1) do
      delete user_url(@user), as: :json
    end
  end

  # --- Non-admin access rejection ---

  test "non-admin cannot access users index" do
    sign_out @user
    regular = confirmed_user("regular@example.local", role: "user",
                             first_name: "Regular", last_name: "User",
                             confirmed_at: Time.current)
    sign_in regular

    get users_url, as: :json
    assert_response :unauthorized
  end

  test "non-admin cannot destroy another user" do
    sign_out @user
    regular = confirmed_user("regular2@example.local", role: "user",
                             first_name: "Regular", last_name: "User",
                             confirmed_at: Time.current)
    sign_in regular

    delete user_url(@user_test), as: :json
    assert_response :unauthorized
  end

  # --- Duplicate email registration ---

  test "cannot create user with duplicate email" do
    post users_create_url, params: {
      user: { email: "user1@example.local", username: "dup_user", password: "password" }
    }, as: :json
    assert_response :unprocessable_entity
    assert_not_nil json_response["errors"]
  end

  # --- Password confirmation mismatch ---

  test "cannot create user when password confirmation does not match" do
    post users_create_url, params: {
      user: {
        email: "mismatch@example.local",
        username: "mismatch_user",
        password: "password",
        password_confirmation: "different"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert_not_nil json_response["errors"]
  end
end
