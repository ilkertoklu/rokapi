class NarrationJob < ApplicationJob
  queue_as :narration

  self.enqueue_after_transaction_commit = true

  rescue_from RubyLLM::Error, RubyLLM::ModelNotFoundError do |error|
    arguments.first.stall_narration
    raise error
  end

  retry_on RubyLLM::RateLimitError, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError,
    RubyLLM::OverloadedError, Narrator::MalformedResponse, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.arguments.first.stall_narration
    raise error
  end
end
