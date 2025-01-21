require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get home_index_url
    assert_response :success
  end

  test "should get favicon.ico" do
    get "/favicon.ico"
    assert_response :success
  end

  test "should get favicon.png" do
    get "/favicon.png"
    assert_response :success
  end

  test "should get robots.txt" do
    get "/robots.txt"
    assert_response :success
  end
end
