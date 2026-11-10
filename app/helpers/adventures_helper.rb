module AdventuresHelper
  def adventure_hero(adventure)
    adventure.players.find { it.user_id == Current.user.id }&.character
  end

  def adventure_summary(adventure)
    [ l(adventure.ended_at.to_date, format: :played), adventure_hero(adventure)&.summary ].compact.join(" · ")
  end
end
