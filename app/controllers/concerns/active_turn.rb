module ActiveTurn
  extend ActiveSupport::Concern
  include GameSessionScoped

  included do
    before_action :ensure_active_turn
    rescue_from Scene::OutOfTurn, ActiveRecord::RecordNotUnique, with: :redirect_to_game_session
  end

  private
    def ensure_active_turn
      @scene = @game_session.current_scene

      head :forbidden unless @scene && @scene.active_player == @player
    end
end
