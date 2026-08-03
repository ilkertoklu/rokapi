class GameSessions::NarrationsController < ApplicationController
  include ActiveTurn

  def create
    @game_session.resume_narration!

    redirect_to_game_session
  end
end
