class UsersController < ApplicationController
  include UserAccessControl

  before_action :authorize_user_access
  before_action :find_user, only: %i[show update destroy]

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
    @user.destroy
    render json: { message: I18n.t("user.deleted", email: @user.email, id: @user.id) }, status: :ok
  end

  private

  def find_user
    if params[:id]
      @user = User.find_by_id!(params[:id])
    else
      @user = User.find_by_email!(params[:email])
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: I18n.t("errors.not_found", model: User.model_name.human) }, status: :not_found
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
    end

    filtered_params
  end
end
