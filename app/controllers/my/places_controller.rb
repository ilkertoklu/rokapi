class My::PlacesController < ApplicationController
  def index
    @places = GameSession::Place.all
    @adventure_counts = Current.user.game_sessions.finished.group(:place).count
  end

  def show
    @adventures = Current.user.game_sessions.finished.where(place: params[:id]).order(ended_at: :desc).includes(players: :character)
    raise ActiveRecord::RecordNotFound if @adventures.load.none?

    @place = GameSession::Place.fetch(params[:id])
    @troubles = @adventures.map { it.card.trouble }.uniq
    @figures = @adventures.map { it.card.figure }.uniq
  end
end
