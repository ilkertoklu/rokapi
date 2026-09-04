module GameSessionScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_game_session, :set_player
  end

  private
    def set_game_session
      @game_session = Current.user.game_sessions.find(params[:game_session_id])
    end

    def set_player
      @player = @game_session.player_for(Current.user)
    end

    def redirect_to_game_session
      redirect_to game_session_path(@game_session)
    end
end
