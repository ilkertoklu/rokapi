class GameSessions::JoinsController < ApplicationController
  rate_limit to: 10, within: 5.minutes, only: :create, by: -> { Current.user.id },
    with: -> { redirect_to new_game_sessions_join_path, alert: t(".rate_limited") }

  def new
  end

  def create
    @code = params.expect(:code)
    game_session = GameSession.open_for_join(@code)
    game_session.join(Current.user)

    respond_to do |format|
      format.html { redirect_to game_session_path(game_session) }
      format.json { head :created, location: game_session_url(game_session) }
    end
  rescue GameSession::NotFound
    refuse :not_found
  rescue GameSession::Full
    refuse :full, max: game_session.max_players
  end

  private
    def refuse(reason, **details)
      @rejection = reason
      @rejection_details = details

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: t("game_sessions.joins.new.#{reason}.title", **details) }, status: :unprocessable_entity }
      end
    end
end
