# frozen_string_literal: true

class UsersController < ApplicationController
  include UserAccessControl

  # NOTE: index and create are implicitly admin-only.
  # Non-admin users are rejected by admin_or_current_user?
  # in UserAccessControl concern (only update/destroy/show are allowed).

  before_action :authorize_user_access
  before_action :find_user, only: %i[show update destroy toggle_status]

  # GET /users
  def index
    per_page = [ (params[:per_page] || 20).to_i, 1 ].max
    per_page = [ per_page, 100 ].min
    safe_columns = %i[id email username first_name last_name role active confirmed_at created_at unconfirmed_email]
    @pagy, @users = pagy(
      User.select(*safe_columns),
      limit: per_page,
      max_limit: 100
    )

    collection_updated_at = User.maximum(:updated_at)&.utc
    collection_count = User.count
    last_modified = collection_updated_at || Time.at(0).utc
    etag = [
      "users-index",
      collection_count,
      collection_updated_at&.iso8601(6) || "0",
      @pagy.page,
      @pagy.limit
    ]

    if stale?(etag: etag, last_modified: last_modified)
      render json: {
        users: @users,
        meta: pagy_from_metadata(@pagy)
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
    if @user.id == current_user.id && user_params[:role].present? && user_params[:role] != "admin"
      return render json: { error: I18n.t("user.cannot_demote_yourself") }, status: :unprocessable_entity
    end

    update_params = user_params.dup
    update_params.delete(:password) if update_params[:password].blank?
    update_params.delete(:password_confirmation) if update_params[:password_confirmation].blank?

    if update_params[:password].present? && @user.id == current_user.id
      unless @user.valid_password?(params[:current_password])
        return render json: { error: I18n.t("user.current_password_incorrect") }, status: :unprocessable_entity
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
      return render json: { error: I18n.t("user.active_must_be_boolean") }, status: :unprocessable_entity
    end

    if @user.update(active: active_value)
      render json: @user, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def find_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t("errors.not_found", model: User.model_name.human) }, status: :not_found
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
      filtered_params[:role] = role if role.present? && User.roles.key?(role)
      active_value = params.dig(:user, :active)
      filtered_params[:active] = parse_boolean(active_value) unless active_value.nil?
    end

    filtered_params
  end
end
