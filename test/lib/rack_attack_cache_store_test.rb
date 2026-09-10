# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/rack_attack_cache_store")

class RackAttackCacheStoreTest < ActiveSupport::TestCase
  test "test environment uses memory store" do
    store = RackAttackCacheStore.resolve(
      environment: "test",
      requested: nil,
      default_store: Object.new
    )

    assert_instance_of ActiveSupport::Cache::MemoryStore, store
  end

  test "memory mode uses memory store" do
    store = RackAttackCacheStore.resolve(
      environment: "production",
      requested: "memory",
      default_store: Object.new
    )

    assert_instance_of ActiveSupport::Cache::MemoryStore, store
  end

  test "blank and rails modes preserve shared Rails cache" do
    default_store = Object.new

    assert_same default_store, RackAttackCacheStore.resolve(
      environment: "production", requested: nil, default_store: default_store
    )
    assert_same default_store, RackAttackCacheStore.resolve(
      environment: "production", requested: "rails", default_store: default_store
    )
  end

  test "unknown mode fails closed" do
    error = assert_raises(ArgumentError) do
      RackAttackCacheStore.resolve(
        environment: "production",
        requested: "redis-ish",
        default_store: Object.new
      )
    end

    assert_match(/RACK_ATTACK_CACHE_STORE/, error.message)
  end
end
