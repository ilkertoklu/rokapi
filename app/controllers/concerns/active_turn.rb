module ActiveTurn
  extend ActiveSupport::Concern
  include GameSessionScoped

  included do
    before_action :refuse_finished_game, if: -> { @game_session.finished? }
    before_action :ensure_active_turn
    rescue_from Scene::OutOfTurn, ActiveRecord::RecordNotUnique, with: :refuse_move
  end

  private
    def ensure_active_turn
      @scene = @game_session.current_scene

      head :forbidden unless @scene&.turn_of?(@player)
    end

    def refuse_finished_game
      respond_to do |format|
        format.html { redirect_to_game_session }
        format.json { render json: { error: t("game_sessions.over") }, status: :conflict }
      end
    end

    def refuse_move
      respond_to do |format|
        format.html { redirect_to_game_session }
        format.json { head :conflict }
      end
    end
end
