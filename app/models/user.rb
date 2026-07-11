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

  before_validation :normalize_username

  validates :username, uniqueness: { allow_nil: true },
                       length: { in: 3..25, allow_nil: true },
                       format: { with: /\A[a-zA-Z0-9_-]+\z/, allow_nil: true }

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
    Rails.logger.error "Failed to send confirmation instructions to #{email}: #{e.class} - #{e.message}"
  end

  private

  def normalize_username
    self.username = username.to_s.gsub(/\s+/, "").downcase.presence
  end
end
