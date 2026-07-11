# frozen_string_literal: true

require "shellwords"

class PasswordResetInstructions
  attr_reader :token

  def initialize(token)
    @token = token.to_s
  end

  def endpoint_url
    Rails.application.routes.url_helpers.user_password_url(url_options)
  end

  def payload
    {
      user: {
        reset_password_token: token,
        password: "<NEW_PASSWORD>",
        password_confirmation: "<NEW_PASSWORD>"
      }
    }
  end

  def payload_json
    JSON.generate(payload)
  end

  def curl_command
    [
      "curl -X PUT",
      Shellwords.shellescape(endpoint_url),
      "-H",
      Shellwords.shellescape("Content-Type: application/json"),
      "--data",
      Shellwords.shellescape(payload_json)
    ].join(" ")
  end

  def plain_text
    <<~TEXT
      Password reset requested

      This service is API-only and does not provide a browser password-reset form.
      Use the reset token below with PUT /users/password.

      Reset token:
      #{token}

      Content-Type: application/json
      JSON payload:
      #{payload_json}

      curl example:
      #{curl_command}

      If you did not request this password reset, ignore this email.
    TEXT
  end

  private

  def url_options
    Rails.application.config.action_mailer.default_url_options.to_h.merge(only_path: false)
  end
end
