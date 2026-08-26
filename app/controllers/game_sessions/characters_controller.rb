class GameSessions::CharactersController < ApplicationController
  before_action :set_game_session_and_player
  before_action :redirect_if_created

  def new
    @character = @player.build_character(race: "human", klass: "warrior", background: "soldier")
    @base_stats = Character.base_stats_for(@character.klass)
  end

  def create
    @player.ready_up(character_params)
    redirect_to game_session_path(@game_session)
  rescue ActiveRecord::RecordInvalid
    redirect_to new_game_session_character_path(@game_session), alert: "Karakter geçersiz. Seçimlerini ve puan dağılımını kontrol et."
  end

  private
    def set_game_session_and_player
      @game_session = Current.user.game_sessions.find(params[:game_session_id])
      @player = @game_session.player_for(Current.user)
    end

    def redirect_if_created
      redirect_to game_session_path(@game_session) if @player.character.present?
    end

    def character_params
      params.expect(character: [ :race, :klass, :background, stats: Character::STAT_KEYS ])
    end
end
