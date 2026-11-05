class GameSession::Card < Data.define(:place, :trouble, :figure)
  HAND = 3

  class << self
    def deal(count = HAND, to:)
      latest = to.created_game_sessions.latest
      latest_places, latest_troubles = latest.pluck(:place), latest.pluck(:trouble)

      fresh(GameSession::Place.keys, latest_places).first(count).each_with_object([]) do |key, hand|
        place = GameSession::Place.fetch(key)
        trouble = fresh(place.troubles - hand.map { it.trouble.key }, latest_troubles).first
        figure = fresh(place.figures, hand.map { it.figure.key }).first

        hand << new(place: place, trouble: GameSession::Trouble.fetch(trouble), figure: GameSession::Figure.fetch(figure))
      end
    end

    private
      def fresh(keys, used)
        keys.shuffle.partition { used.exclude?(it) }.flatten
      end
  end

  def keys = [ place, trouble, figure ].map(&:key)
  def key = keys.join(" ")
end
