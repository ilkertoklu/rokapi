class HomeController < ApplicationController
  def show
    @resumable_game_session = Current.user.game_sessions.ongoing.order(updated_at: :desc).first
  end
end
