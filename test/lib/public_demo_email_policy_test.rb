# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/public_demo_email_policy")

class PublicDemoEmailPolicyTest < ActiveSupport::TestCase
  ENABLED = { "PUBLIC_DEMO_EMAIL_GUARD" => "true" }.freeze

  test "guard is disabled by default" do
    assert_not PublicDemoEmailPolicy.enabled?({})
    assert PublicDemoEmailPolicy.allowed?("user@example.com", {})
  end

  test "guard accepts all supported providers case-insensitively" do
    PublicDemoEmailPolicy::ALLOWED_DOMAINS.each do |domain|
      assert PublicDemoEmailPolicy.allowed?("Person@#{domain.upcase}", ENABLED), domain
    end
  end

  test "guard rejects unsupported domains" do
    assert_not PublicDemoEmailPolicy.allowed?("person@example.com", ENABLED)
    assert_not PublicDemoEmailPolicy.allowed?("person@mail.ru", ENABLED)
    assert_not PublicDemoEmailPolicy.allowed?("person@yandex.com", ENABLED)
  end

  test "domain extraction rejects malformed addresses" do
    assert_nil PublicDemoEmailPolicy.domain("not-an-email")
    assert_nil PublicDemoEmailPolicy.domain("@gmail.com")
    assert_nil PublicDemoEmailPolicy.domain("user@")
    assert_nil PublicDemoEmailPolicy.domain("a@b@gmail.com")
  end
end
