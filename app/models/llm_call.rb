class LlmCall < ApplicationRecord
  belongs_to :game_session

  enum :purpose, %w[plan scene outcome].index_by(&:itself)

  def self.record(game_session:, purpose:, response:)
    create!(
      game_session: game_session,
      purpose: purpose,
      model: response.model_id,
      input_tokens: response.input_tokens.to_i,
      output_tokens: response.output_tokens.to_i,
      cost_in_microdollars: microdollars_for(response)
    )
  end

  def self.microdollars_for(response)
    cost = RubyLLM.models.find(response.model_id).cost_for(response)
    (cost.total.to_f * 1_000_000).round
  end
end
