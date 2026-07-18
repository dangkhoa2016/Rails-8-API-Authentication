# frozen_string_literal: true

require "test_helper"

class CleanExpiredRefreshTokensJobTest < ActiveJob::TestCase
  setup do
    @user = confirmed_user("clean_refresh_tokens@example.com", first_name: "Clean", last_name: "Tokens")
  end

  test "uses the default queue" do
    assert_equal "default", CleanExpiredRefreshTokensJob.queue_name
  end

  test "deletes tokens expired or revoked older than 7 days" do
    RefreshToken.delete_all

    expired_old = RefreshToken.generate_for(@user)
    RefreshToken.find(expired_old[1].id).update!(expires_at: 8.days.ago)
    revoked_old = RefreshToken.generate_for(@user)
    RefreshToken.find(revoked_old[1].id).update!(revoked_at: 8.days.ago)
    still_active = RefreshToken.generate_for(@user)

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

    Rails.stub(:logger, logger) do
      CleanExpiredRefreshTokensJob.perform_now
    end

    assert_not RefreshToken.exists?(expired_old[1].id)
    assert_not RefreshToken.exists?(revoked_old[1].id)
    assert RefreshToken.exists?(still_active[1].id)
    assert_includes logger.messages, "[CleanExpiredRefreshTokensJob] Deleted 2 expired/revoked refresh tokens"
  end

  test "logs zero when no records qualify" do
    RefreshToken.delete_all

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

    Rails.stub(:logger, logger) do
      CleanExpiredRefreshTokensJob.perform_now
    end

    assert_includes logger.messages, "[CleanExpiredRefreshTokensJob] Deleted 0 expired/revoked refresh tokens"
  end

  test "job is configured in recurring.yml" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    production_config = recurring["production"]
    assert production_config, "No production config found in recurring.yml"
    assert production_config.dig("clean_expired_refresh_tokens", "class"), "Job class not configured"
    assert production_config.dig("clean_expired_refresh_tokens", "schedule"), "Schedule not configured"
  end
end
