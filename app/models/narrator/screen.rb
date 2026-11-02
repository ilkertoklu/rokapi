module Narrator::Screen
  SCENE_WORDS = 90
  FINALE_WORDS = 120
  RESOLUTION_WORDS = 40
  LOCATION_WORDS = 5
  ADVENTURE_WORDS = 4
  LABEL_WORDS = 9
  REASON_WORDS = 10

  # The scene header on the comp's 390px phone: an 18px Spectral SemiBold title beside one 7px dot per scene, 6px apart.
  HEADER_WIDTH = 390 - 2 * 22.4 - 12
  PROGRESS_DOT_PITCH = 7 + 6
  CURRENT_DOT_WIDTH = 9
  TITLE_GLYPH_WIDTH = 8.2

  def self.title_limit(scenes)
    progress = PROGRESS_DOT_PITCH * (scenes - 1) + CURRENT_DOT_WIDTH
    ((HEADER_WIDTH - progress) / TITLE_GLYPH_WIDTH).floor
  end

  def self.fit(part, text, words)
    count = text.to_s.split.size
    raise Narrator::MalformedResponse, "#{part} runs #{count} words, at most #{words} fit the screen: #{text.to_s.squish.inspect}" if count > words

    text
  end

  def self.fit_title(title, scenes)
    limit = title_limit(scenes)
    return title if title.length <= limit

    raise Narrator::MalformedResponse, "the title #{title.inspect} runs #{title.length} characters, at most #{limit} fit beside the progress dots"
  end
end
