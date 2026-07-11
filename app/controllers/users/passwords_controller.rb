# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
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
  # def edit
  #   super
  # end

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
