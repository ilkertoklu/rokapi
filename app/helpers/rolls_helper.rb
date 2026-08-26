module RollsHelper
  VERDICTS = {
    critical: "KRİTİK BAŞARI!", brilliant: "PARLAK BAŞARI", solid: "BAŞARILI", narrow: "KIL PAYI BAŞARI",
    failure: "BAŞARISIZ", heavy: "AĞIR BAŞARISIZLIK", catastrophe: "FELAKET!"
  }.freeze

  def outcome_verdict(roll)
    VERDICTS.fetch(roll.grade)
  end
end
