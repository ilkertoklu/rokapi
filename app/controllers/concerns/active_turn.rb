module ActiveTurn
  extend ActiveSupport::Concern

  included do
    before_action :set_active_turn
    rescue_from Scene::OutOfTurn, ActiveRecord::RecordNotUnique, with: :redirect_to_game_session
  end

  private
    def set_active_turn
      @game_session = Current.user.game_sessions.find(params[:game_session_id])
      @player = @game_session.player_for(Current.user)
      @scene = @game_session.current_scene

      head :forbidden unless @scene && @scene.active_player == @player
    end

    def redirect_to_game_session
      redirect_to game_session_path(@game_session)
    end
end
