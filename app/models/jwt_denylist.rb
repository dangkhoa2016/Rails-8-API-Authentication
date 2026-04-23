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

  def self.delete_expired!(before: Time.current)
    expired_before(before).delete_all
  end
end
