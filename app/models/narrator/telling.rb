class Narrator::Telling
  def self.open(scene, data)
    new(scene, data).open if data
  end

  def initialize(scene, data)
    @scene = scene
    @game_session = scene.game_session
    @data = data
  end

  def open
    validate

    ApplicationRecord.transaction do
      @game_session.update! title: adventure if names_the_adventure?
      @game_session.update! outcome: outcome if finale?
      @scene.update! title: @data["title"], location: @data["location"], finale: finale?
    end

    self
  end

  def close(prose)
    raise Narrator::MalformedResponse, "the narration is missing" if prose.blank?

    narration = Narrator::Screen.fit("the narration", prose, finale? ? Narrator::Screen::FINALE_WORDS : Narrator::Screen::SCENE_WORDS)

    ApplicationRecord.transaction do
      @scene.update! narration: narration, state: finale? ? :played : :choosing
      finale? ? @game_session.finish : create_choices
    end
  end

  private
    def finale?
      @data["finale"] == true
    end

    def names_the_adventure?
      @scene.first? && @game_session.quest.nil?
    end

    def validate
      raise Narrator::MalformedResponse, "title missing" if @data["title"].blank?
      Narrator::Screen.fit_title @data["title"], @game_session.scene_budget
      Narrator::Screen.fit "the location", @data["location"], Narrator::Screen::LOCATION_WORDS
      Narrator::Screen.fit "the adventure", adventure, Narrator::Screen::ADVENTURE_WORDS if names_the_adventure?

      if @scene.active_player.character.hp.zero?
        raise Narrator::MalformedResponse, "a downed character must meet defeat" unless finale? && outcome == "defeat"
      elsif finale?
        outcome
      elsif @scene.position >= @game_session.scene_budget
        raise Narrator::MalformedResponse, "scene #{@scene.position} is the last one, so it must be the finale"
      elsif choices.size != 3
        raise Narrator::MalformedResponse, "expected 3 choices"
      elsif choices.map { |choice| stat_in(choice) }.uniq.size != 3
        raise Narrator::MalformedResponse, "choices must use three distinct stats"
      else
        choices.each { |choice| validate_choice choice }
      end
    end

    def validate_choice(choice)
      Narrator::Screen.fit "the choice label", label_in(choice), Narrator::Screen::LABEL_WORDS
      Narrator::Screen.fit "the difficulty reason", choice["difficulty_reason"], Narrator::Screen::REASON_WORDS
      difficulty_in choice
    end

    def choices
      Array(@data["choices"])
    end

    def adventure
      @data["adventure"].presence || raise(Narrator::MalformedResponse, "the first scene must name the adventure")
    end

    def outcome
      @data["outcome"].presence_in(GameSession.outcomes.keys) || raise(Narrator::MalformedResponse, "unknown outcome #{@data["outcome"].inspect}")
    end

    def create_choices
      character = @scene.active_player.character

      choices.each do |choice|
        stat = stat_in(choice)
        @scene.choices.create! label: label_in(choice), stat: stat, modifier: character.bonus_for(stat),
          target: difficulty_in(choice), difficulty_reason: choice["difficulty_reason"]
      end
    end

    def label_in(choice)
      choice["label"].presence || raise(Narrator::MalformedResponse, "unlabeled choice")
    end

    def stat_in(choice)
      choice["stat"].presence_in(Character::Stat.keys) || raise(Narrator::MalformedResponse, "unknown stat #{choice["stat"].inspect}")
    end

    def difficulty_in(choice)
      difficulty = Integer(choice["difficulty"], exception: false) || raise(Narrator::MalformedResponse, "difficulty missing")
      return difficulty if Choice::DIFFICULTY.cover?(difficulty)

      raise Narrator::MalformedResponse, "difficulty #{difficulty} is outside #{Choice::DIFFICULTY.min}-#{Choice::DIFFICULTY.max}"
    end
end
