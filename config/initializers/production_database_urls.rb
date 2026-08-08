# frozen_string_literal: true

require "uri"

module ProductionDatabaseUrls
  NAMES = %w[DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL].freeze
  SUFFIXES = {
    "DATABASE_URL" => "",
    "CACHE_DATABASE_URL" => "_cache",
    "QUEUE_DATABASE_URL" => "_queue",
    "CABLE_DATABASE_URL" => "_cable"
  }.freeze
  COMPONENTS = %w[POSTGRES_HOST POSTGRES_PORT POSTGRES_USER POSTGRES_PASSWORD].freeze
  REQUIRED = %w[POSTGRES_USER POSTGRES_PASSWORD].freeze

  def self.apply!(environment:)
    return true unless environment == "production"

    urls = synthesize(ENV.to_h)
    check!(urls)

    NAMES.each do |name|
      ENV[name] = urls.fetch(name)
    end

    true
  end

  def self.validate!(environment:, urls:)
    return true unless environment == "production"

    check!(synthesize(urls))
  end

  def self.synthesize(urls)
    return urls unless COMPONENTS.any? { |name| urls[name].to_s.present? }

    missing = REQUIRED.reject { |name| urls[name].to_s.present? }
    raise KeyError, "Missing production PostgreSQL configuration: #{missing.join(', ')}" unless missing.empty?

    base = urls["POSTGRES_DB"].presence || default_database_base

    NAMES.each_with_object(urls.dup) do |name, merged|
      value = merged[name]
      if value.to_s.empty?
        merged[name] = build_url(urls, "#{base}#{SUFFIXES.fetch(name)}")
      elsif parse(value).nil?
        raise KeyError, "Missing or invalid PostgreSQL URL: #{name}"
      end
    end
  end

  def self.build_url(urls, database)
    user = encode(urls["POSTGRES_USER"].presence || "postgres")
    password = encode(urls["POSTGRES_PASSWORD"].to_s)
    host = urls["POSTGRES_HOST"].presence || "127.0.0.1"
    host = "[#{host}]" if host.include?(":") && !host.start_with?("[")
    port = urls["POSTGRES_PORT"].presence || "5432"

    "postgresql://#{user}:#{password}@#{host}:#{port}/#{encode(database)}"
  end

  def self.default_database_base
    app = Rails.application.class.module_parent_name.underscore.gsub(/([a-z])(\d)/, '\1_\2')
    "#{app}_production"
  end

  def self.parse(value)
    uri = URI.parse(value.to_s)
    return nil unless %w[postgres postgresql].include?(uri.scheme)
    return nil unless uri.host && uri.path.to_s.delete_prefix("/").present?
    return nil unless (1..65_535).cover?(uri.port || 5432)

    uri
  rescue URI::InvalidURIError
    nil
  end

  def self.check!(urls)
    parsed = NAMES.to_h do |name|
      uri = parse(urls[name])
      raise KeyError, "Missing or invalid PostgreSQL URL: #{name}" unless uri

      [ name, uri ]
    end

    targets = parsed.values.map do |uri|
      [ uri.host.downcase, uri.port || 5432, decode(uri.path.delete_prefix("/")) ]
    end
    raise ArgumentError, "Production database URLs must reference four distinct databases" unless targets.uniq.length == NAMES.length

    true
  end

  def self.encode(value)
    URI.encode_uri_component(value.to_s)
  end

  def self.decode(value)
    URI.decode_uri_component(value.to_s)
  rescue ArgumentError
    value.to_s
  end
  private_class_method :encode, :decode, :check!
end

ProductionDatabaseUrls.apply!(environment: Rails.env)
