# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure Action Mailer SMTP delivery from environment variables so the same
# code works locally (Mailpit), in Docker, and in production. When
# SMTP_ADDRESS is set, emails are delivered through that server; otherwise
# Rails falls back to its default behavior (localhost:25).
#
# Local Mailpit example:
#   SMTP_ADDRESS=localhost SMTP_PORT=1025
# Containerized app talking to Mailpit on the host:
#   SMTP_ADDRESS=host.docker.internal SMTP_PORT=1025

if ENV["SMTP_ADDRESS"].present?
  settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: ENV.fetch("SMTP_PORT", 587).to_i
  }

  settings[:user_name] = ENV["SMTP_USERNAME"] if ENV["SMTP_USERNAME"].present?
  settings[:password] = ENV["SMTP_PASSWORD"] if ENV["SMTP_PASSWORD"].present?
  settings[:domain] = ENV["SMTP_DOMAIN"] if ENV["SMTP_DOMAIN"].present?
  settings[:authentication] = ENV.fetch("SMTP_AUTHENTICATION").to_sym if ENV["SMTP_AUTHENTICATION"].present?

  ActionMailer::Base.smtp_settings = settings
  ActionMailer::Base.raise_delivery_errors = true
end
