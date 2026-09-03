class GameSessionsController < ApplicationController
  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to root_path, alert: "Çok fazla macera kuruldu. Biraz bekle." }

  def new
    if params[:mode].presence_in(GameSession.modes.keys)
      @adventures = Adventure.order(:id)
    else
      render :modes
    end
  end

  def create
    game_session = GameSession.create!(mode: :solo, **game_session_params)
    redirect_to new_game_session_character_path(game_session)
  end

  def show
    @game_session = Current.user.game_sessions.find(params[:id])
    @character = @game_session.player_for(Current.user).character

    redirect_to new_game_session_character_path(@game_session) if @character.nil?
  end

  private
    def game_session_params
      params.expect(game_session: [ :adventure_id, :tone, :length ])
    end
end
