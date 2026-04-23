require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should not save user without email" do
    user = User.new
    assert_not user.save, "Saved the user without an email"
  end

  test "should not save user without password" do
    user = User.new
    user.email = "test@local.test"
    assert_not user.save, "Saved the user without a password"
  end

  test "user_count" do
    assert_equal 3, User.count
  end

  test "find one" do
    assert_equal "user2@example.local", users(:two).email
  end

  # --- Email format validation ---

  test "should not save user with invalid email format" do
    user = User.new(email: "not-an-email", password: "password", password_confirmation: "password")
    assert_not user.save, "Saved user with invalid email"
  end

  test "should not save user with duplicate email" do
    user = User.new(email: "user1@example.local", password: "password", password_confirmation: "password")
    assert_not user.save, "Saved user with duplicate email"
  end

  # --- Role enum ---

  test "default role is user" do
    user = User.new(email: "role@example.local", password: "password", password_confirmation: "password")
    assert_equal "user", user.role
  end

  test "role can be set to admin" do
    user = users(:admin)
    assert user.admin?, "Expected admin user to return true for admin?"
    assert_not user.user?, "Expected admin user to return false for user?"
  end

  test "role can be set to user" do
    user = users(:one)
    assert user.user?, "Expected regular user to return true for user?"
    assert_not user.admin?, "Expected regular user to return false for admin?"
  end

  # --- Lockable ---

  test "user is locked after maximum failed attempts" do
    user = users(:one)
    assert_not user.access_locked?, "User should not be locked initially"

    Devise.maximum_attempts.times do
      user.increment_failed_attempts
    end
    user.lock_access!

    assert user.access_locked?, "User should be locked after max failed attempts"
  end

  test "user can be unlocked" do
    user = users(:one)
    user.lock_access!
    assert user.access_locked?

    user.unlock_access!
    assert_not user.access_locked?
  end

  # --- Username uniqueness ---

  test "should not save user with duplicate username" do
    user = User.new(
      email: "unique@example.local",
      username: "user1",  # already taken by fixture :one
      password: "password",
      password_confirmation: "password"
    )
    assert_not user.save, "Saved user with duplicate username"
    assert_includes user.errors[:username], "has already been taken"
  end
end
