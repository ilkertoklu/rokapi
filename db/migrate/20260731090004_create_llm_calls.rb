class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_calls do |t|
      t.references :game_session, null: false, foreign_key: true
      t.string :purpose, null: false
      t.string :model, null: false
      t.integer :input_tokens, null: false
      t.integer :output_tokens, null: false
      t.integer :cost_in_microcents, null: false

      t.timestamps
    end
  end
end
