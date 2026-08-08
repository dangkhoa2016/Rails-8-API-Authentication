# frozen_string_literal: true

require "test_helper"
require "erb"
require "yaml"

class DatabaseConfigurationTest < ActiveSupport::TestCase
  def database_config
    YAML.safe_load(
      ERB.new(Rails.root.join("config/database.yml").read).result,
      aliases: true
    )
  end

  test "development and test use PostgreSQL" do
    assert_equal "postgresql", database_config.dig("development", "adapter")
    assert_equal "postgresql", database_config.dig("test", "adapter")
    assert_equal "unicode", database_config.dig("test", "encoding")
  end

  test "production defines all Solid adapter databases" do
    assert_equal %w[cable cache primary queue], database_config.fetch("production").keys.sort
    assert_equal "db/cache_migrate", database_config.dig("production", "cache", "migrations_paths")
    assert_equal "db/queue_migrate", database_config.dig("production", "queue", "migrations_paths")
    assert_equal "db/cable_migrate", database_config.dig("production", "cable", "migrations_paths")
  end
end
