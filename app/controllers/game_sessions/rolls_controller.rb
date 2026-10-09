class GameSessions::RollsController < ApplicationController
  include ActiveTurn

  def create
    @scene.roll_dice by: @player

    respond_to do |format|
      format.html { redirect_to_game_session }
      format.json { head :no_content }
    end
  end
end
