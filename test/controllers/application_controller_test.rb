# frozen_string_literal: true

require "test_helper"
require "ostruct"

class TestErrorsController < ApplicationController
  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json = json
    @rendered_status = status
  end
end

class TestSessionsController < Users::SessionsController
  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json = json
    @rendered_status = status
  end

  def request
    @_request ||= ActionDispatch::Request.new(Rack::MockRequest.env_for("/user/profile", {
      "HTTP_AUTHORIZATION" => "Bearer #{@token}",
      "CONTENT_TYPE" => "application/json"
    }))
  end
end

class ApplicationControllerTest < ActiveSupport::TestCase
  include Devise::Test::IntegrationHelpers

  def confirmed_user(email, password: "password", **attributes)
    base = email.split("@").first.gsub(/[^\w]/, "_")
    suffix = "_#{SecureRandom.hex(2)}"
    max_base = 25 - suffix.length
    attributes[:username] ||= base.length > max_base ? base[0, max_base] + suffix : base + suffix
    User.create!(
      {
        email: email,
        password: password,
        password_confirmation: password,
        confirmed_at: Time.current
      }.merge(attributes)
    )
  end

  def jwt_auth_headers_for(user, headers = { "Accept" => "application/json", "Content-Type" => "application/json" })
    Devise::JWT::TestHelpers.auth_headers(headers, user)
  end

  def decode_jwt(token)
    payload, = JWT.decode(
      token,
      Warden::JWTAuth.config.secret,
      true,
      algorithm: Warden::JWTAuth.config.algorithm
    )
    payload
  end

  test "JWT decode errors return 401" do
    controller = TestErrorsController.new
    logger = Class.new do
      attr_reader :messages

      def initialize
        @messages = []
      end

      def error(message)
        @messages << message
      end
    end.new

    controller.define_singleton_method(:logger) { logger }

    exception = JWT::DecodeError.new("invalid token")
    controller.send(:handle_invalid_token, exception)

    assert_equal({ error: I18n.translate("jwt.decode_error") }, controller.rendered_json)
    assert_equal :unauthorized, controller.rendered_status
  end

  test "record not found errors return 404" do
    controller = TestErrorsController.new
    logger = Class.new do
      attr_reader :messages

      def initialize
        @messages = []
      end

      def error(message)
        @messages << message
      end
    end.new

    controller.define_singleton_method(:logger) { logger }

    exception = ActiveRecord::RecordNotFound.new("User not found")
    controller.send(:record_not_found, exception)

    assert_equal({ error: I18n.translate("errors.record_not_found") }, controller.rendered_json)
    assert_equal :not_found, controller.rendered_status
  end

  test "parameter missing errors return 422" do
    controller = TestErrorsController.new
    logger = Class.new do
      attr_reader :messages

      def initialize
        @messages = []
      end

      def error(message)
        @messages << message
      end
    end.new

    controller.define_singleton_method(:logger) { logger }

    exception = ActionController::ParameterMissing.new("user")
    controller.send(:parameter_missing, exception)

    assert_equal({ error: I18n.translate("errors.parameter_missing") }, controller.rendered_json)
    assert_equal :unprocessable_entity, controller.rendered_status
  end

  test "build_token_info decodes payload from token when token_info lacks payload" do
    user = confirmed_user("unit_test@example.local")
    token = jwt_auth_headers_for(user).fetch("Authorization").delete_prefix("Bearer ")

    controller = TestSessionsController.new
    env = Rack::MockRequest.env_for("/user/profile", "HTTP_AUTHORIZATION" => "Bearer #{token}")
    fake_warden = Struct.new(:env).new(env)
    controller.define_singleton_method(:warden) { fake_warden }

    result = controller.send(:build_token_info, OpenStruct.new(token_info: nil))

    assert_equal token, result[:token]
    assert_equal user.id.to_s, result[:user_id]
    assert result[:jti].present?
  end

  test "build_token_info uses existing payload from token_info when available" do
    user = confirmed_user("unit_test2@example.local")
    token = jwt_auth_headers_for(user).fetch("Authorization").delete_prefix("Bearer ")
    payload = decode_jwt(token)

    controller = TestSessionsController.new
    controller.define_singleton_method(:warden) { Struct.new(:env).new({}) }

    result = controller.send(:build_token_info, OpenStruct.new(token_info: { token: token, payload: payload }))

    assert_equal token, result[:token]
    assert_equal user.id.to_s, result[:user_id]
    assert result[:jti].present?
  end
end
