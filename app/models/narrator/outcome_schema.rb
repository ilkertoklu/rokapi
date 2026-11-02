class Narrator::OutcomeSchema < Schematist::Schema
  string :resolution, description: "What the roll brought, shown to the player"
  object :effects do
    integer :hp, description: "Change in health"
    array :items_gained, description: "Items the character gains" do
      object do
        string :name, description: "The item's name"
        string :kind, enum: %w[instant passive quest],
          description: "instant: takes effect when used and is spent; passive: works in the story as long as it is carried; quest: a quest item"
        string :description, description: "What the item does, shown beside its name; empty for instant"
        integer :hp, description: "Effect on health when an instant item is used; 0 for the other kinds"
        integer :uses, description: "How many times an instant item can be used; 0 for the other kinds"
      end
    end
    array :items_lost, of: :string, description: "Names of the carried items the character loses"
    array :statuses_gained, description: "Statuses that stick to the character" do
      object do
        string :name, description: "The status's name, shown to the player"
        integer :modifier, description: "Its contribution to later rolls, -2..+2"
        integer :turns, description: "How many turns it lasts; 0 if it is tied to a condition"
        string :expires_when, description: "The condition that ends the status; empty if it is counted in turns"
      end
    end
    array :statuses_lost, of: :string, description: "Names of the status effects that end with this result"
  end
end
