require "test_helper"
require "tmpdir"

class CoverageReportRedirectMiddlewareTest < ActiveSupport::TestCase
  test "redirects get requests for coverage when a report exists" do
    status, headers, body = with_middleware(report_exists: true) do |middleware|
      middleware.call(Rack::MockRequest.env_for("/coverage", "REQUEST_METHOD" => "GET"))
    end

    assert_equal 301, status
    assert_equal "/coverage/", headers.fetch("Location")
    assert_equal "text/html", headers.fetch("Content-Type")
    assert_equal "0", headers.fetch("Content-Length")
    assert_equal [], body
  end

  test "redirects head requests for coverage when a report exists" do
    status, headers, _body = with_middleware(report_exists: true) do |middleware|
      middleware.call(Rack::MockRequest.env_for("/coverage", "REQUEST_METHOD" => "HEAD"))
    end

    assert_equal 301, status
    assert_equal "/coverage/", headers.fetch("Location")
  end

  test "passes through when report is missing or path does not match" do
    status, headers, body = with_middleware(report_exists: false) do |middleware|
      middleware.call(Rack::MockRequest.env_for("/coverage", "REQUEST_METHOD" => "GET"))
    end

    assert_equal 200, status
    assert_equal "text/plain", headers.fetch("Content-Type")
    assert_equal [ "ok" ], body

    status, _headers, body = with_middleware(report_exists: true) do |middleware|
      middleware.call(Rack::MockRequest.env_for("/other", "REQUEST_METHOD" => "POST"))
    end

    assert_equal 200, status
    assert_equal [ "ok" ], body
  end

  test "redirect response prefixes script name when present" do
    with_middleware(report_exists: true) do |middleware|
      request = Rack::Request.new(
        Rack::MockRequest.env_for("/coverage", "SCRIPT_NAME" => "/auth-service")
      )

      status, headers, body = middleware.send(:redirect_response, request)

      assert_equal 301, status
      assert_equal "/auth-service/coverage/", headers.fetch("Location")
      assert_equal [], body
    end
  end

  private

  def with_middleware(report_exists:)
    Dir.mktmpdir do |dir|
      report_path = File.join(dir, "index.html")
      File.write(report_path, "coverage") if report_exists

      middleware = CoverageReportRedirectMiddleware.new(
        ->(_env) { [ 200, { "Content-Type" => "text/plain" }, [ "ok" ] ] },
        report_path: report_path
      )

      yield middleware
    end
  end
end