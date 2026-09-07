class Narrator::Briefing
  GRADE_NOTES = {
    critical: "doğal 20 — istisnai an",
    brilliant: "hedef %{margin} puan farkla aşıldı",
    narrow: "ucu ucuna",
    heavy: "hedefin %{margin} puan altında",
    catastrophe: "doğal 1 — olabilecek en kötüsü"
  }.freeze

  def initialize(game_session)
    @game_session = game_session
  end

  def plan_prompt
    [ mission_block, character_portrait, "SAHNE SAYISI: #{@game_session.scene_budget}. Vuruş listesi tam #{@game_session.scene_budget} satır olur.",
      "Hikâye kitabını yaz." ].join("\n\n")
  end

  def outcome_prompt(roll)
    [ mission_block, bible_block, character_block(roll.scene), used_items_block(roll),
      history_block, roll_block(roll), missing_healing_block(roll), "Bu sonucu çözümle." ].compact.join("\n\n")
  end

  def scene_prompt(scene)
    [ mission_block, bible_block, character_block(scene), history_block, repetition_block, variety_block,
      wounded_block(scene), pacing_block(scene), action_block ].compact.join("\n\n")
  end

  private
    def mission_block
      brief = GameSession::Quest[@game_session.quest]&.brief ||
        "Sürpriz macera: bilinmeyen, özgün bir dünya ve görev kur; ilk sahnede oyuncuyu hikâyenin ortasına bırak."
      "GÖREV ÇERÇEVESİ: #{brief}\nTON: #{GameSession::Tone.fetch(@game_session.tone).directive}"
    end

    def bible_block
      return if @game_session.story_bible.blank?

      antagonist = @game_session.story_antagonist.to_h
      ally = @game_session.story_ally.to_h
      <<~TEXT.strip
        HİKÂYE KİTABI (gizli — oyuncuya söylenmez, sahnelerle yaşatılır):
        Macera: #{@game_session.story_title}. #{@game_session.story_premise}
        Kişisel bağ: #{@game_session.story_personal_stake}
        Karşıt güç: #{antagonist["name"]} — istediği: #{antagonist["want"]} Yöntemi: #{antagonist["method"]} İlk izi: #{antagonist["first_sign"]}
        Müttefik: #{ally["name"]} — istediği: #{ally["want"]} Sırrı: #{ally["secret"]}
        Dönüş: #{@game_session.story_twist}
        Finalin sorusu: #{@game_session.story_finale_question}
        Zafer: #{@game_session.story_victory}
        Yenilgi: #{@game_session.story_defeat}
      TEXT
    end

    def repetition_block
      stats = @game_session.rolls.order(id: :desc).limit(3).pluck("choices.stat")
      return unless stats.size == 3 && stats.uniq.size == 1

      label = Character::Stat.fetch(stats.first).label
      "TEKRAR: Oyuncu üst üste üç kez #{label} kullandı. Dünya buna uyum sağlar: bu sahnede #{label} yolunu ya kapat ya da belirgin biçimde zorlaştır."
    end

    def variety_block
      recent = @game_session.scenes.played.chronological.last(2).flat_map(&:choices)
      return if recent.empty?

      easy = recent.select(&:easy?).map(&:stat).uniq
      hard = recent.select(&:hard?).map(&:stat).uniq
      "ÇEŞİTLİLİK: Son sahnelerin seçenekleri: #{recent.map { |choice| %("#{choice.label}") }.join(", ")}. " \
        "Bunların kalıbını yeniden yazma. Kolay seçenek #{stat_labels(easy)}, zor seçenek #{stat_labels(hard)} statındaydı; bu sahnede kolay ve zor seçenekleri başka statlara ver."
    end

    def stat_labels(stats)
      stats.map { |stat| Character::Stat.fetch(stat).label }.join("/").presence || "—"
    end

    def pacing_block(scene)
      [ "SAHNE: #{scene.position}/#{@game_session.scene_budget}", beat_line(scene), stage_directive(scene) ].compact.join("\n")
    end

    def beat_line(scene)
      beat = Array(@game_session.story_beats)[scene.position - 1]
      "VURUŞ: #{beat}" if beat.present?
    end

    def stage_directive(scene)
      budget = @game_session.scene_budget

      if scene.active_player.character.hp.zero?
        "KARAKTER YIĞILDI: canı tükendi. Bu sahne FİNAL ve yenilgidir: düşüşünü en fazla 2 kısa paragrafta ve 110 kelimede anlat. #{closing_rules} finale=true, outcome=\"defeat\", seçenek üretme."
      elsif scene.position >= budget
        "Bu sahne FİNAL: hikâyeyi en fazla 2 kısa paragrafta ve 120 kelimede kapat. Final yeni bir hamle yaptırmaz ve doruk çözümlemesini yeniden anlatmaz; o sonucun ardından ne olduğunu gösterir. #{tally_line} Finalin sorusunu oyuncunun gerçekten yaptıklarıyla cevapla: zafer koşulu sağlandıysa outcome \"victory\", sağlanmadıysa \"defeat\"; ikisi de bedeliyle gelir. Doruk zarı başarısızsa temiz zafer yok: ya yenilgi ya da zafer koşulunun yalnız bir parçası, gözle görülür bir kayıpla (bir insan, bir yer, bir ilişki) gerçekleşir. #{closing_rules} finale=true, seçenek üretme."
      elsif scene.position == budget - 1
        "DORUK: karşıt güçle yüz yüze gelinir ve tehlike bedenseldir; üç seçenek de bedel ister, kolay olan bile bir şeyi feda eder. Bu sahnenin seçimi finalin rengini belirler; bir sonraki sahne final."
      elsif scene.first?
        "GİRİŞ: oyuncu olayın ortasına düşer; kişisel bağ bu sahnede bir cümleyle kurulur (bir ad, bir anı, bir borç), karşıt gücün ilk izi görünür, hedef nettir."
      elsif scene.position == midpoint
        "ORTA NOKTA: dönüş bu sahnede açığa çıkar; bundan sonrası geri dönüşsüzdür."
      elsif scene.position > midpoint
        "TIRMANIŞ: tempo yükselir, bedeller büyür; müttefikin sırrı ve karşıt gücün yüzü yaklaşır."
      else
        "GELİŞME: yeni bir komplikasyon, bilgi ya da bedel getir; hedefe somut bir adım attır."
      end
    end

    def tally_line
      rolls = @game_session.rolls.order(:id).to_a
      return if rolls.empty?

      "ZAR BİLANÇOSU: #{rolls.count(&:success?)} başarı, #{rolls.count { |roll| !roll.success? }} başarısızlık; doruk zarı #{grade_label(rolls.last)}."
    end

    def closing_rules
      "Kapanış kurulanı öder: kişisel bağ bir cümleyle cevaplanır ve oyuncu finalde görünür (biri ona konuşur ya da bir şey ona kalır), karşıt gücün ve müttefikin akıbeti birer cümleyle görünür, açılıştaki bir imge geri döner (imge kendisi gelir, \"ilk sahnedeki\" denmez), son cümle tek vurucu imgedir. \"İleride\", \"bir gün\", \"macera sürecek\" gibi açık uçlu kapanış yazma."
    end

    def midpoint
      (@game_session.scene_budget / 2.0).ceil
    end

    def missing_healing_block(roll)
      scene = roll.scene
      character = scene.active_player.character
      return if scene.position < 2 || character.sturdy? || character.items.healing.any?
      return if last_outcome_granted_item?(roll)

      "EKSİK: Karakterin şifa eşyası yok ve oyun bunu bekliyor. Bu çözümlemede en ufak fırsat varsa " \
        "(çanta, sandık, enkaz, ceset, ödül, dost bir el) bir şifa iksiri ver: instant, +6..+8 can, 1 hak. " \
        "Bu izin her derece için geçerli: sıradan bir başarı da iksir bulabilir."
    end

    def last_outcome_granted_item?(roll)
      previous = @game_session.rolls.where.not(id: roll.id).order(:id).last
      previous.present? && previous.items_gained.any?
    end

    def wounded_block(scene)
      character = scene.active_player.character
      return unless character.wounded?

      "AĞIR YARALI: Karakterin canı #{character.hp}/#{character.max_hp}. Dünya bunu görüyor: " \
        "anlatı yorgunluğu yansıtsın ve seçeneklerden biri soluklanmaya, şifaya ya da temkinli bir yola açılsın."
    end

    def character_block(scene)
      character = scene.active_player.character
      stats = Character::Stat.all.map { |stat| "#{stat.label} #{character.stats[stat.key]}" }.join(", ")
      [ "KARAKTER: #{character.user.name} — #{character.summary}. Can #{character.hp}/#{character.max_hp}. Statlar: #{stats}.",
        inventory_line(character), statuses_line(character) ].compact.join("\n")
    end

    def character_portrait
      character = @game_session.host.character
      traits = [ Character::Race.fetch(character.race), Character::Klass.fetch(character.klass), Character::Background.fetch(character.background) ]
        .map { |trait| "#{trait.label}: #{trait.description}" }.join(" ")
      "OYUNCUNUN KARAKTERİ: #{traits}\n#{inventory_line(character)}"
    end

    def inventory_line(character)
      items = character.items.carried
      "ENVANTER: #{items.any? ? items.map(&:summary).join("; ") : "boş"}"
    end

    def statuses_line(character)
      statuses = character.status_effects
      "STATÜ ETKİLERİ: #{statuses.map(&:summary).join("; ")}" if statuses.any?
    end

    def used_items_block(roll)
      used = roll.player.character.items.used_since(roll.scene.created_at)
      return if used.none?

      "KULLANILAN EŞYA: #{used.map { |item| "#{item.name} (#{format('%+d', item.hp_effect)} can)" }.join("; ")} — canı zaten uygulandı ve envanterden düştü; anlatıda içildiği görünsün, hp'ye ve items_lost'a yeniden yazma."
    end

    def history_block
      scenes = @game_session.scenes.played.chronological.includes(roll: :choice)
      return if scenes.none?

      "HİKÂYE ŞİMDİYE DEK (sahne sahne, oyuncunun seçimi ve zar sonucuyla):\n" + scenes.map { |scene| history_entry(scene) }.join("\n\n")
    end

    def history_entry(scene)
      entry = "[#{scene.position}] #{scene.title} @ #{scene.location}\n#{scene.narration}"
      roll = scene.roll
      return entry if roll.nil? || !roll.resolved?

      "#{entry}\n→ Seçim: \"#{roll.choice.label}\" — #{grade_label(roll)}. #{roll.resolution}"
    end

    def roll_block(roll)
      status = " #{format('%+d', roll.status_modifier)} (statü)" unless roll.status_modifier.zero?
      <<~TEXT
        ZAR SONUCU: "#{roll.choice.label}" seçildi.
        d20=#{roll.value} #{format('%+d', roll.modifier)}#{status} = #{roll.total}, hedef #{roll.target} → #{grade_label(roll)}.
      TEXT
    end

    def grade_label(roll)
      note = GRADE_NOTES[roll.grade]
      note ? "#{roll.grade_label} (#{note % { margin: roll.margin.abs }})" : roll.grade_label
    end

    def action_block
      roll = @game_session.rolls.order(:id).last
      return "İlk sahneyi yaz." if roll.nil?

      "Son çözümleme oyuncuya gösterildi: olanları yeniden sahneleme, kaldığı yerden devamını yaz."
    end
end
