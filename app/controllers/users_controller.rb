# frozen_string_literal: true

class UsersController < ApplicationController
  include UserAccessControl

  before_action :authorize_user_access
  before_action :find_user, only: %i[show update destroy toggle_status confirm_by_admin]

  # GET /users
  def index
    @users = User.all
    render json: @users, status: :ok
  end

  # GET /users/{username}
  def show
    render json: @user, status: :ok
  end

  # POST /users
  def create
    @user = User.new(user_params)
    if @user.save
      render json: @user, status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /users/{username}
  def update
    update_params = user_params.dup
    update_params.delete(:password) if update_params[:password].blank?
    update_params.delete(:password_confirmation) if update_params[:password_confirmation].blank?

    if @user.update(update_params)
      render json: @user, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /users/{username}
  def destroy
    if @user.destroy
      render json: { message: I18n.t("user.deleted", email: @user.email, id: @user.id) }, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /users/{id}/status
  def toggle_status
    active_value = params.dig(:user, :active)

    unless [ true, false, "true", "false" ].include?(active_value)
      return render json: { error: "active must be a boolean" }, status: :unprocessable_entity
    end

    if @user.update(active: ActiveModel::Type::Boolean.new.cast(active_value))
      render json: @user, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /users/{id}/confirm_by_admin
  def confirm_by_admin
    if @user.update(confirmed_at: Time.current, active: true)
      render json: @user, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def find_user
    @user = if params[:id].to_s.match?(/\A\d+\z/)
      User.find(params[:id])
    elsif params[:id].to_s.include?("@")
      User.find_by!(email: params[:id])
    else
      User.find_by!(username: params[:id])
    end
  end

  def user_params
    filtered_params = params.require(:user).permit(
      :first_name, :last_name,
      :username, :email,
      :password, :password_confirmation
    )

    if current_user.admin?
      role = params.dig(:user, :role)
      filtered_params[:role] = role if role.present?
      active_value = params.dig(:user, :active)
      filtered_params[:active] = ActiveModel::Type::Boolean.new.cast(active_value) unless active_value.nil?
    end

    filtered_params
  end
end
