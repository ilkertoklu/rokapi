class GameSessions::SolosController < ApplicationController
  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to root_path, alert: "Too many adventures started. Wait a little." }

  def new
  end

  def create
    game_session = GameSession.create!(game_session_params)
    redirect_to new_game_session_character_path(game_session)
  rescue ActiveRecord::RecordInvalid
    redirect_to new_game_sessions_solo_path, alert: "That setup is not valid. Check your picks."
  end

  private
    def game_session_params
      params.expect(game_session: [ :quest, :tone, :length ])
    end
end
