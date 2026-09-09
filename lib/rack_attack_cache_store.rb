# frozen_string_literal: true

module RackAttackCacheStore
  module_function

  def resolve(environment:, requested:, default_store:)
    mode = requested.to_s.strip
    return ActiveSupport::Cache::MemoryStore.new if environment == "test" || mode == "memory"
    return default_store if mode.empty? || mode == "rails"

    raise ArgumentError,
      "Unsupported RACK_ATTACK_CACHE_STORE=#{mode.inspect}; expected rails or memory"
  end
end
