# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_signed_out_user, only: :destroy
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  def destroy
    # super

    user = current_user if user_signed_in?
    if user
      sign_out(user)
      render json: { message: I18n.translate("user.signed_out", email: user.email) }, status: :ok
    else
      render json: { message: I18n.translate("user.not_signed_in") }, status: :unprocessable_entity
    end
  end

  def show
    user = current_user if user_signed_in?
    token_info = build_token_info(user)

    if user
      render json: { user: user, token_info: token_info }, status: :ok
    else
      render json: { user: nil, token_info: token_info }, status: :unprocessable_entity
    end
  end

  private

  def build_token_info(user)
    token_info = {}

    if user
      token_info = user.token_info || {}
      token_info[:token] ||= get_token_from_request_headers
      payload = token_info.delete(:payload) || {}
    else
      token = get_token_from_request_headers
      payload, _config = decode_token(token) if token
      token_info[:token] = token
      payload ||= {}
    end

    expired_at = payload["exp"] || 0
    token_info.merge({
      user_id: payload["sub"],
      expired_at: Time.at(expired_at).to_datetime,
      expired_in: (expired_at - Time.now.to_i).to_i,
      expired: Time.now.to_i >= expired_at,
      jti: payload["jti"]
    })
  end

  def get_token_from_request_headers
    Warden::JWTAuth::HeaderParser.from_env(warden.env)
  end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
