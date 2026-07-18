# frozen_string_literal: true

require "digest"
require "securerandom"

class RefreshToken < ApplicationRecord
  LIFETIME = 7.days

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :family_id, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  class << self
    def generate_for(user, user_agent: nil, ip_address: nil, family_id: nil)
      raw_token = SecureRandom.hex(32)
      family_id ||= SecureRandom.uuid

      record = create!(
        user: user,
        token_digest: digest(raw_token),
        family_id: family_id,
        expires_at: LIFETIME.from_now,
        user_agent: user_agent,
        ip_address: ip_address
      )

      [ raw_token, record ]
    end

    def digest(raw_token)
      Digest::SHA256.hexdigest(raw_token.to_s)
    end

    def find_by_raw_token(raw_token)
      return nil if raw_token.blank?

      find_by(token_digest: digest(raw_token))
    end
  end

  def active?
    revoked_at.nil? && expires_at > Time.current
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end

  def revoke_family!
    RefreshToken.where(
      user_id: user_id,
      family_id: family_id,
      revoked_at: nil
    ).update_all(revoked_at: Time.current)
  end

  def rotate!(user_agent: nil, ip_address: nil)
    with_lock do
      reload

      if revoked?
        [ :revoked, nil, nil ]
      elsif expired?
        update!(revoked_at: Time.current)
        [ :expired, nil, nil ]
      else
        update!(revoked_at: Time.current)
        raw_token, record = self.class.generate_for(
          user,
          user_agent: user_agent,
          ip_address: ip_address,
          family_id: family_id
        )
        [ :rotated, raw_token, record ]
      end
    end
  end
end
