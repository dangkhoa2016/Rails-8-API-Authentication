class CoverageReportRedirectMiddleware
  def initialize(app, report_path: Rails.root.join("public/coverage/index.html"))
    @app = app
    @report_path = report_path
  end

  def call(env)
    request = Rack::Request.new(env)

    return redirect_response(request) if redirect_request?(request)

    @app.call(env)
  end

  private

  def redirect_request?(request)
    (request.get? || request.head?) && request.path == "/coverage" && File.exist?(@report_path)
  end

  def redirect_response(request)
    location = request.script_name.to_s.empty? ? "/coverage/" : "#{request.script_name}/coverage/"

    [ 301, { "Location" => location, "Content-Type" => "text/html", "Content-Length" => "0" }, [] ]
  end
end
