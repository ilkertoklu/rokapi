module RollsHelper
  REEL_CELLS = 17

  def outcome_verdict(roll)
    roll.grade.in?(%i[ critical catastrophe ]) ? "#{roll.grade_label}!" : roll.grade_label
  end

  def die_reel_faces(roll)
    others = (1..Roll::DIE).to_a - [ roll.value ]
    others.shuffle(random: Random.new(roll.id)).first(REEL_CELLS - 1) << roll.value
  end
end
