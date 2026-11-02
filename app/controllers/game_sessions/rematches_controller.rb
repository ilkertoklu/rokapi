class GameSessions::RematchesController < ApplicationController
  include GameSessionScoped

  before_action :ensure_finished_party, :stop_at_usage_wall

  def create
    rematch = @game_session.start_rematch(by: Current.user)

    respond_to do |format|
      format.html { redirect_to game_session_path(rematch) }
      format.json { head :created, location: game_session_url(rematch) }
    end
  end

  private
    def ensure_finished_party
      head :conflict unless @game_session.multiplayer? && @game_session.finished?
    end

    def stop_at_usage_wall
      if @game_session.rematch.nil? && Current.user.out_of_usage?
        respond_to do |format|
          format.html { redirect_to new_game_sessions_multi_path }
          format.json { render "plans/wall", status: :payment_required }
        end
      end
    end
end
