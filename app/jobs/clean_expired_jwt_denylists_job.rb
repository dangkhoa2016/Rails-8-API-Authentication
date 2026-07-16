# frozen_string_literal: true

class CleanExpiredJwtDenylistsJob < ApplicationJob
  queue_as :background

  def perform
    deleted = JwtDenylist.delete_expired!
    Rails.logger.info "[CleanExpiredJwtDenylistsJob] Deleted #{deleted} expired JWT denylist entries"
  end
end
