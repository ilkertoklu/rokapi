class GameSessions::SolosController < ApplicationController
  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to root_path, alert: t(".rate_limited") }

  def new
  end

  def create
    game_session = GameSession.create!(game_session_params)

    respond_to do |format|
      format.html { redirect_to new_game_session_character_path(game_session) }
      format.json { head :created, location: game_session_url(game_session) }
    end
  rescue ActiveRecord::RecordInvalid => invalid
    respond_to do |format|
      format.html { redirect_to new_game_sessions_solo_path, alert: t(".invalid") }
      format.json { render json: invalid.record.errors, status: :unprocessable_entity }
    end
  end

  private
    def game_session_params
      params.expect(game_session: [ :quest, :tone, :length ])
    end
end
