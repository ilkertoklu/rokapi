class GameSessions::CharactersController < ApplicationController
  include GameSessionScoped

  before_action :redirect_if_created

  def new
    @character = @player.build_character
  end

  def create
    @player.ready_up(character_params)

    respond_to do |format|
      format.html { redirect_to_game_session }
      format.json { head :created, location: game_session_url(@game_session) }
    end
  rescue ActiveRecord::RecordInvalid => invalid
    respond_to do |format|
      format.html { redirect_to new_game_session_character_path(@game_session), alert: t(".invalid") }
      format.json { render json: invalid.record.errors, status: :unprocessable_entity }
    end
  end

  private
    def redirect_if_created
      redirect_to_game_session if @player.character.present?
    end

    def character_params
      params.expect(character: [ :race, :klass, :background, stats: Character::Stat.keys ])
    end
end
