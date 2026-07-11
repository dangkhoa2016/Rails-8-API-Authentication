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
    assert_equal 2, User.count
  end

  test "find one" do
    assert_equal "user2@example.local", users(:two).email
  end
  # ---------------------------------------------------------------------------
  # send_devise_notification — new method added to rescue mail delivery errors
  # ---------------------------------------------------------------------------

  # Helper: stubs Rails.logger and the devise_mailer, raises a given error,
  # then returns { logger:, result: }.
  def stub_notification_error(user, notification, error_class, error_message = "error")
    logger = Minitest::Mock.new
    logger.expect(:error, nil) { |msg| msg.include?(error_class.to_s.split(":").last) || true }

    mailer_double = Object.new
    mailer_double.define_singleton_method(:send) { |*_a| raise error_class, error_message }

    result = nil
    Rails.stub(:logger, logger) do
      user.stub(:devise_mailer, mailer_double) do
        result = user.send_devise_notification(notification)
      end
    end

    { logger: logger, result: result }
  end

  # --- send_devise_notification: happy path ---

  test "send_devise_notification delivers the notification successfully" do
    user = users(:one)
    delivered = []
    mailer_double = Object.new
    mailer_double.define_singleton_method(:send) do |*_args|
      msg = Object.new
      msg.define_singleton_method(:deliver_now) { delivered << true }
      msg
    end

    user.stub(:devise_mailer, mailer_double) do
      user.send_devise_notification(:confirmation_instructions, "token", {})
    end

    assert_equal 1, delivered.size
  end

  # --- send_devise_notification: rescues each error class ---

  [
    [ Net::SMTPFatalError,   "SMTP error" ],
    [ Net::OpenTimeout,      "open timeout" ],
    [ Net::ReadTimeout,      "read timeout" ],
    [ Errno::ECONNREFUSED,   "connection refused" ],
    [ Errno::ECONNRESET,     "connection reset" ],
    [ SocketError,           "socket error" ]
  ].each do |error_class, label|
    test "send_devise_notification rescues #{label} and returns false" do
      user = users(:one)
      out = stub_notification_error(user, :some_notification, error_class)
      assert_equal false, out[:result], "Expected false when #{label} is raised"
    end
  end

  # --- send_devise_notification: adds error only for :confirmation_instructions ---

  test "send_devise_notification adds base error when notification is :confirmation_instructions" do
    user = users(:one)
    stub_notification_error(user, :confirmation_instructions, Errno::ECONNREFUSED)
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") },
           "Expected a base error for confirmation_instructions notification"
  end

  test "send_devise_notification does NOT add base error for other notifications" do
    user = users(:one)
    stub_notification_error(user, :reset_password_instructions, Errno::ECONNREFUSED)
    assert_empty user.errors[:base],
                 "Expected no base error for reset_password_instructions notification"
  end

  test "send_devise_notification logs the notification name and email" do
    user = users(:one)
    logged_messages = []

    fake_logger = Object.new
    fake_logger.define_singleton_method(:error) { |msg| logged_messages << msg }

    mailer_double = Object.new
    mailer_double.define_singleton_method(:send) { |*_a| raise Errno::ECONNREFUSED, "refused" }

    Rails.stub(:logger, fake_logger) do
      user.stub(:devise_mailer, mailer_double) do
        user.send_devise_notification(:password_change)
      end
    end

    assert logged_messages.any? { |m| m.include?(user.email) },
           "Expected log to include user email"
    assert logged_messages.any? { |m| m.include?("ECONNREFUSED") },
           "Expected log to include error class name"
  end

  # ---------------------------------------------------------------------------
  # send_confirmation_instructions — extended rescue (ECONNREFUSED/ECONNRESET/SocketError)
  # ---------------------------------------------------------------------------

  # Helper: raise inside super (send_devise_notification), capture result
  def stub_confirmation_error(user, error_class)
    logged = []
    fake_logger = Object.new
    fake_logger.define_singleton_method(:error) { |m| logged << m }

    result = nil
    Rails.stub(:logger, fake_logger) do
      user.stub(:send_devise_notification, ->(*_a) { raise error_class, "err" }) do
        result = user.send_confirmation_instructions
      end
    end

    { result: result, logged: logged }
  end

  test "send_confirmation_instructions rescues Errno::ECONNREFUSED" do
    user = users(:one)
    out = stub_confirmation_error(user, Errno::ECONNREFUSED)
    assert_equal false, out[:result]
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end

  test "send_confirmation_instructions rescues Errno::ECONNRESET" do
    user = users(:one)
    out = stub_confirmation_error(user, Errno::ECONNRESET)
    assert_equal false, out[:result]
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end

  test "send_confirmation_instructions rescues SocketError" do
    user = users(:one)
    out = stub_confirmation_error(user, SocketError)
    assert_equal false, out[:result]
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end

  test "send_confirmation_instructions rescues Net::SMTPFatalError" do
    user = users(:one)
    out = stub_confirmation_error(user, Net::SMTPFatalError)
    assert_equal false, out[:result]
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end

  test "send_confirmation_instructions rescues Net::OpenTimeout" do
    user = users(:one)
    out = stub_confirmation_error(user, Net::OpenTimeout)
    assert_equal false, out[:result]
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end

  test "send_confirmation_instructions rescues Net::ReadTimeout" do
    user = users(:one)
    out = stub_confirmation_error(user, Net::ReadTimeout)
    assert_equal false, out[:result]
    assert user.errors[:base].any? { |e| e.include?("Could not send confirmation email") }
  end

  test "send_confirmation_instructions logs error with user email" do
    user = users(:one)
    out = stub_confirmation_error(user, Errno::ECONNREFUSED)
    assert out[:logged].any? { |m| m.include?(user.email) },
           "Expected log to include user email"
  end
end
