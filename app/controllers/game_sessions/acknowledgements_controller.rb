class GameSessions::AcknowledgementsController < ApplicationController
  include ActiveTurn

  def create
    @game_session.unseen_roll&.acknowledge

    redirect_to_game_session
  end
end
