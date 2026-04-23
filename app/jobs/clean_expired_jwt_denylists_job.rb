class CleanExpiredJwtDenylistsJob < ApplicationJob
  queue_as :background

  def perform
    deleted = JwtDenylist.where("exp < ?", Time.current).delete_all
    Rails.logger.info "[CleanExpiredJwtDenylistsJob] Deleted #{deleted} expired JWT denylist entries"
  end
end
