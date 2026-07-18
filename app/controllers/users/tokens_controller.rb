# frozen_string_literal: true

class Users::TokensController < ApplicationController
  include RefreshTokenCookie

  skip_before_action :authenticate_user!, only: [ :refresh ], raise: false

  def refresh
    raw_token = refresh_token_from_request
    if raw_token.blank?
      return render json: { error: I18n.t("refresh_token.missing") }, status: :unauthorized
    end

    token_record = RefreshToken.find_by_raw_token(raw_token)

    if token_record.nil?
      return render json: { error: I18n.t("refresh_token.invalid") }, status: :unauthorized
    end

    # Reuse detection: an attacker is reusing a revoked token
    user = token_record.user
    unless user.active_for_authentication?
      token_record.revoke!
      delete_refresh_token_cookie
      return render json: { error: I18n.t("refresh_token.inactive_account") }, status: :unauthorized
    end

    status, new_raw_token, _new_record = token_record.rotate!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )

    case status
    when :revoked
      token_record.revoke_family!
      delete_refresh_token_cookie
      return render json: {
        error: I18n.t("refresh_token.reuse_detected")
      }, status: :unauthorized
    when :expired
      delete_refresh_token_cookie
      return render json: {
        error: I18n.t("refresh_token.expired")
      }, status: :unauthorized
    end

    # Issue a new JWT access token
    access_token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    write_refresh_token_cookie(new_raw_token)

    render json: {
      user: user,
      access_token: access_token,
      refresh_token: new_raw_token
    }, status: :ok
  end
end
