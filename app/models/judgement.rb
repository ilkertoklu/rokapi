class Judgement
  class MalformedVerdict < StandardError; end

  def initialize(first, second)
    @first, @second = first, second
  end

  def verdict
    data = Judge.new.ask(prompt).parsed
    raise MalformedVerdict, data.inspect unless data.is_a?(Hash) && data["better"].in?(%w[first second])

    winner, loser = data["better"] == "first" ? [ @first, @second ] : [ @second, @first ]

    { "first" => @first.id, "second" => @second.id, "winner" => winner.id, "loser" => loser.id,
      "confidence" => data["confidence"], "reason" => data["reason"], "improvement" => data["improvement"] }
  end

  private
    def prompt
      I18n.with_locale(:en) do
        "THE FIRST PLAYTHROUGH\n\n#{Playthrough.new(@first)}\n\n\nTHE SECOND PLAYTHROUGH\n\n#{Playthrough.new(@second)}"
      end
    end
end
