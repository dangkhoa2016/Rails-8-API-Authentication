
class ExceptionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue JWT::DecodeError => e
      handle_jwt_error(e)
    rescue JWT::ExpiredSignature => e
      handle_jwt_error(e)
    rescue JWT::VerificationError => e
      handle_jwt_error(e)
    rescue JWT::IncorrectAlgorithm => e
      handle_jwt_error(e)
    rescue JWT::ImmatureSignature => e
      handle_jwt_error(e)
    rescue JWT::InvalidIssuerError => e
      handle_jwt_error(e)
    rescue JWT::InvalidIatError => e
      handle_jwt_error(e)
    rescue JWT::InvalidAudError => e
      handle_jwt_error(e)
    rescue JWT::InvalidSubError => e
      handle_jwt_error(e)
    rescue JWT::InvalidJtiError => e
      handle_jwt_error(e)
    rescue JWT::InvalidPayload => e
      handle_jwt_error(e)
    rescue JWT::DecodeError => e
      handle_jwt_error(e)
    rescue JWT::VerificationError => e
      handle_jwt_error(e)
    rescue JWT::ExpiredSignature => e
      handle_jwt_error(e)
    rescue ActionController::RoutingError => e
      [
        404,
        { "Content-Type" => "application/json" },
        [ { error: I18n.translate("errors.route_not_found") }.to_json ]
      ]
    rescue => e
      [
        500,
        { "Content-Type" => "application/json" },
        [ { error: e.message }.to_json ]
      ]
    end
  end

  private

  def handle_jwt_error(e)
    [
      422,
      { "Content-Type" => "application/json" },
      [ { error: I18n.translate("jwt.decode_error") }.to_json ]
    ]
  end
end
