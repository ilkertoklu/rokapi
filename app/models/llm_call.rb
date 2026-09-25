class LlmCall < ApplicationRecord
  belongs_to :game_session

  enum :purpose, %w[plan scene outcome].index_by(&:itself)

  def self.record(game_session:, purpose:, response:)
    create!(
      game_session: game_session,
      purpose: purpose,
      model: response.model,
      input_tokens: response.tokens.input.to_i,
      output_tokens: response.tokens.output.to_i,
      cost_in_microdollars: (response.cost.total * 1_000_000).round
    )
  end
end
