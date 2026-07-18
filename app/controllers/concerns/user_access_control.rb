# frozen_string_literal: true

module UserAccessControl
  extend ActiveSupport::Concern

  private

  def require_authenticated_user
    return if current_user.present?

    render json: { error: I18n.t("errors.unauthorized") }, status: :unauthorized
  end

  def authorize_user_access
    return if performed?
    return if current_user.admin?
    return if self_service_action? && @user.present? && current_user.id == @user.id

    render json: { error: I18n.t("errors.must_be_administrator") }, status: :forbidden
  end

  def self_service_action?
    action_name.in?(%w[update destroy show])
  end
end
