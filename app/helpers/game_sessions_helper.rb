module GameSessionsHelper
  def duration_label(duration)
    minutes = (duration / 60).round
    minutes >= 60 ? "#{minutes / 60}h #{minutes % 60}m" : "#{minutes} min"
  end

  def progress_at(scene, position)
    return "current" if position == scene.position

    position < scene.position ? "past" : "upcoming"
  end

  def finale_share_text(game_session)
    outcome = game_session.outcome_victory? ? "Victory" : "Defeat"
    highlights = [ game_session.title, duration_label(game_session.duration), pluralize(game_session.rolls.count, "roll") ].join(" · ")

    "#{game_session.current_scene.title} — #{outcome}\n#{highlights}"
  end

  def resume_summary(game_session)
    scene = game_session.current_scene

    [ scene&.title.presence || game_session.title, scene&.location,
      game_session.updated_at.strftime("%b %-d, %H:%M") ].compact_blank.join(" · ")
  end
end
