# frozen_string_literal: true

require "test_helper"

class Users::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "inherits from devise confirmations controller" do
    assert_equal Devise::ConfirmationsController, Users::ConfirmationsController.superclass
  end
end
