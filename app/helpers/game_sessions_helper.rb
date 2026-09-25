module GameSessionsHelper
  def duration_label(duration)
    minutes = (duration / 60).round
    if minutes >= 60
      t("game_session.duration.hours", hours: minutes / 60, minutes: minutes % 60)
    else
      t("game_session.duration.minutes", minutes: minutes)
    end
  end

  def progress_at(scene, position)
    return "current" if position == scene.position

    position < scene.position ? "past" : "upcoming"
  end

  def finale_share_text(game_session)
    outcome = t(game_session.outcome, scope: "game_session.outcomes")
    highlights = [ game_session.title, duration_label(game_session.duration), t("game_session.rolls", count: game_session.rolls.count) ].join(" · ")

    "#{game_session.current_scene.title} — #{outcome}\n#{highlights}"
  end

  def resume_summary(game_session)
    scene = game_session.current_scene

    [ scene&.title.presence || game_session.title, scene&.location,
      l(game_session.updated_at, format: :resume) ].compact_blank.join(" · ")
  end
end
