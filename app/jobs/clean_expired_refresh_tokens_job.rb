# frozen_string_literal: true

class CleanExpiredRefreshTokensJob < ApplicationJob
  queue_as :default

  def perform
    deleted = RefreshToken.where("expires_at < ?", 7.days.ago)
                          .or(RefreshToken.where("revoked_at < ?", 7.days.ago))
                          .delete_all

    Rails.logger.info "[CleanExpiredRefreshTokensJob] Deleted #{deleted} expired/revoked refresh tokens"
  end
end
