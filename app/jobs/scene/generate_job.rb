class Scene::GenerateJob < NarrationJob
  limits_concurrency to: 1, key: ->(game_session) { game_session }

  def perform(game_session)
    game_session.continue_narration
  end
end
