# frozen_string_literal: true

require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  test "CORS headers present on GET request" do
    get root_url, headers: { "Origin" => "http://localhost:4000" }
    assert_response :ok
    assert response.headers["Access-Control-Allow-Origin"].present?
  end

  test "CORS preflight OPTIONS request returns correct headers" do
    options root_url, headers: {
      "Origin" => "http://localhost:4000",
      "Access-Control-Request-Method" => "POST"
    }
    assert_response :ok
    assert response.headers["Access-Control-Allow-Methods"].present?
  end

  test "CORS headers include allowed methods" do
    get root_url, headers: { "Origin" => "http://localhost:4000" }
    assert_response :ok
    allowed_methods = response.headers["Access-Control-Allow-Methods"]
    assert allowed_methods.include?("GET")
    assert allowed_methods.include?("POST")
  end
end
