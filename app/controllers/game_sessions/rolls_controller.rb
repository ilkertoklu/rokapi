class GameSessions::RollsController < ApplicationController
  include ActiveTurn

  def create
    @scene.roll! by: @player

    redirect_to_game_session
  end
end
