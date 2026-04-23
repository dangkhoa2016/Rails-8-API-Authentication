class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  respond_to :json
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Catch all types of errors and display messages to the user
  rescue_from StandardError, with: :handle_internal_error
  rescue_from JWT::DecodeError, with: :handle_invalid_token
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  # rescue_from ActionController::RoutingError, with: :route_not_found
  rescue_from ActionController::UnknownFormat, with: :route_not_found

  def decode_token(token_string)
    begin
       Warden::JWTAuth::TokenDecoder.new.call token_string
    rescue => e
      config = [ Warden::JWTAuth.config.secret, false ]
      JWT.decode(token_string, *config, {
        algorithm: Warden::JWTAuth.config.algorithm,
        verify_jti: true
      })
    end
  end

  # Handle errors for path not found
  def route_not_found
    logger.error "Route not found: #{request.url}"
    render json: { error: I18n.translate("errors.route_not_found") }, status: 404
  end

  private

  def configure_permitted_parameters
    fields = [ :first_name, :last_name, :username, :email, :password, :password_confirmation ]
    devise_parameter_sanitizer.permit(:sign_up, keys: fields)
    devise_parameter_sanitizer.permit(:account_update, keys: fields)
    # devise_parameter_sanitizer.permit(:account_update, keys: fields + [:current_password])
  end

   # Handle internal errors
   def handle_internal_error(exception)
    logger.error "Internal error: #{exception.message}\n#{Array(exception.backtrace).join("\n")}"
    render json: { error: I18n.translate("errors.internal_error") }, status: 500
  end

  def handle_invalid_token(exception)
    logger.error "Invalid token: #{exception.message}"
    render json: { error: I18n.translate("jwt.decode_error") }, status: :unprocessable_entity
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
