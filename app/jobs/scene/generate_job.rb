class Scene::GenerateJob < NarrationJob
  def perform(game_session)
    game_session.continue_narration
  end
end
