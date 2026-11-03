class GameSession::Figure < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[
    weather_reader young_guard indebted_smith unwilling_heir ambitious_clerk path_child old_captain
    doubted_healer weary_smuggler doubting_novice selling_innkeeper exiled_noble stable_hand hermit
    hiding_apprentice lonely_moneylender unknown_bard gravedigger greedy_bridgekeeper last_of_the_house
  ].map { |key| new(key: key) }.freeze
end
