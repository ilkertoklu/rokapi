class Narrator::OutcomeSchema < RubyLLM::Schema
  string :resolution, description: "1-2 short sentences working the roll into the story"
  object :effects do
    integer :hp, description: "Effect on health; from the ranges in the rules according to the grade and the kind of danger, 0 on a plain success"
    array :items_gained, description: "Items gained from where the fiction shows them (a chest, loot, a reward); empty on most turns" do
      object do
        string :name, description: "The item's name"
        string :kind, enum: %w[instant passive quest],
          description: "instant: takes effect when used and is spent; passive: works in the story as long as it is carried; quest: a quest item"
        string :description, description: "A short predicate saying what the item does, e.g. 'opens locks', 'ties to the bridge'; leave empty for instant"
        integer :hp, description: "Effect on health when an instant item is used; 0 for the other kinds"
        integer :uses, description: "How many times an instant item can be used; 0 for the other kinds"
      end
    end
    array :items_lost, of: :string, description: "Names of the items lost with this result; empty on most turns"
    array :statuses_gained, description: "Statuses that stick to the character; positive only on a critical or brilliant success, negative on heavy results — empty on most turns" do
      object do
        string :name, description: "A name stating the concrete mark left in the narration, e.g. Bleeding Shoulder, Soaked Through; never a mood adjective"
        integer :modifier, description: "Its contribution to later rolls, -2..+2"
        integer :turns, description: "How many turns it lasts; 0 if it is tied to a condition"
        string :expires_when, description: "The label of the condition that will end the status, e.g. 'until it dries'; leave empty if it is counted in turns"
      end
    end
    array :statuses_lost, of: :string, description: "Names of the status effects that end with this result"
  end
end
