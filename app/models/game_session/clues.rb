module GameSession::Clues
  extend ActiveSupport::Concern

  def clues_found
    (scenes + rolls).filter_map { Integer(it.effects&.dig("clue"), exception: false) }.select(&:positive?).uniq.sort
  end

  def clues_left
    [ clue_count - clues_found.size, 0 ].max
  end

  def next_clue
    (1..clue_count).find { clues_found.exclude?(it) }
  end

  def marks
    rolls.sort_by(&:id).filter_map { it.effects&.dig("mark").presence }
  end

  private
    def clue_count
      plan.to_s.scan(/^\W*(\d+)[.)]/).flatten.map(&:to_i).max.to_i
    end
end
