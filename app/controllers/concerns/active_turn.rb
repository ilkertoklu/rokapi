module ActiveTurn
  extend ActiveSupport::Concern
  include GameSessionScoped

  included do
    before_action :refuse_move, if: -> { @game_session.finished? }
    before_action :ensure_active_turn
    rescue_from Scene::OutOfTurn, ActiveRecord::RecordNotUnique, with: :refuse_move
  end

  private
    def ensure_active_turn
      @scene = @game_session.current_scene

      head :forbidden unless @scene&.turn_of?(@player)
    end

    def refuse_move
      respond_to do |format|
        format.html { redirect_to_game_session }
        format.json { head :conflict }
      end
    end
end
