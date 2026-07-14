# frozen_string_literal: true

require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup success with valid params" do
    assert_difference("User.count", 1) do
      post user_registration_url, params: {
        user: {
          email: "newuser@example.com",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }, as: :json
    end

    assert_response :created
    assert json_response["message"].present?
    assert_equal "newuser@example.com", json_response["user"]["email"]
  end

  test "signup failure with duplicate email" do
    confirmed_user("existing@example.com")

    assert_no_difference("User.count") do
      post user_registration_url, params: {
        user: {
          email: "existing@example.com",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert json_response["errors"].any? { |e| e.downcase.include?("email") }
  end

  test "signup failure with password missing complexity" do
    assert_no_difference("User.count") do
      post user_registration_url, params: {
        user: {
          email: "weak@example.com",
          password: "alllowercase",
          password_confirmation: "alllowercase"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert json_response["errors"].any? { |e| e.downcase.include?("password") }
  end

  test "update profile success" do
    user = confirmed_user("update_test@example.com", first_name: "Original")
    sign_in user

    put user_registration_url, params: {
      user: { first_name: "Updated", current_password: "Password1!" }
    }, as: :json

    assert_response :success
    assert_equal "Updated", json_response["user"]["first_name"]
  end

  test "update profile failure without current password" do
    user = confirmed_user("update_fail@example.com")
    sign_in user

    put user_registration_url, params: {
      user: { first_name: "Updated" }
    }, as: :json

    assert_response :unprocessable_entity
    assert json_response["errors"].present?
  end

  test "destroy account success" do
    user = confirmed_user("destroy_test@example.com")
    sign_in user

    assert_difference("User.count", -1) do
      delete user_registration_url, as: :json
    end

    assert_response :success
    assert json_response["message"].present?
  end

  test "destroy account failure renders errors" do
    user = confirmed_user("destroy_fail@example.com")
    user.define_singleton_method(:destroy) do
      errors.add(:base, "cannot delete account")
      false
    end

    controller = TestRegistrationsController.new
    controller.define_singleton_method(:resource) { user }
    controller.define_singleton_method(:sign_out) { |*_| true }
    controller.define_singleton_method(:set_flash_message!) { |*_| nil }

    controller.destroy

    assert_equal :unprocessable_entity, controller.rendered_status
    assert_includes controller.rendered_json[:errors], "cannot delete account"
  end
end

class TestRegistrationsController < Users::RegistrationsController
  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json = json
    @rendered_status = status
  end
end
