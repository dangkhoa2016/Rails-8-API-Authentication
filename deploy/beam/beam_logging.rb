# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

Rails.application.config.after_initialize do
  Rails.logger.info("[beam-logging] Rails logger is writing to STDOUT") if ENV["BEAM_RAILS_LOG_PROBE"] == "true"
end
