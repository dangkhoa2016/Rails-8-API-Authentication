# frozen_string_literal: true

# Single source of truth for refresh-token transport shared by auth
# controllers: reading the raw token from cookie/param/header and managing
# the signed HttpOnly cookie that carries it.
module RefreshTokenCookie
  extend ActiveSupport::Concern

  private

  def refresh_token_from_request
    cookies.signed[:refresh_token] || params[:refresh_token] || request.headers["X-Refresh-Token"]
  end

  def write_refresh_token_cookie(raw_token)
    cookies.signed[:refresh_token] = {
      value: raw_token,
      httponly: true,
      secure: Rails.env.production?,
      samesite: :lax,
      expires: RefreshToken::LIFETIME.from_now
    }
  end

  def delete_refresh_token_cookie
    cookies.delete(:refresh_token)
  end
end
