require "test_helper"

class CleanExpiredJwtDenylistsJobTest < ActiveJob::TestCase
  test "uses the background queue" do
    assert_equal "background", CleanExpiredJwtDenylistsJob.queue_name
  end

  test "deletes expired records and logs the count" do
    JwtDenylist.delete_all

    expired = JwtDenylist.create!(jti: "expired-job-jti", exp: 2.hours.ago)
    active = JwtDenylist.create!(jti: "active-job-jti", exp: 2.hours.from_now)
    logger = Class.new {
      attr_reader :messages

      def initialize
        @messages = []
      end

      def info(message)
        @messages << message
        nil
      end
    }.new

    original_logger = Rails.logger
    Rails.singleton_class.send(:define_method, :logger) { logger }

    begin
      CleanExpiredJwtDenylistsJob.perform_now
    ensure
      Rails.singleton_class.send(:define_method, :logger) { original_logger }
    end

    assert_not JwtDenylist.exists?(expired.id)
    assert JwtDenylist.exists?(active.id)
    assert_includes logger.messages, "[CleanExpiredJwtDenylistsJob] Deleted 1 expired JWT denylist entries"
  end
end
