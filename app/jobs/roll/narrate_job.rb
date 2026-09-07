class Roll::NarrateJob < NarrationJob
  def perform(roll)
    roll.narrate
  end
end
