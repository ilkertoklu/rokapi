class Narrator::BibleSchema < RubyLLM::Schema
  string :title, description: "The adventure's name, 2-4 words; on a ready-made quest, the quest's name"
  string :premise, description: "The world and the quest in 2 sentences: where it is, what is at stake, why the player is here"
  string :personal_stake, description: "The personal reason tying the player's character to this quest, derived from their race, class and background, 1-2 sentences"
  object :antagonist, description: "The real opposing force: someone or something with a face" do
    string :name, description: "Their name"
    string :want, description: "What they want and why they believe they are right"
    string :method, description: "How they work and who they use"
    string :first_sign, description: "The trace felt in the early scenes but not yet named"
  end
  object :ally, description: "Someone standing with the player who has troubles of their own" do
    string :name, description: "Their name"
    string :want, description: "What they want"
    string :secret, description: "What they hide and what will come out in the story"
  end
  string :twist, description: "The fact taken as known that inverts at the midpoint, 1-2 sentences"
  array :beats, of: :string, description: "Scene by scene beats, to the requested count: each line says what happens in that scene and what changes; the last line is the finale"
  string :finale_question, description: "The single question the finale answers"
  string :victory, description: "The condition for victory and its closing image"
  string :defeat, description: "The condition for defeat and its closing image"
end
