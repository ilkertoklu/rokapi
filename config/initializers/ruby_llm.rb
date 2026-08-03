require "ruby_llm/schema"

RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:openai, :api_key)
  config.default_model = "gpt-5.1"
  config.use_new_acts_as = true
end

Rails.application.config.x.llm.helper_model = "gpt-5-mini"
