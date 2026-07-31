class GameSessionsController < ApplicationController
  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to root_path, alert: "Çok fazla macera kuruldu. Biraz bekle." }

  def new
    @mode = params[:mode].presence_in(GameSession.modes.keys)
    @adventures = Adventure.order(:id) if @mode
  end

  def create
    game_session = GameSession.create!(mode: :solo, **setup_attributes)
    redirect_to new_game_session_character_path(game_session)
  end

  def show
    @game_session = Current.user.game_sessions.find(params[:id])
    @character = @game_session.player_for(Current.user).character

    redirect_to new_game_session_character_path(@game_session) if @character.nil?
  end

  private
    def setup_attributes
      permitted = params.expect(game_session: [ :adventure_id, :tone, :length ])

      {
        adventure: Adventure.find_by(id: permitted[:adventure_id]),
        tone: permitted[:tone].presence_in(GameSession.tones.keys),
        length: permitted[:length].presence_in(GameSession.lengths.keys)
      }.compact
    end
end
