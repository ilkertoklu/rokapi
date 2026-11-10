class Scene::NarrateJob < NarrationJob
  def perform(scene)
    scene.narrate
  end
end
