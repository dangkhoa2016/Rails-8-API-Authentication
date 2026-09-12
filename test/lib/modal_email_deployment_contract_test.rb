# frozen_string_literal: true

require "test_helper"

class ModalEmailDeploymentContractTest < ActiveSupport::TestCase
  test "Modal runtime secret requires outbound email configuration" do
    source = File.read(Rails.root.join("deploy/modal/app.py"))

    %w[
      SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD SMTP_DOMAIN
      SMTP_AUTHENTICATION SMTP_SSL SMTP_ENABLE_STARTTLS_AUTO
      DEVISE_MAILER_SENDER APP_HOST APP_PROTOCOL PUBLIC_DEMO_EMAIL_GUARD
    ].each do |key|
      assert_includes source, %("#{key}"), "expected Modal secret contract to require #{key}"
    end
  end

  test "public email delivery acceptance is fail closed" do
    source = File.read(Rails.root.join("deploy/modal/email_delivery_e2e.sh"))

    assert_includes source, "unsupported-domain registration expected 422"
    assert_includes source, "allowed-provider registration expected 201"
    assert_includes source, "https://api.resend.com/emails?limit=100"
    assert_includes source, "delivered"
  end
end
