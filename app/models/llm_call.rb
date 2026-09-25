class LlmCall < ApplicationRecord
  belongs_to :game_session

  enum :purpose, %w[plan scene outcome].index_by(&:itself)

  def self.record(game_session:, purpose:, response:)
    create!(
      game_session: game_session,
      purpose: purpose,
      model: response.model,
      input_tokens: response.tokens.input,
      output_tokens: response.tokens.output,
      cost_in_microdollars: microdollars(response.cost.total)
    )
  end

  def self.microdollars(dollars)
    (dollars * 1_000_000).round if dollars
  end
  private_class_method :microdollars
end
