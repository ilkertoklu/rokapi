class GameSessions::AcknowledgementsController < ApplicationController
  include ActiveTurn

  def create
    @scene.roll&.acknowledge

    redirect_to_game_session
  end
end
