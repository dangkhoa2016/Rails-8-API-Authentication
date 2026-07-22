# frozen_string_literal: true

require_relative "boot"
require "rails/all"
require "dotenv/load" if Rails.env.development? || Rails.env.test?

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rails8ApiAuthentication
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `config` `ignore` list any files that are not Ruby
    # files, so that Rails does not add `.rb` extensions to them.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back arbitrarily.
    #
    # Middleware that Rack considers "common" is already handled by Rails.
    # config.session_store :cookie_store, key: "_interslice_session"
    #
    # This is the default Rails middleware stack for API-only apps.
    # config.middleware.use ActionDispatch::Cookies
    # config.middleware.use ActionDispatch::Session::CookieStore, key: "_interslice_session"
  end
end
