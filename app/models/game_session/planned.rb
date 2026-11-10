module GameSession::Planned
  extend ActiveSupport::Concern

  NAMES = 8

  def fresh_names
    (I18n.t("game_session.names", locale: locale) - names_in_latest_plans - players.map(&:name)).sample(NAMES)
  end

  def latest_pasts
    latest_plans.filter_map { hidden_past_in(it) }
  end

  def plan_story
    update! plan: Narrator::Planner.for(self).plan
  end

  private
    def names_in_latest_plans
      latest_plans.join(" ").scan(/[[:alpha:]]+/).uniq
    end

    def latest_plans
      creator ? creator.created_game_sessions.excluding(self).where.not(plan: nil).latest.pluck(:plan) : []
    end

    def hidden_past_in(plan)
      hidden, _people = plan.split(/\n\s*\n/).each_cons(2).find { |_, following| following.match?(/^- /) }
      hidden&.sub(/\A[^:\n]*:\**/, "")&.squish.presence
    end
end
