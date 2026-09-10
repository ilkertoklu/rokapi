class GameSession::Quest < Data.define(:key, :title, :hook, :brief)
  extend Catalog

  ALL = [
    new(key: "lost_caravan", title: "The Lost Caravan", hook: "The trail of a salt caravan lost in a blizzard.",
        brief: "The caravan carrying Whitebend's winter salt has been missing for three days. " \
               "It has to be found and brought to the village before the blizzard closes the pass. " \
               "The route runs from Whitebend to Blizzard Pass, on past the tracks, the abandoned " \
               "lodges and the rope bridge at the pass. The caravan's loss could be an accident, " \
               "or it could be an ambush."),
    new(key: "sunken_village", title: "The Lake's Secret", hook: "An old village left under the water.",
        brief: "The lake has drawn back in the drought and uncovered a village that went under years ago. " \
               "No record says why the village was abandoned, and some claim they hear a bell out on the " \
               "water at night. Solving it means going down into the drowned village.")
  ].freeze
end
