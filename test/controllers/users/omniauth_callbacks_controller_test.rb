# frozen_string_literal: true

require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  test "inherits from devise omniauth callbacks controller" do
    assert_equal Devise::OmniauthCallbacksController, Users::OmniauthCallbacksController.superclass
  end
end
