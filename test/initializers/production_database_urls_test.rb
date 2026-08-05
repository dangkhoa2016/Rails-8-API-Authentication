# frozen_string_literal: true

require "test_helper"

class ProductionDatabaseUrlsTest < ActiveSupport::TestCase
  NAMES = %w[DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL].freeze

  test "accepts four distinct PostgreSQL URLs" do
    urls = NAMES.to_h { |name| [ name, "postgresql://user:secret@db/#{name.downcase}" ] }

    assert ProductionDatabaseUrls.validate!(environment: "production", urls: urls)
  end

  test "rejects missing URLs without exposing values" do
    error = assert_raises(KeyError) do
      ProductionDatabaseUrls.validate!(environment: "production", urls: {})
    end

    assert_match(/DATABASE_URL/, error.message)
    assert_no_match(/secret/, error.message)
  end

  test "rejects URLs that resolve to the same database target" do
    urls = {
      "DATABASE_URL" => "postgresql://writer:secret@db:5432/shared",
      "CACHE_DATABASE_URL" => "postgresql://cache:other@db:5432/shared",
      "QUEUE_DATABASE_URL" => "postgresql://user:secret@db/queue",
      "CABLE_DATABASE_URL" => "postgresql://user:secret@db/cable"
    }

    assert_raises(ArgumentError) do
      ProductionDatabaseUrls.validate!(environment: "production", urls: urls)
    end
  end

  test "does nothing outside production" do
    assert ProductionDatabaseUrls.validate!(environment: "test", urls: {})
  end
end
