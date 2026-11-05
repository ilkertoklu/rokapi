module LobbyHelper
  def lobby_meta(game_session)
    t("game_sessions.lobby.meta", players: game_session.max_players,
      estimate: GameSession::Length.fetch(game_session.length).estimate,
      tone: GameSession::Tone.fetch(game_session.tone).label.downcase)
  end

  def lobby_player_line(player, you:)
    if player.character
      [ Character::Race.fetch(player.character.race).label, Character::Klass.fetch(player.character.klass).label ].join(" · ")
    elsif you
      t("game_sessions.lobby.no_character_yet")
    elsif player != player.game_session.host && player.created_at.after?(1.minute.ago)
      t("game_sessions.lobby.just_joined")
    else
      t("game_sessions.lobby.choosing")
    end
  end

  def lobby_player_status(player, you:)
    if player.ready?
      t("game_sessions.lobby.ready")
    elsif you
      t("game_sessions.lobby.missing_character")
    else
      t("game_sessions.lobby.preparing")
    end
  end
end
