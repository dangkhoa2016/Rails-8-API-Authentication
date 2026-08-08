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

  test "builds missing URLs from POSTGRES_* components in production" do
    urls = {
      "POSTGRES_HOST" => "127.0.0.1",
      "POSTGRES_PORT" => "5432",
      "POSTGRES_USER" => "postgres",
      "POSTGRES_PASSWORD" => "postgres"
    }

    assert ProductionDatabaseUrls.validate!(environment: "production", urls: urls)

    synthesized = ProductionDatabaseUrls.synthesize(urls)
    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/rails_8_api_authentication_production", synthesized["DATABASE_URL"]
    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/rails_8_api_authentication_production_cache", synthesized["CACHE_DATABASE_URL"]
    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/rails_8_api_authentication_production_queue", synthesized["QUEUE_DATABASE_URL"]
    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/rails_8_api_authentication_production_cable", synthesized["CABLE_DATABASE_URL"]
  end

  test "explicit URL wins over POSTGRES_* components" do
    urls = {
      "DATABASE_URL" => "postgresql://explicit@db.example.com/primary",
      "POSTGRES_HOST" => "127.0.0.1",
      "POSTGRES_USER" => "postgres",
      "POSTGRES_PASSWORD" => "postgres"
    }

    synthesized = ProductionDatabaseUrls.synthesize(urls)

    assert_equal "postgresql://explicit@db.example.com/primary", synthesized["DATABASE_URL"]
    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/rails_8_api_authentication_production_cache", synthesized["CACHE_DATABASE_URL"]
  end

  test "POSTGRES_DB overrides the derived base name" do
    urls = {
      "POSTGRES_DB" => "myapp_production",
      "POSTGRES_HOST" => "127.0.0.1",
      "POSTGRES_USER" => "postgres",
      "POSTGRES_PASSWORD" => "postgres"
    }

    synthesized = ProductionDatabaseUrls.synthesize(urls)

    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/myapp_production", synthesized["DATABASE_URL"]
    assert_equal "postgresql://postgres:postgres@127.0.0.1:5432/myapp_production_cable", synthesized["CABLE_DATABASE_URL"]
  end

  test "percent-encodes user and password components" do
    urls = {
      "POSTGRES_HOST" => "127.0.0.1",
      "POSTGRES_USER" => "a b",
      "POSTGRES_PASSWORD" => "p@ss: word/"
    }

    synthesized = ProductionDatabaseUrls.synthesize(urls)
    uri = URI.parse(synthesized["DATABASE_URL"])

    assert_equal "a b", URI::DEFAULT_PARSER.unescape(uri.user)
    assert_equal "p@ss: word/", URI::DEFAULT_PARSER.unescape(uri.password)
  end

  test "does not synthesize when no POSTGRES_* components are present" do
    urls = { "DATABASE_URL" => "postgresql://user:secret@db/primary" }

    assert_equal urls, ProductionDatabaseUrls.synthesize(urls)
  end

  test "raises when an explicit URL is invalid while components are present" do
    urls = {
      "DATABASE_URL" => "postgresql-BỊ-SAI://host/db",
      "POSTGRES_HOST" => "127.0.0.1",
      "POSTGRES_USER" => "postgres",
      "POSTGRES_PASSWORD" => "postgres"
    }

    assert_raises(KeyError) do
      ProductionDatabaseUrls.synthesize(urls)
    end
  end

  test "requires POSTGRES_USER and POSTGRES_PASSWORD in component mode" do
    urls = { "POSTGRES_HOST" => "db.example.com" }

    error = assert_raises(KeyError) do
      ProductionDatabaseUrls.synthesize(urls)
    end

    assert_match(/POSTGRES_USER/, error.message)
    assert_match(/POSTGRES_PASSWORD/, error.message)
  end

  test "apply! raises before writing ENV when a URL is invalid" do
    names = ProductionDatabaseUrls::NAMES
    original = names.to_h { |name| [ name, ENV[name] ] }

    ENV["DATABASE_URL"] = "postgresql-BỊ-SAI://host/db"
    ENV["POSTGRES_HOST"] = "127.0.0.1"
    ENV["POSTGRES_USER"] = "postgres"
    ENV["POSTGRES_PASSWORD"] = "postgres"

    assert_raises(KeyError) do
      ProductionDatabaseUrls.apply!(environment: "production")
    end
    assert_equal "postgresql-BỊ-SAI://host/db", ENV["DATABASE_URL"]
    assert_nil ENV["CACHE_DATABASE_URL"]
  ensure
    original.each do |name, value|
      value.nil? ? ENV.delete(name) : ENV[name] = value
    end
  end

  test "encodes database name in synthesized URL" do
    urls = {
      "POSTGRES_DB" => "my db/2",
      "POSTGRES_HOST" => "127.0.0.1",
      "POSTGRES_USER" => "postgres",
      "POSTGRES_PASSWORD" => "secret"
    }

    url = ProductionDatabaseUrls.synthesize(urls)["DATABASE_URL"]
    uri = URI.parse(url)

    assert_equal "my db/2", URI::DEFAULT_PARSER.unescape(uri.path.delete_prefix("/"))
  end

  test "brackets IPv6 hosts in synthesized URL" do
    urls = {
      "POSTGRES_HOST" => "::1",
      "POSTGRES_USER" => "postgres",
      "POSTGRES_PASSWORD" => "secret"
    }

    url = ProductionDatabaseUrls.synthesize(urls)["DATABASE_URL"]

    assert_equal "postgresql://postgres:secret@[::1]:5432/rails_8_api_authentication_production", url
  end

  test "rejects URLs with out-of-range ports" do
    urls = NAMES.to_h { |name| [ name, "postgresql://user:secret@db:70000/#{name.downcase}" ] }

    assert_raises(KeyError) do
      ProductionDatabaseUrls.validate!(environment: "production", urls: urls)
    end
  end

  test "rejects URLs whose decoded database names are identical" do
    urls = {
      "DATABASE_URL" => "postgresql://user:secret@db/db",
      "CACHE_DATABASE_URL" => "postgresql://user:secret@db/%64b",
      "QUEUE_DATABASE_URL" => "postgresql://user:secret@db/queue",
      "CABLE_DATABASE_URL" => "postgresql://user:secret@db/cable"
    }

    assert_raises(ArgumentError) do
      ProductionDatabaseUrls.validate!(environment: "production", urls: urls)
    end
  end

  test "apply! writes synthesized URLs into ENV and validates" do
    names = ProductionDatabaseUrls::NAMES + %w[POSTGRES_HOST POSTGRES_PORT POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB]
    original = names.to_h { |name| [ name, ENV[name] ] }

    ProductionDatabaseUrls::NAMES.each { |name| ENV.delete(name) }
    ENV["POSTGRES_HOST"] = "db.example.com"
    ENV["POSTGRES_PORT"] = "5432"
    ENV["POSTGRES_USER"] = "postgres"
    ENV["POSTGRES_PASSWORD"] = "postgres"
    ENV.delete("POSTGRES_DB")

    assert ProductionDatabaseUrls.apply!(environment: "production")
    assert ENV["DATABASE_URL"].start_with?("postgresql://postgres:postgres@db.example.com:5432/")
    assert ENV["CACHE_DATABASE_URL"].start_with?("postgresql://postgres:postgres@db.example.com:5432/")
    assert ENV["QUEUE_DATABASE_URL"].start_with?("postgresql://postgres:postgres@db.example.com:5432/")
    assert ENV["CABLE_DATABASE_URL"].start_with?("postgresql://postgres:postgres@db.example.com:5432/")
  ensure
    original.each do |name, value|
      value.nil? ? ENV.delete(name) : ENV[name] = value
    end
  end
end
