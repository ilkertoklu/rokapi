module PlayersHelper
  TURKISH_GENITIVE = { "a" => "ın", "ı" => "ın", "e" => "in", "i" => "in", "o" => "un", "u" => "un", "ö" => "ün", "ü" => "ün" }.freeze
  PALATAL_L_ENDING = /[aâ]l\z/

  def player_avatar(player, *modifiers, seat: player.seat)
    tag.span player.initial, title: player.name, class: [ "avatar", "avatar--seat-#{seat}", { "avatar--departed": player.departed? }, *modifiers ]
  end

  def genitive(name)
    return "#{name}’s" unless I18n.locale == :tr

    lowered = name.downcase(:turkic)
    suffix = lowered.match?(PALATAL_L_ENDING) ? "in" : TURKISH_GENITIVE.fetch(lowered.scan(/[aıeioöuü]/).last, "in")
    suffix = "n#{suffix}" if lowered.match?(/[aıeioöuü]\z/)
    "#{name}’#{suffix}"
  end
end
