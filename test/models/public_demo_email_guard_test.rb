# frozen_string_literal: true

require "test_helper"

class PublicDemoEmailGuardTest < ActiveSupport::TestCase
  def with_public_demo_guard(value = "true")
    previous = ENV["PUBLIC_DEMO_EMAIL_GUARD"]
    ENV["PUBLIC_DEMO_EMAIL_GUARD"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("PUBLIC_DEMO_EMAIL_GUARD") : ENV["PUBLIC_DEMO_EMAIL_GUARD"] = previous
  end

  def build_user(email)
    User.new(
      email: email,
      username: "guard_#{SecureRandom.hex(4)}",
      password: "Password1!",
      password_confirmation: "Password1!"
    )
  end

  test "supported public-demo email remains valid" do
    with_public_demo_guard do
      user = build_user("reviewer@gmail.com")
      assert user.valid?, user.errors.full_messages.join(", ")
    end
  end

  test "unsupported public-demo email is rejected before persistence" do
    with_public_demo_guard do
      user = build_user("reviewer@example.com")
      assert_not user.valid?
      assert user.errors[:email].any? { |message| message.include?("supported public-demo provider") }
    end
  end

  test "ordinary deployments are not restricted when guard is disabled" do
    with_public_demo_guard("false") do
      user = build_user("reviewer@example.com")
      assert user.valid?, user.errors.full_messages.join(", ")
    end
  end

  test "devise notification is blocked for unsupported legacy recipient" do
    with_public_demo_guard do
      user = users(:one)
      mailer_called = false
      mailer = Object.new
      mailer.define_singleton_method(:send) do |*_args|
        mailer_called = true
        raise "mailer should not be called"
      end

      user.stub(:devise_mailer, mailer) do
        assert_equal false, user.send_devise_notification(:reset_password_instructions)
      end

      assert_not mailer_called
    end
  end
end
