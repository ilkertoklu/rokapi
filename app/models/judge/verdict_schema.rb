class Judge::VerdictSchema < Schematist::Schema
  string :better, enum: %w[first second], description: "The playthrough that was the better story to have played"
  string :confidence, enum: %w[low medium high], description: "How sure you are"
  string :reason, description: "Why, in a few sentences"
  string :improvement, description: "The single change that would most improve the other playthrough"
end
