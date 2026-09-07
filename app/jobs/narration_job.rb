class NarrationJob < ApplicationJob
  queue_as :narration

  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError,
    RubyLLM::OverloadedError, Narrator::MalformedResponse, wait: :polynomially_longer, attempts: 3

  after_discard { |job, error| job.arguments.first.stall_narration }
end
