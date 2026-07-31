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
end
