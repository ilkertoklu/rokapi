class RenameLlmCallsCostToMicrodollars < ActiveRecord::Migration[8.1]
  def change
    rename_column :llm_calls, :cost_in_microcents, :cost_in_microdollars
  end
end
