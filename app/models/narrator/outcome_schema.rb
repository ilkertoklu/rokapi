class Narrator::OutcomeSchema < RubyLLM::Schema
  string :resolution, description: "Zar sonucunun ne olduğunu anlatan 1-2 cümle"
  object :effects do
    integer :hp, description: "Sonucun cana etkisi: başarısızlıkta genelde -2..-6, başarıda 0, iyileşme anlarında pozitif"
  end
end
