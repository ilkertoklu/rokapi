class GameSession::Twist < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[
    asker_is_cause villain_protects left_willingly both_hide_same cover_for_worse helper_profits
    old_wrong no_villain trouble_shields outsider_framed unwitting_helper
    one_of_two dear_price friend_opposed fixer_runs abandon_place cause_must_help break_the_rule second_chance
  ].map { |key| new(key: key) }.freeze
end
