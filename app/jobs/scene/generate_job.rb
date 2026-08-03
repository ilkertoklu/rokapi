class Scene::GenerateJob < ApplicationJob
  queue_as :narration

  retry_on RubyLLM::Error, Narrator::MalformedResponse, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.arguments.first.narration_failed!
    raise error
  end

  def perform(game_session)
    game_session.continue_narration
  end
end
