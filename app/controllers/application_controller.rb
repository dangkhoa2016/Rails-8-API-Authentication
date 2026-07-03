# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pagy::Method
  include ActionController::MimeResponds
  respond_to :json
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from JWT::DecodeError, with: :handle_invalid_token
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from ActionController::UnknownFormat, with: :route_not_found

  def decode_token(token_string)
    Warden::JWTAuth::TokenDecoder.new.call(token_string)
  end

  # Handle errors for path not found
  def route_not_found
    logger.error "Route not found: #{request.path}"
    render json: { error: I18n.translate("errors.route_not_found") }, status: 404
  end

  private

  def configure_permitted_parameters
    fields = [ :first_name, :last_name, :username, :email, :password, :password_confirmation ]
    devise_parameter_sanitizer.permit(:sign_up, keys: fields)
    devise_parameter_sanitizer.permit(:account_update, keys: fields + [ :current_password ])
  end

  def handle_invalid_token(exception)
    logger.error "Invalid token: #{exception.message}"
    render json: { error: I18n.translate("jwt.decode_error") }, status: :unauthorized
  end

  def pagy_metadata(pagy)
    {
      current_page: pagy.page,
      per_page: pagy.limit,
      total_count: pagy.count,
      total_pages: pagy.last
    }
  end

  # Handle record not found errors
  def record_not_found(exception)
    logger.error "Record not found: #{exception.message}"
    render json: { error: I18n.translate("errors.record_not_found") }, status: :not_found
  end

  # Handle parameter missing errors
  def parameter_missing(exception)
    logger.error "Parameter missing: #{exception.message}"
    render json: { error: I18n.translate("errors.parameter_missing") }, status: :unprocessable_entity
  end
end
