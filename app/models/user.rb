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
    with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
    message: "must include at least 1 uppercase letter, 1 lowercase letter, and 1 number"
  }, if: :password_required?

  validates :username, uniqueness: true, allow_blank: true

  attr_accessor :token_info
  enum :role, { user: "user", admin: "admin" }

  def on_jwt_dispatch(token, payload)
    # puts "on_jwt_dispatch: #{token}, #{payload}"
    self.token_info = { token: token, payload: payload }
  end

  def serializable_hash(options = nil)
    result = super

    if unconfirmed_email.present?
      result[:unconfirmed_email] = unconfirmed_email
    end

    result
  end

  def send_confirmation_instructions
    super
  rescue Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Failed to send confirmation to #{email}: #{e.class}"
    errors.add(:base, I18n.t("user.confirmation_email_failed"))
    false
  end

  private

  def password_required?
    new_record? || password.present?
  end
end
