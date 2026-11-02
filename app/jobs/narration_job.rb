class NarrationJob < ApplicationJob
  queue_as :narration

  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError,
    RubyLLM::OverloadedError, wait: :polynomially_longer, attempts: 3

  around_perform { |job, perform| I18n.with_locale(I18n.default_locale, &perform) }

  after_discard { |job, error| job.arguments.first.stall_narration }
end
