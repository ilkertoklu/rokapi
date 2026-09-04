class GameSessionsController < ApplicationController
  def show
    @game_session = Current.user.game_sessions.find(params[:id])
    @character = @game_session.player_for(Current.user).character

    redirect_to new_game_session_character_path(@game_session) if @character.nil?
  end
end
