module GameSession::Clues
  extend ActiveSupport::Concern

  def clues_found
    (clues_in(scenes) + clues_in(rolls)).uniq.sort
  end

  def clues_won
    clues_in(rolls)
  end

  def solved?
    clues_won.size * 2 >= clue_count
  end

  def earned_outcome
    solved? ? "victory" : "defeat"
  end

  def clues_left
    [ clue_count - clues_found.size, 0 ].max
  end

  def next_clue
    clues_unfound.first
  end

  def clues_unfound
    (1..clue_count).to_a - clues_found
  end

  def first_scene_for_clue(clue)
    (clue - 1) * (scene_budget - 1) / clue_count + 1
  end

  def marks
    rolls.sort_by(&:id).filter_map { it.effects&.dig("mark").presence }
  end

  private
    def clue_count
      plan.to_s.scan(/^\W*(\d+)[.)]/).flatten.map(&:to_i).max.to_i
    end

    def clues_in(records)
      records.pluck(:effects).filter_map { Integer(it&.dig("clue"), exception: false) }.select(&:positive?).uniq.sort
    end
end
