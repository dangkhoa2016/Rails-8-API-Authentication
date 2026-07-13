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
end
