# frozen_string_literal: true

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
    user = User.new(email: "not-an-email", username: "invalid_email_user", password: "Password1!", password_confirmation: "Password1!")
    assert_not user.save, "Saved user with invalid email"
  end

  test "should not save user with duplicate email" do
    user = User.new(email: "user1@example.local", username: "duplicate_email_user", password: "Password1!", password_confirmation: "Password1!")
    assert_not user.save, "Saved user with duplicate email"
  end

  # --- Role enum ---

  test "default role is user" do
    user = User.new(email: "role@example.local", username: "role_user", password: "Password1!", password_confirmation: "Password1!")
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
      password: "Password1!",
      password_confirmation: "Password1!"
    )
    assert_not user.save, "Saved user with duplicate username"
    assert_includes user.errors[:username], "has already been taken"
  end

  test "blank username is normalized to nil" do
    user = User.new(
      email: "blank-username@example.local",
      username: "   ",
      password: "Password1!",
      password_confirmation: "Password1!"
    )

    assert user.save
    assert_nil user.reload.username
  end

  test "serializable hash includes unconfirmed email when present" do
    user = User.new(
      email: "reconfirm@example.local",
      username: "reconfirm_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      unconfirmed_email: "pending@example.local"
    )

    assert_equal "pending@example.local", user.serializable_hash[:unconfirmed_email]
  end

  # --- find_for_database_authentication ---

  test "finds user by email" do
    user = User.find_for_database_authentication(email: "user1@example.local")
    assert_equal users(:one), user
  end

  test "finds user by username" do
    user = User.find_for_database_authentication(email: "user1")
    assert_equal users(:one), user
  end

  test "finds user by username when no email matches" do
    user = User.find_for_database_authentication(email: "admin_user")
    assert_equal users(:admin), user
  end

  test "returns nil for nonexistent email or username" do
    assert_nil User.find_for_database_authentication(email: "nonexistent@example.com")
    assert_nil User.find_for_database_authentication(email: "completely_unknown")
  end

  test "returns nil for blank login" do
    assert_nil User.find_for_database_authentication(email: "")
    assert_nil User.find_for_database_authentication(email: nil)
  end

  # --- active_for_authentication? ---

  test "active user is active for authentication" do
    assert users(:admin).active_for_authentication?
  end

  test "inactive user is not active for authentication" do
    user = users(:admin)
    user.update!(active: false)
    assert_not user.active_for_authentication?
  end

  test "inactive message for active user delegates to super" do
    assert_equal :inactive, users(:admin).inactive_message
  end

  test "inactive message for deactivated user" do
    user = users(:admin)
    user.update!(active: false)
    assert_equal :account_inactive, user.inactive_message
  end

  test "active defaults to true for new users" do
    user = User.new(
      email: "active-default@example.local",
      username: "active_default_user",
      password: "Password1!",
      password_confirmation: "Password1!"
    )
    assert user.active?
  end

  test "send confirmation instructions logs and swallows delivery errors" do
    user = User.create!(
      email: "delivery-error@example.local",
      username: "delivery_error_user",
      password: "Password1!",
      password_confirmation: "Password1!"
    )

    logger = Class.new {
      attr_reader :messages

      def initialize
        @messages = []
      end

      def error(message)
        @messages << message
        nil
      end
    }.new

    user.define_singleton_method(:send_devise_notification) do |*_args|
      raise Net::SMTPFatalError, "mailer exploded"
    end

    Rails.stub(:logger, logger) do
      assert_nil user.send_confirmation_instructions
    end

    assert_includes logger.messages, "Failed to send confirmation instructions to delivery-error@example.local: Net::SMTPFatalError - mailer exploded"
  end
end
