# frozen_string_literal: true

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
        password: "Password1!",
        password_confirmation: "Password1!" }
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

  test "should return unprocessable entity when creating user with duplicate email" do
    existing = users(:one)

    post users_create_url, params: {
      user: {
        email: existing.email,
        username: "new_username",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert json_response["errors"].present?
  end

  test "should return unprocessable entity when updating user with duplicate username" do
    other = users(:two)

    put user_url(@user_test), params: {
      user: { username: other.username }
    }, as: :json

    assert_response :unprocessable_entity
    assert json_response["errors"].present?
  end

  test "should return not found for missing user" do
    get user_url(999_999), as: :json

    assert_response :not_found
    assert_equal({ "errors" => "User not found" }, json_response)
  end

  test "find user by email param" do
    user = users(:one)
    controller = TestUsersController.new
    controller.params = ActionController::Parameters.new(email: user.email)

    controller.send(:find_user)

    assert_equal user, controller.instance_variable_get(:@user)
  end

  test "destroy failure renders errors when destroy returns false" do
    user = confirmed_user("destroy_fail_controller@example.com")
    user.define_singleton_method(:destroy) do
      errors.add(:base, "cannot delete")
      false
    end

    controller = TestUsersController.new
    controller.instance_variable_set(:@user, user)

    controller.destroy

    assert_equal :unprocessable_entity, controller.rendered_status
    assert_includes controller.rendered_json[:errors], "cannot delete"
  end
end

class TestUsersController < UsersController
  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json = json
    @rendered_status = status
  end
end
