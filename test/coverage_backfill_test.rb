# frozen_string_literal: true

require "test_helper"

require "ostruct"

class CoverageBackfillTest < ActiveSupport::TestCase
  # --- lib/failure_middleware.rb (lines 3-6) ---

  if defined?(FailureMiddleware)
    test "FailureMiddleware class is loadable" do
      assert_equal Devise::FailureApp, FailureMiddleware.superclass
    end

    test "FailureMiddleware http_auth_body returns JSON for JSON format" do
      middleware = FailureMiddleware.new
      env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "application/json", "action_dispatch.request.format" => :json)
      request = ActionDispatch::Request.new(env)
      middleware.define_singleton_method(:request) { request }
      middleware.define_singleton_method(:request_format) { :json }
      middleware.define_singleton_method(:i18n_message) { "invalid" }
      result = middleware.send(:http_auth_body)
      parsed = JSON.parse(result)
      assert_equal false, parsed["success"]
      assert_equal "invalid", parsed["message"]
    end
  end

  # --- lib/coverage_report_redirect_middleware.rb ---

  test "CoverageReportRedirectMiddleware initializes with app" do
    app = ->(env) { [ 200, {}, [ "OK" ] ] }
    middleware = CoverageReportRedirectMiddleware.new(app)
    assert middleware.respond_to?(:call)
  end

  test "CoverageReportRedirectMiddleware passes through non-coverage requests" do
    app = ->(env) { [ 200, {}, [ "OK" ] ] }
    middleware = CoverageReportRedirectMiddleware.new(app)
    env = Rack::MockRequest.env_for("/other-path", method: "GET")
    status, _headers, _body = middleware.call(env)
    assert_equal 200, status
  end

  test "CoverageReportRedirectMiddleware redirects /coverage when report exists" do
    app = ->(env) { [ 200, {}, [ "OK" ] ] }
    report_path = Rails.root.join("public/coverage/index.html")
    middleware = CoverageReportRedirectMiddleware.new(app, report_path: report_path)

    FileUtils.mkdir_p(File.dirname(report_path))
    FileUtils.touch(report_path) unless File.exist?(report_path)

    env = Rack::MockRequest.env_for("/coverage", method: "GET")
    status, headers, _body = middleware.call(env)
    assert_equal 302, status
    assert headers["Location"].include?("/coverage/")
  ensure
    FileUtils.rm_f(report_path)
  end

  test "CoverageReportRedirectMiddleware passes through /coverage when report missing" do
    app = ->(env) { [ 200, {}, [ "OK" ] ] }
    middleware = CoverageReportRedirectMiddleware.new(app, report_path: "/nonexistent/path.html")
    env = Rack::MockRequest.env_for("/coverage", method: "GET")
    status, _headers, _body = middleware.call(env)
    assert_equal 200, status
  end

  # --- app/mailers/application_mailer.rb ---

  test "ApplicationMailer is configured" do
    assert ApplicationMailer < ActionMailer::Base
    assert_equal "from@example.com", ApplicationMailer.default[:from]
  end

  # --- app/controllers/users/confirmations_controller.rb (line 3) ---

  if defined?(Users::ConfirmationsController)
    test "ConfirmationsController is a Devise::ConfirmationsController subclass" do
      assert Users::ConfirmationsController < Devise::ConfirmationsController
    end
  end

  # --- app/controllers/users/omniauth_callbacks_controller.rb (line 3) ---

  if defined?(Users::OmniauthCallbacksController)
    test "OmniauthCallbacksController is a Devise subclass" do
      assert Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
    end
  end

  # --- app/controllers/users/unlocks_controller.rb (line 3) ---

  if defined?(Users::UnlocksController)
    test "UnlocksController is a Devise::UnlocksController subclass" do
      assert Users::UnlocksController < Devise::UnlocksController
    end
  end

  # --- app/jobs/application_job.rb (line 3) ---

  test "ApplicationJob is an ActiveJob subclass" do
    assert ApplicationJob < ActiveJob::Base
  end

  # --- app/jobs/clean_expired_jwt_denylists_job.rb ---

  test "CleanExpiredJwtDenylistsJob runs without error" do
    JwtDenylist.create!(jti: SecureRandom.uuid, exp: 1.hour.ago)
    JwtDenylist.create!(jti: SecureRandom.uuid, exp: 1.hour.from_now)
    assert_nothing_raised { CleanExpiredJwtDenylistsJob.perform_now }
  end

  # --- app/models/user.rb ---

  test "SENSITIVE_FIELDS constant is defined and frozen" do
    assert User::SENSITIVE_FIELDS.frozen?
    assert_includes User::SENSITIVE_FIELDS, "encrypted_password"
    assert_includes User::SENSITIVE_FIELDS, "reset_password_token"
  end

  # --- app/controllers/application_controller.rb ---

  test "pagy_metadata returns expected structure" do
    controller = ApplicationController.new
    fake_pagy = OpenStruct.new(page: 1, limit: 20, count: 100, last: 5)
    result = controller.send(:pagy_metadata, fake_pagy)

    assert_equal 1, result[:current_page]
    assert_equal 20, result[:per_page]
    assert_equal 100, result[:total_count]
    assert_equal 5, result[:total_pages]
  end
end
