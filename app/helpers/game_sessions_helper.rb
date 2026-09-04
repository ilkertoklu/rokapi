module GameSessionsHelper
  def duration_label(duration)
    minutes = (duration / 60).round
    minutes >= 60 ? "#{minutes / 60}sa #{minutes % 60}dk" : "#{minutes}dk"
  end

  def progress_at(scene, position)
    return "current" if position == scene.position

    position < scene.position ? "past" : "upcoming"
  end

  def finale_share_text(game_session)
    outcome = game_session.outcome_victory? ? "Zafer" : "Yenilgi"
    highlights = [ game_session.title, duration_label(game_session.duration), "#{game_session.rolls.count} zar" ].join(" · ")

    "#{game_session.current_scene.title} — #{outcome}\n#{highlights}"
  end

  def resume_summary(game_session)
    scene = game_session.current_scene

    [ scene&.title.presence || game_session.title, scene&.location,
      game_session.updated_at.strftime("%d.%m %H:%M") ].compact_blank.join(" · ")
  end
end
