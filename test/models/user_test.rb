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
      assert_equal false, user.send_confirmation_instructions
    end

    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end
end
