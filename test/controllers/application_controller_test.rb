require "test_helper"

class TestErrorsController < ApplicationController
  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json = json
    @rendered_status = status
  end
end

class ApplicationControllerTest < ActiveSupport::TestCase
  test "internal errors return json response" do
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
    exception = StandardError.new("boom")
    exception.set_backtrace([ "test/backtrace.rb:1" ])

    controller.define_singleton_method(:logger) { logger }

    controller.send(:handle_internal_error, exception)

    assert_equal({ error: I18n.translate("errors.internal_error") }, controller.rendered_json)
    assert_equal 500, controller.rendered_status
    assert_match(/boom/, logger.messages.first)
  end
end
