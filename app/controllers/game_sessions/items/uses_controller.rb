class GameSessions::Items::UsesController < ApplicationController
  include ActiveTurn

  rescue_from Item::Unusable, with: :redirect_to_game_session

  def create
    @item = @player.character.items.usable.find(params[:item_id])
    @hp_before = @player.character.hp
    @item.use!
  end
end
