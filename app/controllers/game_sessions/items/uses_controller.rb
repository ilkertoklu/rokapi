class GameSessions::Items::UsesController < ApplicationController
  include ActiveTurn

  rescue_from Item::Unusable, with: :refuse_move

  def create
    @item = @player.character.items.usable.find(params[:item_id])
    @restored = @item.use

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
