class User::Badges::Adventure
  attr_reader :game_session

  def initialize(game_session, player:, rolls:, item_used:, earlier:)
    @game_session, @player, @rolls, @item_used, @earlier = game_session, player, rolls, item_used, earlier
  end

  def badges
    Badge.all.select { public_send("#{it.key}?") }
  end

  def natural_twenty_finale?
    victory? && finale_rolled?(Roll::DIE)
  end

  def last_health?
    victory? && player.character&.hp == 1
  end

  def whole_party?
    party.size == GameSession::PARTY_SIZE && party.none?(&:fallen?)
  end

  def surprise?
    game_session.surprise?
  end

  def won_back?
    victory? && earlier.any? { it.place == game_session.place && it.outcome_defeat? }
  end

  def no_items?
    victory? && game_session.long? && !item_used
  end

  def two_twenties?
    rolls.count { it.player_id == player.id && it.value == Roll::DIE } >= 2
  end

  def every_roll?
    rolls.any? && rolls.all?(&:success?)
  end

  def natural_one_finale?
    game_session.outcome_defeat? && finale_rolled?(1)
  end

  def fallen_hero?
    victory? && game_session.multiplayer? && party.any?(&:fallen?)
  end

  private
    attr_reader :player, :rolls, :item_used, :earlier

    def victory?
      game_session.outcome_victory?
    end

    def party
      game_session.players
    end

    def finale_rolled?(value)
      rolls.any? { it.finale? && it.player_id == player.id && it.value == value }
    end
end
