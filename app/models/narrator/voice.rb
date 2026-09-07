class Narrator::Voice < RubyLLM::Agent
  instructions identity: -> { Narrator::Voice.trait(:identity) },
    language_rules: -> { Narrator::Voice.trait(:language_rules) }

  def self.trait(name)
    render_prompt(name, chat: nil, inputs: {}, locals: {})
  end
end
