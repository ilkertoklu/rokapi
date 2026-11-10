class GameSessions::RematchesController < ApplicationController
  include GameSessionScoped

  before_action :ensure_rematchable, :ensure_rematch_allowance

  def create
    rematch = @game_session.start_rematch(by: Current.user)

    respond_to do |format|
      format.html { redirect_to game_session_path(rematch) }
      format.json { head :created, location: game_session_url(rematch) }
    end
  end

  private
    def ensure_rematchable
      unless @game_session.rematchable?
        respond_to do |format|
          format.html { redirect_to_game_session }
          format.json { head :conflict }
        end
      end
    end

    def ensure_rematch_allowance
      unless Current.user.can_rematch?(@game_session)
        respond_to do |format|
          format.html { redirect_to new_game_sessions_multi_path }
          format.json { render "plans/wall", status: :payment_required }
        end
      end
    end
end
