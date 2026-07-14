# frozen_string_literal: true

require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  test "redacts reset_password_token through the active token filter" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter(reset_password_token: "sensitive").fetch(:reset_password_token)
  end
end
