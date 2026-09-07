class Scene::NarrateJob < NarrationJob
  limits_concurrency to: 1, key: ->(scene) { scene.game_session }

  def perform(scene)
    scene.narrate
  end
end
