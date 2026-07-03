# frozen_string_literal: true

module UserAccessControl
  extend ActiveSupport::Concern

  private

  def authorize_user_access
    return render(json: { error: I18n.t("errors.unauthorized") }, status: :unauthorized) unless current_user
    return if current_user.admin?
    return if action_name.in?(%w[update destroy show]) &&
              current_user.id.to_s == params[:id].to_s

    render json: { error: I18n.t("errors.must_be_administrator") }, status: :unauthorized
  end
end
