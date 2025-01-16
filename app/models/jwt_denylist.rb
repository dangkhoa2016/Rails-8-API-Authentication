class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  # self.table_name = "jwt_denylist"
  validates :jti, :exp, presence: true

  def self.jwt_revoked?(payload, user)
    result = exists?(jti: payload["jti"])
    if !result
      user.token_info = { payload: payload }
    end
    result
  end
end
