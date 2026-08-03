class GameSessions::ChosenChoicesController < ApplicationController
  include ActiveTurn

  def create
    @scene.choices.find(params.expect(:choice_id)).choose!

    redirect_to_game_session
  end
end
