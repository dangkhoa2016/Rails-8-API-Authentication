# frozen_string_literal: true

require "test_helper"

class RefreshTokenConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    RefreshToken.delete_all
    User.where(email: "refresh-race@example.com").delete_all
    @user = confirmed_user(
      "refresh-race@example.com",
      first_name: "Refresh",
      last_name: "Race"
    )
  end

  teardown do
    RefreshToken.delete_all
    User.where(email: "refresh-race@example.com").delete_all
  end

  test "only one concurrent rotation creates a successor" do
    skip "PostgreSQL locking test" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

    _raw_token, token = RefreshToken.generate_for(@user)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    errors = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          candidate = RefreshToken.find(token.id)
          ready << true
          start.pop
          results << candidate.rotate!.first
        rescue StandardError => error
          errors << error
        end
      end
    end

    Timeout.timeout(10) do
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:join)
    end

    assert errors.empty?, errors.size.times.map { errors.pop.full_message }.join("\n")
    assert_equal 2, results.size
    assert_equal %i[revoked rotated], 2.times.map { results.pop }.sort
    assert_equal 1, RefreshToken.active.where(user: @user, family_id: token.family_id).count
  ensure
    threads&.each do |thread|
      thread.kill if thread.alive?
      thread.join
    end
  end
end
