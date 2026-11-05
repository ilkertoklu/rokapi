understudy = Rails.env.test? || Rails.configuration.x.narrator_command.present?

RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:openai, :api_key) || ("understudy" if understudy)
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key) || ("understudy" if understudy)
  config.default_model = "gpt-5-nano"
  config.openai_protocol = config.anthropic_protocol = :understudy if understudy
end

Rails.application.config.to_prepare do
  RubyLLM::Providers::OpenAI.protocol :understudy, Understudy if understudy
  RubyLLM::Providers::Anthropic.protocol :understudy, Understudy if understudy
end
