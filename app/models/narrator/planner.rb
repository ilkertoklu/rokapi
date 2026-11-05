class Narrator::Planner < Narrator::Offstage
  REWRITES = 1

  Pass = Data.define(:plan, :problems)

  def plan
    passes.last.plan
  end

  def passes
    passes = [ critiqued(ask("Write the plan.").content) ]

    while passes.last.problems.any? && passes.size <= REWRITES
      passes << critiqued(ask(rewrite_cue(passes.last.problems)).content)
    end

    passes
  end

  private
    def critiqued(reply)
      plan = reply.to_s.strip
      raise Narrator::MalformedResponse, "the plan is empty" if plan.empty?

      problems = Narrator::Critic.for(game_session).problems_with(plan)
      Rails.logger.info "The critic found #{problems.size} problems in the plan: #{problems.join(" / ")}"

      Pass.new(plan: plan, problems: problems)
    end

    def rewrite_cue(problems)
      "A reader found these problems in the plan:\n#{problems.map { "- #{it}" }.join("\n")}\nWrite the whole plan again with them fixed, and reply with the plan only."
    end
end
