class NarrationJob < ApplicationJob
  queue_as :narration
  limits_concurrency to: 1, key: ->(narratable) { narratable.game_session }, group: "Narration", duration: 15.minutes

  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError,
    RubyLLM::OverloadedError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  around_perform { |job, perform| I18n.with_locale(I18n.default_locale, &perform) }

  after_discard { |job, error| job.arguments.first&.stall_narration }
end
