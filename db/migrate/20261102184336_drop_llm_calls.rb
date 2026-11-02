class DropLlmCalls < ActiveRecord::Migration[8.1]
  def change
    drop_table :llm_calls do |t|
      t.references :game_session, null: false, foreign_key: true
      t.string :purpose, null: false
      t.string :model, null: false
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cost_in_microdollars
      t.timestamps
    end
  end
end
