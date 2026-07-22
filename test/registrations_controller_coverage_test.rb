# frozen_string_literal: true

require "test_helper"

class RegistrationsControllerCoverageTest < ActionDispatch::IntegrationTest
  test "registration create success" do
    assert_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "newreg@example.local",
          username: "newreg_user",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }, as: :json
    end
    assert_response :success
    body = json_response
    assert body.key?("message")
    assert body.key?("user")
  end

  test "registration create with errors returns 422" do
    post user_registration_path, params: {
      user: {
        email: "user1@example.local",
        username: "dup_reg_user",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  end

  test "registration update success" do
    user = User.create!(
      email: "regupdate@example.local",
      username: "regupdate_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )
    sign_in user

    put user_registration_path, params: {
      user: {
        first_name: "Updated",
        current_password: "Password1!"
      }
    }, as: :json
    assert_response :success
    body = json_response
    assert body.key?("message")
  end

  test "registration update with errors returns 422" do
    user = User.create!(
      email: "regupdate2@example.local",
      username: "regupdate2_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )
    sign_in user

    put user_registration_path, params: {
      user: {
        username: users(:admin).username,
        current_password: "Password1!"
      }
    }, as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  end

  test "registration destroy success" do
    user = User.create!(
      email: "regdestroy@example.local",
      username: "regdestroy_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )
    sign_in user

    delete user_registration_path, params: {
      user: { current_password: "Password1!" }
    }, as: :json
    assert_response :success
    body = json_response
    assert body.key?("message")
  end

  test "registration destroy with invalid password returns errors" do
    user = User.create!(
      email: "regdestroy2@example.local",
      username: "regdestroy2_user",
      password: "Password1!",
      password_confirmation: "Password1!",
      confirmed_at: Time.current
    )
    sign_in user

    user.define_singleton_method(:destroy) { false }
    original_find = User.method(:find)
    User.define_singleton_method(:find) { |_id| user }

    delete user_registration_path, params: {
      user: { current_password: "WrongPassword1!" }
    }, as: :json
    assert_response :unprocessable_entity
    assert json_response.key?("errors")
  ensure
    User.singleton_class.define_method(:find, original_find)
  end
end
