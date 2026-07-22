# frozen_string_literal: true

class UsersController < ApplicationController
  include UserAccessControl

  # NOTE: index and create are implicitly admin-only.
  # Non-admin users are rejected by admin_or_current_user?
  # in UserAccessControl concern (only update/destroy/show are allowed).

  before_action :authorize_user_access
  before_action :find_user, only: %i[show update destroy toggle_status confirm_by_admin]

  # GET /users
  def index
    per_page = (params[:per_page] || 20).to_i
    per_page = [ per_page, 100 ].min
    per_page = [ per_page, 1 ].max
    @pagy, @users = pagy(:offset, User.all, limit: per_page, client_max_limit: 100)
    if stale?(@users.last)
      render json: {
        users: @users,
        meta: pagy_metadata(@pagy)
      }, status: :ok
    end
  end

  # GET /users/{username}
  def show
    if stale?(@user)
      render json: @user, status: :ok
    end
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

    if params[:id].to_i == current_user.id && update_params[:role].present? && update_params[:role] != "admin"
      return render json: { error: "Cannot demote yourself" }, status: :forbidden
    end

    if !current_user.admin? && update_params[:password].present?
      unless current_user.valid_password?(params[:user][:current_password])
        return render json: { error: "Current password is incorrect" }, status: :unprocessable_entity
      end
    end

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
    active_value = parse_boolean(params.dig(:user, :active))

    if active_value.nil?
      return render json: { error: "active must be a boolean" }, status: :unprocessable_entity
    end

    if @user.update(active: active_value)
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
    @user = if (id = Integer(params[:id], exception: false))
      User.find(id)
    elsif params[:id].to_s.include?("@")
      User.find_by!(email: params[:id])
    else
      User.find_by!(username: params[:id])
    end
  end

  def parse_boolean(value)
    case value.to_s.strip.downcase
    when "true", "yes", "y", "1", "t"
      true
    when "false", "no", "n", "0", "f"
      false
    else
      nil
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
      filtered_params[:active] = parse_boolean(active_value) unless active_value.nil?
    end

    filtered_params
  end
end
