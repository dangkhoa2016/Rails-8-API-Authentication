require "test_helper"

class UserControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    sign_in @user

    @user_test = users(:one)
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
end
