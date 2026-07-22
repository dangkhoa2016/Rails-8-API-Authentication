# frozen_string_literal: true

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
    body = json_response
    assert body.key?("users")
    assert body.key?("meta")
    meta = body["meta"]
    assert_equal 1, meta["current_page"]
    assert_equal 20, meta["per_page"]
    assert meta["total_count"] > 0
    assert meta["total_pages"] > 0
  end

  test "index supports custom per_page" do
    get users_url(per_page: 2), as: :json
    assert_response :success
    body = json_response
    assert_equal 2, body["meta"]["per_page"]
    assert body["users"].length <= 2
  end

  test "index caps per_page at 100" do
    get users_url(per_page: 999), as: :json
    assert_response :success
    body = json_response
    assert_equal 100, body["meta"]["per_page"]
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

  test "should return record not found for missing user" do
    get user_url(999_999), as: :json

    assert_response :not_found
    assert_equal({ "error" => "Record not found" }, JSON.parse(@response.body))
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
    assert_response :forbidden
  end

  test "non-admin cannot destroy another user" do
    sign_out @user
    regular = confirmed_user("regular2@example.local", role: "user",
                             first_name: "Regular", last_name: "User",
                             confirmed_at: Time.current)
    sign_in regular

    delete user_url(@user_test), as: :json
    assert_response :forbidden
  end

  # --- Duplicate email registration ---

  test "cannot create user with duplicate email" do
    post users_create_url, params: {
      user: { email: "user1@example.local", username: "dup_user", password: "Password1!",
      password_confirmation: "Password1!" }
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
        password: "Password1!",
        password_confirmation: "different"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert_not_nil json_response["errors"]
  end

  # --- Error handling branches ---

  test "destroy handles failure" do
    user = User.find(@user_test.id)
    user.define_singleton_method(:destroy) { false }
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |*args| user }

    delete user_url(@user_test), as: :json
    assert_response :unprocessable_entity
  ensure
    User.singleton_class.define_method(:find, original_find)
  end

  # --- Update failure path ---

  test "update returns errors on validation failure" do
    put user_url(@user_test), params: {
      user: { username: @user.username }
    }, as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  end

  # --- Create failure path ---

  test "create renders errors on validation failure" do
    post users_create_url, params: {
      user: {
        email: "user1@example.local",
        username: "dup_create_user",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  end

  # --- self-demotion guard ---

  test "admin cannot demote themselves" do
    put user_url(@user), params: {
      user: { role: "user" }
    }, as: :json
    assert_response :forbidden
    assert_equal "Cannot demote yourself", json_response["error"]
  end

  # --- non-admin password update ---

  test "non-admin cannot update password with wrong current password" do
    regular = confirmed_user("wrong-pw@example.local", role: "user",
                             first_name: "Wrong", last_name: "Pw",
                             confirmed_at: Time.current)
    sign_out @user
    sign_in regular

    put user_url(regular), params: {
      user: {
        password: "NewPassword1!",
        password_confirmation: "NewPassword1!",
        current_password: "WrongPassword1!"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert_equal "Current password is incorrect", json_response["error"]
  end

  test "non-admin can update password with correct current password" do
    regular = confirmed_user("pw-update@example.local", role: "user",
                             first_name: "Pw", last_name: "Update",
                             confirmed_at: Time.current)
    sign_out @user
    sign_in regular

    put user_url(regular), params: {
      user: {
        password: "NewPassword1!",
        password_confirmation: "NewPassword1!",
        current_password: "Password1!"
      }
    }, as: :json
    assert_response :success
  end

  # --- toggle_status ---

  test "toggle_status activates user" do
    @user_test.update!(active: false)
    put "/users/#{@user_test.id}/status", params: {
      user: { active: true }
    }, as: :json
    assert_response :success
    assert @user_test.reload.active?
  end

  test "toggle_status deactivates user" do
    @user_test.update!(active: true)
    put "/users/#{@user_test.id}/status", params: {
      user: { active: false }
    }, as: :json
    assert_response :success
    assert_not @user_test.reload.active?
  end

  test "toggle_status rejects nil boolean value" do
    put "/users/#{@user_test.id}/status", params: {
      user: { active: "maybe" }
    }, as: :json
    assert_response :unprocessable_entity
    assert_equal "active must be a boolean", json_response["error"]
  end

  test "toggle_status handles update failure" do
    user = User.find(@user_test.id)
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |*_args| user }
    user.define_singleton_method(:update) { |_opts| false }

    put "/users/#{@user_test.id}/status", params: {
      user: { active: true }
    }, as: :json
    assert_response :unprocessable_entity
  ensure
    User.singleton_class.define_method(:find, original_find)
  end

  test "toggle_status accepts string true values" do
    @user_test.update!(active: false)
    put "/users/#{@user_test.id}/status", params: {
      user: { active: "yes" }
    }, as: :json
    assert_response :success
    assert @user_test.reload.active?
  end

  test "toggle_status accepts string false values" do
    @user_test.update!(active: true)
    put "/users/#{@user_test.id}/status", params: {
      user: { active: "no" }
    }, as: :json
    assert_response :success
    assert_not @user_test.reload.active?
  end

  test "toggle_status accepts numeric 1 as true" do
    @user_test.update!(active: false)
    put "/users/#{@user_test.id}/status", params: {
      user: { active: "1" }
    }, as: :json
    assert_response :success
    assert @user_test.reload.active?
  end

  test "toggle_status accepts numeric 0 as false" do
    @user_test.update!(active: true)
    put "/users/#{@user_test.id}/status", params: {
      user: { active: "0" }
    }, as: :json
    assert_response :success
    assert_not @user_test.reload.active?
  end

  # --- confirm_by_admin ---

  test "confirm_by_admin confirms and activates user" do
    @user_test.update!(confirmed_at: nil, active: false)
    put "/users/#{@user_test.id}/confirm_by_admin", as: :json
    assert_response :success
    @user_test.reload
    assert_not_nil @user_test.confirmed_at
    assert @user_test.active?
  end

  test "confirm_by_admin handles update failure" do
    user = User.find(@user_test.id)
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |*_args| user }
    user.define_singleton_method(:update) { |_opts| false }

    put "/users/#{@user_test.id}/confirm_by_admin", as: :json
    assert_response :unprocessable_entity
  ensure
    User.singleton_class.define_method(:find, original_find)
  end

  # --- find_user by email ---

  test "find_user resolves by email in path" do
    put "/users/#{@user_test.email}/status", params: {
      user: { active: true }
    }, as: :json
    assert_response :success
  end

  # --- find_user by username ---

  test "find_user resolves by username in path" do
    put "/users/#{@user_test.username}/status", params: {
      user: { active: true }
    }, as: :json
    assert_response :success
  end
end
