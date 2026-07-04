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

    assert_response :success
    assert json_response["message"].present?
    assert_equal "newuser@example.com", json_response["user"]["email"]
  end

  test "signup failure with duplicate email" do
    confirmed_user("existing@example.com", role: "user")

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

  test "signup failure with short password" do
    assert_no_difference("User.count") do
      post user_registration_url, params: {
        user: {
          email: "short@example.com",
          password: "123",
          password_confirmation: "123"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert json_response["errors"].any? { |e| e.downcase.include?("password") }
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

  test "signup failure with missing email" do
    assert_no_difference("User.count") do
      post user_registration_url, params: {
        user: {
          email: "",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert json_response["errors"].any? { |e| e.downcase.include?("email") }
  end

  test "signup failure with password confirmation mismatch" do
    assert_no_difference("User.count") do
      post user_registration_url, params: {
        user: {
          email: "mismatch@example.com",
          password: "Password1!",
          password_confirmation: "Different1"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert json_response["errors"].any? { |e| e.downcase.include?("confirmation") }
  end

  test "update profile success" do
    user = confirmed_user("update_test@example.com", role: "user",
                          first_name: "Original", confirmed_at: Time.current)
    sign_in user

    put user_registration_url, params: {
      user: { first_name: "Updated", current_password: "Password1!" }
    }, as: :json

    assert_response :success
    assert_equal "Updated", json_response["user"]["first_name"]
  end
end
