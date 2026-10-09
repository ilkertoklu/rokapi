class GameSessions::NarrationsController < ApplicationController
  include ActiveTurn

  def create
    @game_session.resume_narration

    respond_to do |format|
      format.html { redirect_to_game_session }
      format.json { head :no_content }
    end
  end
end
