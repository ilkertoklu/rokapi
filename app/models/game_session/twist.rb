class GameSession::Twist < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[
    asker_is_cause villain_protects left_willingly both_hide_same cover_for_worse helper_profits
    old_wrong no_villain trouble_shields outsider_framed two_culprits
  ].map { |key| new(key: key) }.freeze
end
