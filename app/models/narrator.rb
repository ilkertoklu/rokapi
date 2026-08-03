class Narrator
  class MalformedResponse < StandardError; end

  RECENT_SCENES = 2

  def initialize(game_session)
    @game_session = game_session
  end

  def narrate_outcome(roll)
    return if roll.resolved?

    response = new_chat(instructions: outcome_instructions).with_schema(OutcomeSchema).ask(outcome_prompt(roll))
    record_call :outcome, response

    data = response.content
    raise MalformedResponse, "structured output missing" unless data.is_a?(Hash)

    roll.resolve! resolution: resolution_in(data), effects: data["effects"]
  end

  def continue!
    generate_scene if owed?
  end

  private
    def owed?
      scene = @game_session.current_scene
      return true if scene.nil? || scene.narrating? || scene.failed?

      scene.played? && !scene.finale? && scene.roll&.acknowledged?
    end

    def generate_scene
      scene = next_scene
      data, prose = ask_streaming(scene)
      close_scene! scene, data, prose
      fold_context_summary
    end

    def next_scene
      @game_session.scenes.unwritten.chronological.last ||
        @game_session.scenes.create!(position: (@game_session.scenes.maximum(:position) || 0) + 1,
                                     active_player: @game_session.players.order(:created_at).first)
    end

    def ask_streaming(scene)
      reply = Reply.new
      data = nil
      visible = 0
      chat = new_chat(instructions: scene_instructions)

      response = chat.ask(scene_prompt(scene)) do |chunk|
        reply << chunk.content.to_s

        if data
          visible = relay(scene, reply.prose, visible)
        elsif (data = structure_in(reply))
          open_scene! scene, data
        end
      end

      record_call :scene, response
      raise MalformedResponse, "structure block missing" if data.nil?

      [ data, reply.prose ]
    end

    def relay(scene, prose, visible)
      return visible if prose.length <= visible

      scene.update_column :narration, prose
      scene.broadcast_narration prose[visible..]
      prose.length
    end

    def structure_in(reply)
      reply.structure
    rescue JSON::ParserError
      repair(reply.json)
    end

    def repair(json)
      response = new_chat(model: helper_model).ask(<<~PROMPT)
        Aşağıdaki bozuk JSON'u düzelt. Yanıt olarak YALNIZCA geçerli JSON döndür, başka hiçbir şey yazma:

        #{json}
      PROMPT
      record_call :repair, response
      JSON.parse response.content.to_s.sub(/\A\s*```(?:json)?/, "").sub(/```\s*\z/m, "").strip
    rescue JSON::ParserError
      raise MalformedResponse, "repair failed"
    end

    def open_scene!(scene, data)
      validate! data
      scene.update! title: data.fetch("title"), location: data["location"]
    rescue KeyError => error
      raise MalformedResponse, error.message
    end

    def close_scene!(scene, data, prose)
      finale = data["finale"] == true

      ApplicationRecord.transaction do
        scene.update! narration: prose, finale: finale, state: finale ? :played : :choosing

        if finale
          @game_session.finish! outcome_in(data)
        else
          create_choices scene, Array(data["choices"])
        end
      end
    end

    def validate!(data)
      data.fetch("title")

      if data["finale"] == true
        outcome_in data
      elsif Array(data["choices"]).size != 3
        raise MalformedResponse, "expected 3 choices"
      end
    end

    def resolution_in(data)
      data["resolution"].presence || raise(MalformedResponse, "resolution missing")
    end

    def outcome_in(data)
      data["outcome"].presence_in(GameSession.outcomes.keys) ||
        raise(MalformedResponse, "unknown outcome #{data["outcome"].inspect}")
    end

    def create_choices(scene, choices)
      character = scene.active_player.character

      choices.each do |choice|
        stat = choice.fetch("stat")
        raise MalformedResponse, "unknown stat #{stat}" unless Character::STAT_KEYS.include?(stat)

        scene.choices.create!(
          label: choice.fetch("label"),
          stat: stat,
          modifier: character.bonus_for(stat),
          difficulty: choice.fetch("difficulty").to_i.clamp(5, 19),
          difficulty_label: choice["difficulty_label"].presence_in(%w[kolay orta zor]) || "orta",
          difficulty_reason: choice["difficulty_reason"]
        )
      end
    end

    def fold_context_summary
      aged_out = scenes_aged_out_of_recent_window
      return if aged_out.empty?

      response = new_chat(model: helper_model).ask(summary_prompt(aged_out))
      record_call :summary, response
      @game_session.update! context_summary: response.content.to_s,
                            context_summary_position: aged_out.last.position
    end

    def scenes_aged_out_of_recent_window
      recent = @game_session.scenes.written.chronological.last(RECENT_SCENES)
      return [] if recent.size < RECENT_SCENES

      @game_session.scenes.written.chronological
        .where(position: (@game_session.context_summary_position + 1)...recent.first.position).to_a
    end

    def summary_prompt(scenes)
      <<~PROMPT
        Aşağıdaki önceki özeti ve yeni sahneleri, anlatıcının hatırlaması gereken olaylar ve durumlarla 5-6 cümlelik tek bir Türkçe özete birleştir:

        ÖNCEKİ ÖZET: #{@game_session.context_summary.presence || "yok"}

        YENİ SAHNELER:
        #{scenes.map { |scene| "#{scene.title}: #{scene.narration.to_s.truncate(600)}" }.join("\n")}
      PROMPT
    end

    def helper_model
      Rails.configuration.x.llm.helper_model
    end

    def new_chat(model: nil, instructions: nil)
      chat = RubyLLM.chat(model: model)
      chat.with_instructions(instructions) if instructions
      chat
    end

    def record_call(purpose, response)
      LlmCall.record! game_session: @game_session, purpose: purpose, response: response
    end

    def persona
      <<~PROMPT
        Sen Rokapi'nin anlatıcısısın: Türkçe yazan, sürükleyici bir masaüstü rol yapma oyunu anlatıcısı.

        Kurallar:
        - Anlatı ikinci tekil şahısla, yalın ve atmosferik.
        - Zar atmazsın ve sonuç uydurmazsın: sana verilen zar sonucunu hikâyeye işlersin.
        - Şiddet ve temalar PEGI-12 sınırında kalır.
      PROMPT
    end

    def outcome_instructions
      <<~PROMPT
        #{persona}
        Görevin yalnızca zar sonucunu çözümlemek. Yeni sahne yazma, seçenek üretme.
      PROMPT
    end

    def scene_instructions
      <<~PROMPT
        #{persona}
        - En fazla 2 kısa paragraf; toplam 120 kelimeyi aşma.

        Çıktı sözleşmesi — kesin uy:
        1) Önce tek bir ```json çitli blok. Yanıtın ilk karakteri bu bloğun açılışıdır; öncesinde hiçbir şey yazma:
        {
          "title": "sahne başlığı (2-3 kelime)",
          "location": "konum adı",
          "choices": [
            {"label": "seçenek metni", "stat": "strength|agility|constitution|intelligence|wisdom|charisma",
             "difficulty": 12, "difficulty_label": "kolay|orta|zor", "difficulty_reason": "kısa gerekçe"}
          ],
          "finale": false,
          "outcome": null
        }
        2) Bloğun kapanışından sonra düz metin anlatı; başka çit ya da başlık kullanma.

        - Tam 3 seçenek üret. difficulty aralıkları: kolay 8-11, orta 12-15, zor 16-19.
        - Önceki aksiyonun çözümlemesi sana verilir; onu tekrar anlatma, hikâyeyi oradan devam ettir.
        - Senden FİNAL istendiğinde hikâyeyi kapat: "choices" boş liste olur, "finale" true, "outcome" "victory" ya da "defeat".
      PROMPT
    end

    def outcome_prompt(roll)
      [ mission_block, character_block(roll.scene), summary_block,
        recent_scenes_block, roll_block(roll), "Bu sonucu çözümle." ].compact.join("\n\n")
    end

    def scene_prompt(scene)
      [ mission_block, character_block(scene), summary_block,
        recent_scenes_block, pacing_block(scene), action_block ].compact.join("\n\n")
    end

    def mission_block
      brief = @game_session.adventure&.brief ||
        "Sürpriz macera: bilinmeyen, özgün bir dünya ve görev kur; ilk sahnede oyuncuyu hikâyenin ortasına bırak."
      "GÖREV ÇERÇEVESİ: #{brief}\nTON: #{GameSession::TONES.fetch(@game_session.tone)}"
    end

    def pacing_block(scene)
      budget = @game_session.scene_budget
      directive =
        if scene.position >= budget
          "Bu sahne FİNAL olmalı: hikâyeyi kapat, finale=true yap, outcome belirle, seçenek üretme."
        elsif scene.position >= budget - 1
          "Kapanışa yaklaş: hikâyeyi sonuca doğru topla."
        end
      [ "SAHNE: #{scene.position}/#{budget}", directive ].compact.join("\n")
    end

    def character_block(scene)
      character = scene.active_player.character
      stats = Character::STAT_KEYS.map { |key| "#{Character::STATS.fetch(key)} #{character.stats[key]}" }.join(", ")
      "KARAKTER: #{player_name(scene.active_player)} — #{character.summary}. Can #{character.hp}/#{character.max_hp}. Statlar: #{stats}."
    end

    def player_name(player)
      player.user.name.to_s.gsub(/\s+/, " ").strip.truncate(40)
    end

    def summary_block
      "GEÇMİŞ ÖZETİ: #{@game_session.context_summary}" if @game_session.context_summary.present?
    end

    def recent_scenes_block
      recents = @game_session.scenes.played.chronological.last(RECENT_SCENES)
      return if recents.none?

      "SON SAHNELER:\n" + recents.map { |scene| "#{scene.title} — #{scene.narration}" }.join("\n---\n")
    end

    def roll_block(roll)
      result = roll.success? ? "BAŞARILI" : "BAŞARISIZ"
      <<~TEXT
        ZAR SONUCU: "#{roll.choice.label}" seçildi.
        d20=#{roll.value} #{format('%+d', roll.modifier)} = #{roll.total}, hedef #{roll.target} → #{result}.
      TEXT
    end

    def action_block
      roll = @game_session.rolls.order(:id).last
      return "İlk sahneyi yaz." if roll.nil?

      "#{roll_block(roll)}ÇÖZÜMLEME: #{roll.resolution}\n\nBu sonucun ardından hikâyeyi yeni bir sahneyle sürdür."
    end
end
