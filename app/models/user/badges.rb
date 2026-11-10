class User::Badges
  include Enumerable

  def initialize(user)
    @user = user
  end

  def each(&)
    Badge.all.select { firsts.key?(it) }.each(&)
  end

  def first_earned_in(game_session)
    Badge.all.select { firsts[it] == game_session.id }
  end

  private
    attr_reader :user

    def firsts
      @firsts ||= adventures.each_with_object({}) do |adventure, firsts|
        adventure.badges.each { firsts[it] ||= adventure.game_session.id }
      end
    end

    def adventures
      game_sessions.each_with_index.map do |game_session, index|
        Adventure.new game_session, player: game_session.players.find { it.user_id == user.id },
          rolls: rolls.fetch(game_session.id, []), item_used: items_used.include?(game_session.id), earlier: game_sessions.first(index)
      end
    end

    def game_sessions
      @game_sessions ||= user.game_sessions.finished.order(:ended_at).eager_load(players: :character).to_a
    end

    def rolls
      @rolls ||= Roll.joins(choice: :scene).where(scenes: { game_session_id: game_sessions })
        .select(:player_id, :value, :success, "scenes.game_session_id", "scenes.finale").group_by(&:game_session_id)
    end

    def items_used
      @items_used ||= Item.where.not(used_at: nil).joins(character: :player).where(players: { game_session_id: game_sessions })
        .distinct.pluck("players.game_session_id").to_set
    end
end
