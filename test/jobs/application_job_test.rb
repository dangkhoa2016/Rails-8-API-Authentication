require "test_helper"

class ApplicationJobTest < ActiveSupport::TestCase
  test "inherits from active job base" do
    assert_equal ActiveJob::Base, ApplicationJob.superclass
  end
end