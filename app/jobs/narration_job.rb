class NarrationJob < ApplicationJob
  queue_as :narration

  rescue_from RubyLLM::Error do |error|
    arguments.first.narration_failed!
    raise error
  end

  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError,
    RubyLLM::OverloadedError, Narrator::MalformedResponse, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.arguments.first.narration_failed!
    raise error
  end
end
