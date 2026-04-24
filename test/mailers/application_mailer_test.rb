require "test_helper"

class ApplicationMailerTest < ActiveSupport::TestCase
  test "uses the expected default sender and layout" do
    assert_equal [ "from@example.com" ], Array(ApplicationMailer.default[:from])
    assert_equal "mailer", ApplicationMailer._layout
  end
end