class GameSessionsController < ApplicationController
  def show
    @game_session = Current.user.game_sessions.find(params[:id])
    @player = @game_session.player_for(Current.user)
    @character = @player.character

    respond_to do |format|
      format.html { redirect_to new_game_session_character_path(@game_session) if @character.nil? }
      format.json
    end
  end
end
