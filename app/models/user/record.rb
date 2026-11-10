class User::Record
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def any?
    adventures.positive?
  end

  def adventures
    tally.values.sum
  end

  def victories
    tally.sum { |(outcome, _), count| outcome == "victory" ? count : 0 }
  end

  def defeats
    tally.sum { |(outcome, _), count| outcome == "defeat" ? count : 0 }
  end

  def party_adventures
    tally.sum { |(_, max_players), count| max_players > 1 ? count : 0 }
  end

  def dice_rolled
    @dice_rolled ||= Roll.where(player: players).count
  end

  def favorite_klass
    @favorite_klass ||= Character::Klass[Character.where(player: players).group(:klass).order(Arel.sql("COUNT(*) DESC, MAX(characters.created_at) DESC")).pick(:klass)]
  end

  private
    def finished_adventures
      user.game_sessions.finished
    end

    def players
      user.players.joins(:game_session).merge(GameSession.finished)
    end

    def tally
      @tally ||= finished_adventures.group(:outcome, :max_players).count
    end
end
