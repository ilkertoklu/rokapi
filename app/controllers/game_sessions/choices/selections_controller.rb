class GameSessions::Choices::SelectionsController < ApplicationController
  include ActiveTurn

  def create
    @scene.choices.find(params[:choice_id]).choose

    redirect_to_game_session
  end
end
