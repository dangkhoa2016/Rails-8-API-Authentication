require "test_helper"

class AccountManagementTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "registration returns validation errors for duplicate email" do
    existing_user = confirmed_user("duplicate-registration@example.local")

    assert_no_difference("User.count") do
      post "/users", params: {
        user: {
          email: existing_user.email,
          username: "different_username",
          password: "password",
          password_confirmation: "password"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Email has already been taken"
  end

  test "registration returns validation errors for duplicate username" do
    existing_user = confirmed_user("duplicate-username@example.local", username: "duplicate_username")

    post "/users", params: {
      user: {
        email: "another-user@example.local",
        username: existing_user.username,
        password: "password",
        password_confirmation: "password"
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Username has already been taken"
  end

  test "registration without username returns validation errors" do
    assert_no_difference("User.count") do
      post "/users", params: {
        user: {
          email: "blank-username@example.local",
          password: "password",
          password_confirmation: "password"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Username can't be blank"
  end

  test "signed in user can update account with current password" do
    user = confirmed_user("account-update@example.local", username: "account_update_user")
    sign_in user

    put "/users", params: {
      user: {
        first_name: "Updated",
        current_password: "password"
      }
    }, as: :json

    assert_response :ok
    assert_equal "Your account has been updated successfully.", json_response.fetch("message")
    assert_equal "Updated", json_response.dig("user", "first_name")
    assert_equal "Updated", user.reload.first_name
  end

  test "signed in user sees validation errors when current password is missing" do
    user = confirmed_user("account-update-missing-password@example.local", username: "account_update_missing_password")
    sign_in user

    put "/users", params: {
      user: {
        first_name: "Updated"
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Current password can't be blank"
  end

  test "signed in user can cancel account" do
    user = confirmed_user("account-destroy@example.local", username: "account_destroy_user")
    sign_in user

    assert_difference("User.count", -1) do
      delete "/users", as: :json
    end

    assert_response :ok
    assert_equal(
      "Bye! Your account has been successfully cancelled. We hope to see you again soon.",
      json_response.fetch("message")
    )
    assert_equal user.email, json_response.dig("user", "email")
  end

  test "signed in user sees destroy errors when account cancellation is aborted" do
    user = confirmed_user("account-destroy-blocked@example.local", username: "account_destroy_blocked")
    sign_in user

    with_destroy_abort_for(user.email, "Cannot delete account") do
      assert_no_difference("User.count") do
        delete "/users", as: :json
      end
    end

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Cannot delete account"
    assert User.exists?(user.id)
  end

  test "sign out returns not signed in message without an authenticated user" do
    delete "/users/sign_out", as: :json

    assert_response :unprocessable_entity
    assert_equal({ "message" => "No user is signed in" }, json_response)
  end

  test "user can reset password with valid token" do
    user = confirmed_user("password-reset@example.local", username: "password_reset_user")
    token = user.send_reset_password_instructions

    put "/users/password", params: {
      user: {
        reset_password_token: token,
        password: "newpassword",
        password_confirmation: "newpassword"
      }
    }, as: :json

    assert_response :ok
    assert_match(/password has been changed successfully/i, json_response.fetch("message"))
    assert user.reload.valid_password?("newpassword")
  end

  test "user sees password reset errors with invalid token" do
    user = confirmed_user("password-reset-invalid@example.local", username: "password_reset_invalid_user")

    put "/users/password", params: {
      user: {
        reset_password_token: "invalid-token",
        password: "newpassword",
        password_confirmation: "newpassword"
      }
    }, as: :json

    assert_response :unprocessable_entity
    assert_includes json_response.fetch("errors"), "Reset password token is invalid"
    assert user.reload.valid_password?("password")
  end

  private

  def with_destroy_abort_for(email, message)
    callback = lambda do |record|
      if record.email == email
        record.errors.add(:base, message)
        throw :abort
      end
    end

    User.set_callback(:destroy, :before, callback)
    yield
  ensure
    User.skip_callback(:destroy, :before, callback)
  end
end