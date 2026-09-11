# frozen_string_literal: true

# Public-demo outbound-email policy.
#
# This is intentionally opt-in so production users of the open-source project
# are not restricted to consumer mailbox providers. The official public demo
# can enable the guard with PUBLIC_DEMO_EMAIL_GUARD=true.
class PublicDemoEmailPolicy
  ENV_KEY = "PUBLIC_DEMO_EMAIL_GUARD"

  ALLOWED_DOMAINS = %w[
    gmail.com
    outlook.com
    hotmail.com
    live.com
    yahoo.com
    icloud.com
    proton.me
    protonmail.com
  ].freeze

  TRUE_VALUES = %w[1 true yes on].freeze

  class << self
    def enabled?(env = ENV)
      TRUE_VALUES.include?(env.fetch(ENV_KEY, "").to_s.strip.downcase)
    end

    def allowed?(email, env = ENV)
      return true unless enabled?(env)

      ALLOWED_DOMAINS.include?(domain(email))
    end

    def domain(email)
      value = email.to_s.strip.downcase
      local, separator, domain = value.rpartition("@")

      return nil if separator.empty? || local.empty? || domain.empty? || local.include?("@")

      domain
    end

    def allowed_domains_label
      ALLOWED_DOMAINS.join(", ")
    end
  end
end
