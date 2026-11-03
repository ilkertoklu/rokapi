class GameSessions::MultisController < ApplicationController
  include UsageWall

  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to root_path, alert: t(".rate_limited") }

  def new
    @cards = GameSession::Card.deal(to: Current.user)
  end

  def create
    game_session = GameSession.create!(game_session_params.merge(max_players: GameSession::PARTY_SIZE))

    respond_to do |format|
      format.html { redirect_to game_session_path(game_session) }
      format.json { render json: game_session.slice(:id, :code), status: :created, location: game_session_url(game_session) }
    end
  rescue ActiveRecord::RecordInvalid => invalid
    respond_to do |format|
      format.html { redirect_to new_game_sessions_multi_path, alert: t(".invalid") }
      format.json { render json: invalid.record.errors, status: :unprocessable_entity }
    end
  end

  private
    def game_session_params
      params.expect(game_session: [ :card, :tone, :length ])
    end
end
