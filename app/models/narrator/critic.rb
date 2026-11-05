class Narrator::Critic < Narrator::Offstage
  def problems_with(plan)
    ask(plan).content.to_s.lines.map(&:strip).grep(/\A- /).map { it.delete_prefix("- ") }
  end
end
