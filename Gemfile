source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
# solid_cable >= 4.0 requires Ruby >= 3.3
if RUBY_VERSION < "3.3"
  gem "solid_cable", "< 4.0"
else
  gem "solid_cable"
end

# Reduces boot times through caching; required in config/boot.rb
# bootsnap >= 1.20 compiles native extensions requiring Ruby 4.0+ APIs
if RUBY_VERSION < "4"
  gem "bootsnap", "~> 1.18.0", require: false
else
  gem "bootsnap", require: false
end

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# Ruby 4.x only — these gems are no longer in Ruby's default set
if RUBY_VERSION >= "4"
  gem "cgi"      # extracted from stdlib in Ruby 4
  gem "tsort"    # removed from default gems in Ruby 4
end

# Ruby 3.x compatibility pins — newer versions of these gems require Ruby >= 3.3
if RUBY_VERSION < "4"
  gem "dry-auto_inject", "< 1.2"
  gem "dry-configurable", "< 1.4"
  gem "parallel", "< 2.0"
end

# Rails 8.0.1 is not compatible with minitest 6
gem "minitest", "< 6"

# Pin rdoc to match system version (7.2.0) to avoid double-load warnings
gem "rdoc", "~> 8.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Load environment variables from .env files
  gem "dotenv"

  # Code coverage
  # Ruby 4 → SimpleCov 1.x (uses `skip`), Ruby 3 → SimpleCov 0.x (uses `add_filter`)
  if RUBY_VERSION >= "4"
    gem "simplecov", "~> 1.0", require: false
  else
    gem "simplecov", "~> 0.22", require: false
  end
  gem "simplecov-console", require: false
end


gem "devise", "~> 5.0"

gem "devise-jwt", "~> 0.13.0"

# Rate limiting for auth endpoints
gem "rack-attack"
