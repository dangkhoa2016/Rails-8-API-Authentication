# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  skip_before_action :assert_reset_token_passed, only: :edit

  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
  def create
    super do |resource|
      if successfully_sent?(resource)
        return render json: {
          message: find_message(:send_instructions, default: "You will receive an email with instructions on how to reset your password in a few minutes."),
          user: resource
        }, status: :ok
      else
        return render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  # GET /resource/password/edit?reset_password_token=abcdef
  #
  # This API-only application does not provide a browser password-reset form.
  # Keep this route as a safe compatibility surface for clients that arrive at
  # Devise's conventional edit path with a token.
  def edit
    token = params[:reset_password_token].to_s

    if token.blank?
      return render plain: "reset_password_token is required.", status: :unprocessable_entity
    end

    response.set_header("Cache-Control", "no-store")
    response.set_header("Pragma", "no-cache")
    response.set_header("Referrer-Policy", "no-referrer")

    render plain: PasswordResetInstructions.new(token).plain_text, content_type: "text/plain"
  end

  # PUT /resource/password
  def update
    super do |resource|
      if resource.errors.empty?
        return render json: {
          message: find_message(:updated_not_active, default: "Your password has been changed successfully."),
          user: resource
        }, status: :ok
      else
        return render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  # protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  # The path used after sending reset password instructions
  # def after_sending_reset_password_instructions_path_for(resource_name)
  #   super(resource_name)
  # end
end
