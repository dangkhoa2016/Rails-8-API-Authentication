# frozen_string_literal: true

require "test_helper"

class DeviseJwtInitializerTest < ActiveSupport::TestCase
  test "compatibility patch is prepended at most once" do
    strategy = Warden::JWTAuth::Strategy
    patch = Devise::JWT::WardenStrategy
    assert_operator strategy.ancestors.count(patch), :<=, 1
  end
end
