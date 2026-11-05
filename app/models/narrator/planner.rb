class Narrator::Planner < Narrator::Offstage
  REWRITES = 1

  Pass = Data.define(:plan, :problems)

  def self.rehearse(card:, twist:, tone:, length:, locale:, heroes:)
    game_session = GameSession.new(card: card, twist: twist, tone: tone, length: length, locale: locale)
    heroes.each { |hero| game_session.players.build(user: User.new(name: hero[:name])).build_character(hero.except(:name)) }

    self.for(game_session).passes
  end

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
      "A reader found these problems in the plan:\n#{problems.map { "- #{it}" }.join("\n")}\nWrite the whole plan again with them fixed by cutting or simplifying, adding no new people, objects or past events, and reply with the plan only."
    end
end
