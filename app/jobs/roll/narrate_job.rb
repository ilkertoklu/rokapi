class Roll::NarrateJob < NarrationJob
  def perform(roll)
    roll.narrate_outcome
  end
end
