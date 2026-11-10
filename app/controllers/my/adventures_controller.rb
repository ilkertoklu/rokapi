class My::AdventuresController < ApplicationController
  def index
    @adventures = Current.user.game_sessions.recently_finished_first.includes(players: :character)
  end

  def show
    @adventure = Current.user.game_sessions.finished.find(params[:id])
    @scenes = @adventure.scenes.chronological.includes(active_player: :user, chosen_choice: :roll)
  end
end
