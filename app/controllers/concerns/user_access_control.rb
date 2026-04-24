module UserAccessControl
  extend ActiveSupport::Concern

  private

  def authorize_user_access
    if current_user.blank?
      return render json: { error: I18n.t("errors.unauthorized") }, status: :unauthorized
    end

    return if admin_or_current_user?

    render json: { error: I18n.t("errors.must_be_administrator") }, status: :unauthorized
  end

  def admin_or_current_user?
    return true if current_user.admin?
    return false unless action_name.in?(%w[update destroy show])

    current_user.id.to_s == params[:id].to_s
  end
end
