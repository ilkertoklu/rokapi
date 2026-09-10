class GameSessions::CharactersController < ApplicationController
  include GameSessionScoped

  before_action :redirect_if_created

  def new
    @character = @player.build_character
  end

  def create
    @player.ready_up(character_params)
    redirect_to_game_session
  rescue ActiveRecord::RecordInvalid
    redirect_to new_game_session_character_path(@game_session), alert: "That character is not valid. Check your picks and how you spent your points."
  end

  private
    def redirect_if_created
      redirect_to_game_session if @player.character.present?
    end

    def character_params
      params.expect(character: [ :race, :klass, :background, stats: Character::Stat.keys ])
    end
end
