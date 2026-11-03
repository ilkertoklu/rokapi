class GameSession::Card < Data.define(:place, :trouble, :figure)
  HAND = 3

  class << self
    def deal(count = HAND, to:)
      latest = to.created_game_sessions.latest
      places, troubles = fresh(GameSession::Place, latest.pluck(:place)), fresh(GameSession::Trouble, latest.pluck(:trouble))
      figures = GameSession::Figure.all.shuffle

      Array.new(count) { new(place: places[it], trouble: troubles[it], figure: figures[it]) }
    end

    private
      def fresh(catalog, used)
        catalog.all.shuffle.partition { used.exclude?(it.key) }.flatten
      end
  end

  def keys = [ place, trouble, figure ].map(&:key)
  def key = keys.join(" ")
end
