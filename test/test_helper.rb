# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-console"
  require "simplecov_json_formatter"
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
    SimpleCov::Formatter::Console
  ])

  SimpleCov.start "rails" do
    coverage_dir "public/coverage"
    if Gem::Version.new(SimpleCov::VERSION) >= Gem::Version.new("1.0")
      skip "/test/"
      skip "/config/"
      skip "/vendor/"
    else
      add_filter "/test/"
      add_filter "/config/"
      add_filter "/vendor/"
    end
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "securerandom"
require "devise"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def json_response
    JSON.parse(response.body)
  end
end
