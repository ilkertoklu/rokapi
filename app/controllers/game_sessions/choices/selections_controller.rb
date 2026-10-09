class GameSessions::Choices::SelectionsController < ApplicationController
  include ActiveTurn

  def create
    @scene.choices.find(params[:choice_id]).choose

    respond_to do |format|
      format.html { redirect_to_game_session }
      format.json { head :no_content }
    end
  end
end
