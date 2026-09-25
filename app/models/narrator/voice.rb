class Narrator::Voice < RubyLLM::Agent
  def self.inherited(agent)
    super
    agent.instructions identity: -> { Narrator::Voice.trait(:identity) },
      language_rules: -> { Narrator::Voice.trait(:language_rules) }
  end

  def self.trait(name)
    RubyLLM.render_prompt("narrator/voice/#{name}")
  end
end
