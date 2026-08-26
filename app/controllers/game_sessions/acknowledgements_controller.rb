class GameSessions::AcknowledgementsController < ApplicationController
  include ActiveTurn

  def create
    @game_session.acknowledge_roll

    redirect_to_game_session
  end
end
