# frozen_string_literal: true

require "uri"

module ProductionDatabaseUrls
  NAMES = %w[DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL].freeze

  def self.validate!(environment:, urls:)
    return true unless environment == "production"

    parsed = NAMES.to_h do |name|
      value = urls[name].to_s
      uri = URI.parse(value)
      valid = %w[postgres postgresql].include?(uri.scheme) && uri.host && uri.path.to_s.delete_prefix("/").present?
      raise KeyError, "Missing or invalid PostgreSQL URL: #{name}" unless valid

      [ name, uri ]
    rescue URI::InvalidURIError
      raise KeyError, "Missing or invalid PostgreSQL URL: #{name}"
    end

    targets = parsed.values.map do |uri|
      [ uri.host.downcase, uri.port || 5432, uri.path.delete_prefix("/") ]
    end
    raise ArgumentError, "Production database URLs must reference four distinct databases" unless targets.uniq.length == NAMES.length

    true
  end
end

ProductionDatabaseUrls.validate!(environment: Rails.env, urls: ENV.to_h)
