# frozen_string_literal: true

require "net/smtp"

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :omniauthable
  # note: :timeoutable will not work with Rails sessions disabled
  devise :database_authenticatable, :registerable,
         :confirmable, :lockable, :trackable,
         :rememberable, :validatable, :recoverable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  validates :password, format: {
    with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).*\z/,
    message: "must include at least 1 uppercase letter, 1 lowercase letter, and 1 number"
  }, if: :password_required?

  before_validation :normalize_username

  validates :username, uniqueness: { allow_blank: true },
                       length: { in: 3..25, allow_blank: true },
                       format: { with: /\A[a-zA-Z0-9_-]+\z/, allow_blank: true }

  def self.find_for_database_authentication(conditions)
    value = conditions[:email].to_s.downcase
    find_by(email: value) || find_by(username: value)
  end

  attr_accessor :token_info
  enum :role, { user: "user", admin: "admin" }

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  def on_jwt_dispatch(token, payload)
    # puts "on_jwt_dispatch: #{token}, #{payload}"
    self.token_info = { token: token, payload: payload }
  end

  # Defensive serialization: exclude sensitive fields from JSON output
  # even if they're added to the model in the future
  def serializable_hash(options = nil)
    opts = (options || {}).merge(except: SENSITIVE_FIELDS)
    result = super(opts)
    result[:unconfirmed_email] = unconfirmed_email if unconfirmed_email.present?
    result
  end

  def send_confirmation_instructions
    super
  rescue Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Failed to send confirmation instructions to #{email}: #{e.class} - #{e.message}"
  end

  SENSITIVE_FIELDS = %w[
    encrypted_password reset_password_token reset_password_sent_at
    confirmation_token unlock_token failed_attempts locked_at
    remember_created_at current_sign_in_ip last_sign_in_ip
    current_sign_in_at last_sign_in_at sign_in_count
  ].freeze

  private

  def normalize_username
    self.username = username.to_s.strip.parameterize.downcase.presence
  end

  def password_required?
    new_record? || password.present?
  end
end
