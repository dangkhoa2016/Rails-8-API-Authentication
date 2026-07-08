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
        password: "Password1!" }
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
      user: { email: "user1@example.local", username: "dup_user", password: "Password1!" }
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

  # --- Unauthenticated access ---

  test "unauthenticated user cannot access users index" do
    sign_out @user
    get users_url, as: :json
    assert_response :unauthorized
  end

  test "unauthenticated user cannot create user" do
    sign_out @user
    post users_create_url, params: {
      user: { email: "new@user.local", username: "new_user", password: "Password1!" }
    }, as: :json
    assert_response :unauthorized
  end

  test "unauthenticated user cannot toggle status" do
    sign_out @user
    put "/users/#{@user_test.id}/status", params: { user: { active: false } }, as: :json
    assert_response :unauthorized
  end

  test "unauthenticated user cannot confirm by admin" do
    sign_out @user
    put "/users/#{@user_test.id}/confirm_by_admin", as: :json
    assert_response :unauthorized
  end

  # --- Non-admin access to existing actions ---

  test "non-admin cannot create user" do
    sign_out @user
    regular = confirmed_user("reg_create@example.local", role: "user",
                            confirmed_at: Time.current)
    sign_in regular

    post users_create_url, params: {
      user: { email: "new@user.local", username: "new_user", password: "Password1!" }
    }, as: :json
    assert_response :unauthorized
  end

  test "non-admin cannot show another user" do
    sign_out @user
    regular = confirmed_user("reg_show@example.local", role: "user",
                            confirmed_at: Time.current)
    sign_in regular

    get user_url(@user_test), as: :json
    assert_response :unauthorized
  end

  test "non-admin cannot update another user" do
    sign_out @user
    regular = confirmed_user("reg_update@example.local", role: "user",
                            confirmed_at: Time.current)
    sign_in regular

    put user_url(@user_test), params: { user: { first_name: "Hacked" } }, as: :json
    assert_response :unauthorized
  end

  # --- Admin permitted params ---

  test "admin can create user with role" do
    post users_create_url, params: {
      user: {
        email: "admin_created@example.local",
        username: "admin_created",
        password: "Password1!",
        role: "admin"
      }
    }, as: :json

    assert_response :created
    assert_equal "admin", User.find_by(email: "admin_created@example.local").role
  end

  test "admin can update user active status via update endpoint" do
    put user_url(@user_test), params: { user: { active: false } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  # --- toggle_status ---

  test "admin can deactivate a user" do
    put "/users/#{@user_test.id}/status", params: { user: { active: false } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "admin can reactivate a user" do
    @user_test.update!(active: false)
    put "/users/#{@user_test.id}/status", params: { user: { active: true } }, as: :json
    assert_response :success
    @user_test.reload
    assert @user_test.active
  end

  test "non-admin cannot toggle status" do
    sign_out @user
    regular = confirmed_user("reg_toggle@example.local", role: "user",
                            confirmed_at: Time.current)
    sign_in regular

    put "/users/#{@user_test.id}/status", params: { user: { active: false } }, as: :json
    assert_response :unauthorized
  end

  test "toggle_status returns not found for missing numeric id" do
    put "/users/999999/status", params: { user: { active: false } }, as: :json
    assert_response :not_found
  end

  test "toggle_status finds user by email" do
    put "/users/#{@user_test.email}/status", params: { user: { active: false } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "toggle_status returns not found for unknown email" do
    put "/users/unknown@example.com/status", params: { user: { active: false } }, as: :json
    assert_response :not_found
  end

  test "toggle_status finds user by username" do
    put "/users/#{@user_test.username}/status", params: { user: { active: false } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "toggle_status returns not found for unknown username" do
    put "/users/nonexistent_user/status", params: { user: { active: false } }, as: :json
    assert_response :not_found
  end

  # --- parse_boolean smart parsing ---

  test "toggle_status accepts string 'yes'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "yes" } }, as: :json
    assert_response :success
    @user_test.reload
    assert @user_test.active
  end

  test "toggle_status accepts string 'y'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "y" } }, as: :json
    assert_response :success
    @user_test.reload
    assert @user_test.active
  end

  test "toggle_status accepts string 't'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "t" } }, as: :json
    assert_response :success
    @user_test.reload
    assert @user_test.active
  end

  test "toggle_status accepts string '1'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "1" } }, as: :json
    assert_response :success
    @user_test.reload
    assert @user_test.active
  end

  test "toggle_status accepts string 'no'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "no" } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "toggle_status accepts string 'n'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "n" } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "toggle_status accepts string 'f'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "f" } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "toggle_status accepts string '0'" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "0" } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  test "toggle_status rejects invalid string" do
    put "/users/#{@user_test.id}/status", params: { user: { active: "invalid" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "toggle_status accepts boolean true" do
    put "/users/#{@user_test.id}/status", params: { user: { active: true } }, as: :json
    assert_response :success
    @user_test.reload
    assert @user_test.active
  end

  test "toggle_status accepts boolean false" do
    put "/users/#{@user_test.id}/status", params: { user: { active: false } }, as: :json
    assert_response :success
    @user_test.reload
    assert_not @user_test.active
  end

  # --- confirm_by_admin ---

  test "admin can confirm a user" do
    target = confirmed_user("confirm_target@example.local", role: "user",
                           confirmed_at: nil)

    put "/users/#{target.id}/confirm_by_admin", as: :json
    assert_response :success
    target.reload
    assert_not_nil target.confirmed_at
    assert target.active
  end

  test "non-admin cannot confirm a user" do
    sign_out @user
    regular = confirmed_user("reg_confirm@example.local", role: "user",
                            confirmed_at: Time.current)
    sign_in regular

    put "/users/#{@user_test.id}/confirm_by_admin", as: :json
    assert_response :unauthorized
  end

  test "confirm_by_admin returns not found for missing user" do
    put "/users/999999/confirm_by_admin", as: :json
    assert_response :not_found
  end

  test "confirm_by_admin finds user by email" do
    target = confirmed_user("confirm_email@example.local", role: "user",
                           confirmed_at: nil)

    put "/users/#{target.email}/confirm_by_admin", as: :json
    assert_response :success
    target.reload
    assert_not_nil target.confirmed_at
  end

  test "confirm_by_admin finds user by username" do
    target = confirmed_user("confirm_user@example.local", role: "user",
                           confirmed_at: nil)

    put "/users/#{target.username}/confirm_by_admin", as: :json
    assert_response :success
    target.reload
    assert_not_nil target.confirmed_at
  end

  # --- Error handling branches ---

  test "destroy handles failure" do
    user = User.find(@user_test.id)
    user.define_singleton_method(:destroy) { false }
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |id| user }

    delete user_url(@user_test), as: :json
    assert_response :unprocessable_entity
  ensure
    User.singleton_class.define_method(:find, original_find)
  end

  test "toggle_status handles update failure" do
    user = User.find(@user_test.id)
    user.define_singleton_method(:update) { |**| false }
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |id| user }

    put "/users/#{@user_test.id}/status", params: { user: { active: false } }, as: :json
    assert_response :unprocessable_entity
  ensure
    User.singleton_class.define_method(:find, original_find)
  end

  test "confirm_by_admin handles update failure" do
    user = User.find(@user_test.id)
    user.define_singleton_method(:update) do |**|
      errors.add(:base, "Update failed")
      false
    end
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |id| user }

    put "/users/#{@user_test.id}/confirm_by_admin", as: :json
    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Update failed"
  ensure
    User.singleton_class.define_method(:find, original_find)
  end

  # --- Non-admin self-update/show ---

  test "non-admin user can view own profile" do
    sign_out @user
    user = confirmed_user("self_view@example.com", role: "user",
                          first_name: "Self", last_name: "View",
                          confirmed_at: Time.current)
    sign_in user

    get user_url(user), as: :json
    assert_response :success
    assert_equal user.id, json_response["id"]
  end

  test "non-admin user can update own profile" do
    sign_out @user
    user = confirmed_user("self_update@example.com", role: "user",
                          first_name: "Self", last_name: "Update",
                          confirmed_at: Time.current)
    sign_in user

    put user_url(user), params: { user: { first_name: "Updated" } }, as: :json
    assert_response :success
    assert_equal "Updated", json_response["first_name"]
  end

  test "non-admin user cannot view other user profile" do
    sign_out @user
    user1 = confirmed_user("user1_access@example.com", role: "user",
                           first_name: "User1", last_name: "Access",
                           confirmed_at: Time.current)
    user2 = confirmed_user("user2_access@example.com", role: "user",
                           first_name: "User2", last_name: "Access",
                           confirmed_at: Time.current)
    sign_in user1

    get user_url(user2), as: :json
    assert_response :unauthorized
  end

  # --- Invalid create params ---

  test "admin cannot create user with short password" do
    assert_no_difference("User.count") do
      post users_create_url, params: {
        user: { email: "short@test.com", password: "123", password_confirmation: "123" }
      }, as: :json
    end
    assert_response :unprocessable_entity
    assert json_response["errors"].any? { |e| e.downcase.include?("password") }
  end

  test "admin cannot create user with invalid email" do
    assert_no_difference("User.count") do
      post users_create_url, params: {
        user: { email: "not-an-email", password: "password123", password_confirmation: "password123" }
      }, as: :json
    end
    assert_response :unprocessable_entity
  end

  # --- find_user edge cases ---

  test "find_user returns not found for non-existent numeric ID" do
    put "/users/999999/status", params: { user: { active: false } }, as: :json
    assert_response :not_found
    assert_equal "Record not found", json_response["error"]
  end

  test "find_user returns not found for non-existent email" do
    put "/users/nonexistent@example.com/status", params: { user: { active: false } }, as: :json
    assert_response :not_found
    assert_equal "Record not found", json_response["error"]
  end

  test "find_user returns not found for non-existent username" do
    put "/users/nonexistentuser/status", params: { user: { active: false } }, as: :json
    assert_response :not_found
    assert_equal "Record not found", json_response["error"]
  end

  test "find_user finds user by email" do
    put "/users/#{@user_test.email}/status", params: { user: { active: false } }, as: :json
    assert_response :success
    assert_equal @user_test.id, json_response["id"]
  end

  test "find_user finds user by username" do
    put "/users/#{@user_test.username}/status", params: { user: { active: false } }, as: :json
    assert_response :success
    assert_equal @user_test.id, json_response["id"]
  end
end
