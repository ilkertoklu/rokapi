class Narrator::Voice < RubyLLM::Agent
  LANGUAGES = { "en" => "English", "tr" => "Turkish" }.freeze

  inputs :locale

  def self.inherited(agent)
    super
    agent.instructions brief: -> { Narrator::Voice.trait(:brief, locale) },
      language: -> { Narrator::Voice.language(locale) }
  end

  def self.trait(name, locale)
    RubyLLM.render_prompt("narrator/voice/#{name}", language: language(locale))
  end

  def self.language(locale)
    LANGUAGES.fetch(locale.to_s)
  end
end
