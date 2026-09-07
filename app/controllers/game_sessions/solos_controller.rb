class GameSessions::SolosController < ApplicationController
  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to root_path, alert: "Çok fazla macera kuruldu. Biraz bekle." }

  def new
  end

  def create
    game_session = GameSession.create!(game_session_params)
    redirect_to new_game_session_character_path(game_session)
  rescue ActiveRecord::RecordInvalid
    redirect_to new_game_sessions_solo_path, alert: "Kurulum geçersiz. Seçimlerini kontrol et."
  end

  private
    def game_session_params
      params.expect(game_session: [ :quest, :tone, :length ])
    end
end
