class GameSessions::Items::UsesController < ApplicationController
  include ActiveTurn

  rescue_from Item::Unusable, with: :redirect_to_game_session

  def create
    @item = @player.character.items.usable.find(params[:item_id])
    @restored = @item.use
  end
end
