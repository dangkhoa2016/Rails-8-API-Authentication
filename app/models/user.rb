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

  validates :username, uniqueness: { allow_nil: true },
                       length: { in: 3..25, allow_nil: true },
                       format: { with: /\A[a-zA-Z0-9_-]+\z/, allow_nil: true }

  def self.find_for_database_authentication(conditions)
    value = conditions[:email].to_s.downcase
    find_by(email: value) || find_by(username: value)
  end

  has_many :refresh_tokens, dependent: :destroy

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

  def serializable_hash(options = nil)
    opts = (options || {}).merge(except: SENSITIVE_FIELDS)
    result = super(opts)
    result[:unconfirmed_email] = unconfirmed_email if unconfirmed_email.present?
    result
  end

  def confirm(args = {})
    self.confirmation_token = nil
    super
  end

  SMTP_OFFLINE_ERRORS = [
    Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
    Errno::ENETUNREACH, Errno::EADDRNOTAVAIL, SocketError
  ].freeze

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_now
  rescue *SMTP_OFFLINE_ERRORS => e
    Rails.logger.error "Failed to send #{notification} to #{email}: #{e.class}"
    errors.add(:base, I18n.t("user.confirmation_email_failed")) if notification == :confirmation_instructions
    false
  end

  def send_confirmation_instructions
    super
  rescue *SMTP_OFFLINE_ERRORS => e
    Rails.logger.error "Failed to send confirmation to #{email}: #{e.class}"
    errors.add(:base, I18n.t("user.confirmation_email_failed"))
    false
  end

  SENSITIVE_FIELDS = %w[
    encrypted_password
    reset_password_token
    confirmation_token
    unlock_token
    jti
    current_sign_in_ip
    last_sign_in_ip
    current_sign_in_at
    last_sign_in_at
    sign_in_count
    failed_attempts
    locked_at
  ].freeze

  private

  def normalize_username
    self.username = username.to_s.strip.parameterize.underscore.downcase.presence
  end

  def password_required?
    new_record? || password.present?
  end
end
