class AllowUnknownLlmCallUsage < ActiveRecord::Migration[8.1]
  def change
    change_column_null :llm_calls, :input_tokens, true
    change_column_null :llm_calls, :output_tokens, true
    change_column_null :llm_calls, :cost_in_microdollars, true
  end
end
