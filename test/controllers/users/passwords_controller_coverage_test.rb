# frozen_string_literal: true

require "test_helper"

class PasswordsControllerCoverageTest < ActionDispatch::IntegrationTest
  test "passwords create returns errors when not successfully sent" do
    original_paranoid = Devise.paranoid
    Devise.paranoid = false

    post user_password_path, params: {
      user: { email: "nonexistent@example.local" }
    }, as: :json

    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  ensure
    Devise.paranoid = original_paranoid
  end
end
