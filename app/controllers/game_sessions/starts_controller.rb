class GameSessions::StartsController < ApplicationController
  include GameSessionScoped

  def create
    @game_session.start(by: @player)

    respond_to do |format|
      format.html { redirect_to_game_session }
      format.json { head :created, location: game_session_url(@game_session) }
    end
  rescue GameSession::NotReady
    respond_to do |format|
      format.html { redirect_to game_session_path(@game_session), alert: t(".not_ready") }
      format.json { render json: { error: t(".not_ready") }, status: :unprocessable_entity }
    end
  end
end
