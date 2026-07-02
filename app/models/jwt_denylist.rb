# frozen_string_literal: true

class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  # self.table_name = "jwt_denylist"
  validates :jti, :exp, presence: true
  scope :expired_before, ->(time = Time.current) { where("exp < ?", time) }

  def self.jwt_revoked?(payload, user)
    result = exists?(jti: payload["jti"])
    if !result
      user.token_info = { payload: payload }
    end
    result
  end

  # Uses delete_all for performance — JWT denylist entries don't need
  # ActiveRecord callbacks or validations. Safe because this model only
  # stores token identifiers with no dependent associations.
  def self.delete_expired!(before: Time.current)
    expired_before(before).delete_all
  end
end
