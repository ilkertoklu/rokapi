module GameSessionsHelper
  SOLO_DURATIONS = { "short" => "~15 dk", "medium" => "~30 dk", "long" => "~60 dk" }.freeze

  def tone_label(tone)
    GameSession::TONES.fetch(tone)
  end

  def solo_duration(length)
    SOLO_DURATIONS.fetch(length)
  end

  def solo_length_label(length)
    "#{GameSession::LENGTHS.fetch(length)} · #{solo_duration(length)}"
  end

  def duration_label(duration)
    minutes = (duration / 60).round
    minutes >= 60 ? "#{minutes / 60}sa #{minutes % 60}dk" : "#{minutes}dk"
  end

  def resume_summary(game_session)
    scene = game_session.current_scene

    [ scene&.title.presence || game_session.title, scene&.location,
      game_session.updated_at.strftime("%d.%m %H:%M") ].compact_blank.join(" · ")
  end
end
