# frozen_string_literal: true

require "test_helper"

class DockerfilePolicyTest < ActiveSupport::TestCase
  test "build does not require a committed lockfile" do
    dockerfile = Rails.root.join("Dockerfile").read
    assert_includes dockerfile, "COPY Gemfile ./"
    refute_match(/COPY\s+Gemfile\s+Gemfile\.lock/, dockerfile)
  end

  test "uses the documented default Ruby" do
    assert_includes Rails.root.join("Dockerfile").read, "ARG RUBY_VERSION=3.3"
  end

  test "installs PostgreSQL runtime and build libraries" do
    dockerfile = Rails.root.join("Dockerfile").read

    assert_includes dockerfile, "libpq5"
    assert_includes dockerfile, "libpq-dev"
    refute_match(/apt-get install.*\bsqlite3\b/, dockerfile)
    refute_match(/COPY\s+Gemfile\s+Gemfile\.lock/, dockerfile)
    assert_includes dockerfile, 'ENV BUNDLE_DEPLOYMENT="1"'
  end
end
