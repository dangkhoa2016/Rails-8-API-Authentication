# frozen_string_literal: true

require "test_helper"

class Users::UnlocksControllerTest < ActionDispatch::IntegrationTest
  test "inherits from devise unlocks controller" do
    assert_equal Devise::UnlocksController, Users::UnlocksController.superclass
  end
end
