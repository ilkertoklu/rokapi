class GameSession::Twist < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[ asker_is_cause villain_protects left_willingly both_hide_same cover_for_worse helper_profits old_wrong no_villain ].map { |key| new(key: key) }.freeze
end
