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
    user = User.new(email: "not-an-email", username: "invalid_email_user", password: "password", password_confirmation: "password")
    assert_not user.save, "Saved user with invalid email"
  end

  test "should not save user with duplicate email" do
    user = User.new(email: "user1@example.local", username: "duplicate_email_user", password: "password", password_confirmation: "password")
    assert_not user.save, "Saved user with duplicate email"
  end

  # --- Role enum ---

  test "default role is user" do
    user = User.new(email: "role@example.local", username: "role_user", password: "password", password_confirmation: "password")
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

  test "blank username is rejected" do
    user = User.new(
      email: "blank-username@example.local",
      username: "   ",
      password: "password",
      password_confirmation: "password"
    )

    assert_not user.save
    assert_includes user.errors[:username], "can't be blank"
  end

  test "serializable hash includes unconfirmed email when present" do
    user = User.new(
      email: "reconfirm@example.local",
      username: "reconfirm_user",
      password: "password",
      password_confirmation: "password",
      unconfirmed_email: "pending@example.local"
    )

    assert_equal "pending@example.local", user.serializable_hash[:unconfirmed_email]
  end

  test "send confirmation instructions logs and swallows delivery errors" do
    user = User.create!(
      email: "delivery-error@example.local",
      username: "delivery_error_user",
      password: "password",
      password_confirmation: "password"
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
      raise StandardError, "mailer exploded"
    end

    original_logger = Rails.logger
    Rails.singleton_class.send(:define_method, :logger) { logger }

    begin
      assert_nil user.send_confirmation_instructions
    ensure
      Rails.singleton_class.send(:define_method, :logger) { original_logger }
    end

    assert_includes logger.messages, "Error sending confirmation instructions: mailer exploded"
  end
end
