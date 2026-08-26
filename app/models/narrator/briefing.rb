class Narrator::Briefing
  TONE_DIRECTIVES = {
    "fun" => "Eğlenceli — tempo hafif, mizah durumlardan ve diyalogdan doğar; dünya yine de gerçektir, tehlike ciddiye alınır, parodiye kaçılmaz.",
    "balanced" => "Dengeli — klasik macera: umut ile tehlike dengede, zaferin tadı bedeliyle gelir.",
    "dark" => "Karanlık — gölgeler ağır basar, bedeller serttir, güven zor kazanılır; korku PEGI-12 sınırında kalır."
  }.freeze

  GRADES = {
    critical: "KRİTİK BAŞARI (doğal 20 — istisnai an)",
    brilliant: "PARLAK BAŞARI (hedef %{margin} puan farkla aşıldı)",
    solid: "BAŞARILI",
    narrow: "KIL PAYI BAŞARI (ucu ucuna)",
    failure: "BAŞARISIZ",
    heavy: "AĞIR BAŞARISIZLIK (hedefin %{margin} puan altında)",
    catastrophe: "FELAKET (doğal 1 — olabilecek en kötüsü)"
  }.freeze

  def initialize(game_session)
    @game_session = game_session
  end

  def outcome_instructions
    <<~PROMPT
      #{persona}
      Görevin yalnızca zar sonucunu çözümlemek. Yeni sahne yazma, seçenek üretme.
      Çözümleme 1-2 kısa cümledir, toplam 40 kelimeyi aşmaz: ne olduğu, neye mal olduğu ya da ne kazandırdığı somut söylenir.
      Başarısızlık hikâyeyi durdurmaz: bir kapı kapanır ama başka bir şey açılır — yeni tehlike, yeni yol, yeni bilgi.

      Zar sonucunun derecesi etkilerin ölçüsüdür:
      - KRİTİK / PARLAK BAŞARI: umulandan fazlası — ek avantaj, değerli bilgi ya da yağma anındaysa küçük bir ganimet. Pozitif statü yalnız bu derecelerde verilir (+1, kritikte +2).
      - BAŞARILI: iş temiz biter; etki listeleri boş kalır, can değişmez.
      - KIL PAYI BAŞARI: başarır ama iz kalır — fiziksel tehlikede -1..-3 can ya da hiçbir etki.
      - BAŞARISIZ: ilerleme yok, bedel somut. Fiziksel tehlikede -3..-6 can; sosyal ya da zihinsel uğraşta can gitmez, onun yerine bir fırsat, bilgi ya da itibar yitirilir.
      - AĞIR BAŞARISIZLIK: durum gözle görülür kötüleşir — fiziksel tehlikede -6..-9 can; kurgu iz bıraktıysa somut negatif statü.
      - FELAKET: olabilecek en kötüsü olur — fiziksel tehlikede -9..-12 can; değerli bir şey elden gidebilir, güçlü negatif statü (-2) yerindedir.
      - Can 0'a düşerse karakter yığılır; çözümleme bunu açıkça gösterir.

      Statü kuralları:
      - Statü, anlatıda görünen somut bir ize bağlanır ve adı o izi söyler: "Kanayan Omuz", "Sırılsıklam", "Ayağı Burkuk". Ruh hâli sıfatları statü olamaz ("Kararlı", "Tedirgin", "Odaklanmış" verilmez).
      - Karakterin 2 aktif statüsü varsa yenisi verilmez.
      - Statü süresi ya tur sayısıyla ya da tek bir koşul etiketiyle belirtilir, ikisiyle birden değil.

      Eşya kuralları:
      - Eşya ancak kurgunun gösterdiği yerden gelir: sandık, ceset, ödül, takas. Kazanılan eşya çözümleme cümlesinde de geçer.
      - Görev eşyası (quest) yalnız görevin kilit nesneleri içindir.
    PROMPT
  end

  def scene_instructions
    <<~PROMPT
      #{persona}
      Sahne kuralları:
      - En fazla 2 kısa paragraf; paragraf 4 cümleyi geçmez, toplam 90 kelimeyi aşma. Az ama vurucu yaz: her cümle yeni bir şey söyler.
      - FİNAL sahnesi de bu sınırların içinde kalır: en fazla 2 kısa paragraf, toplam 100 kelime. Kapanış tek vurucu imgeyle biter, uzatılmaz.
      - Sahne yeni bir gelişmeyle açılır; önceki sahne ya da çözümleme yeniden anlatılmaz.
      - Her sahne şu üçünden en az birini değiştirir: mekân, karşıdaki güç, bilinen bir gerçek. Aynı engel iki sahne üst üste sürmez.
      - Anlatı, oyuncunun karar vereceği gergin bir anda durur; soruyla bitmez.

      Seçenek kuralları:
      - Tam 3 seçenek ve üçü birbirinden FARKLI stat kullanır.
      - Seçenek metni emir kipinde, en çok 9 kelime: "Zinciri kılıçla kes", "Muhafızı borcuyla ikna et".
      - Üç seçenek üç ayrı yol açar; aynı eylemin çeşitlemeleri yazılmaz. Biri temkinli (kolay), biri dengeli (orta), biri gözü kara (zor) olur; zor olan, tutarsa hikâyeyi en çok ilerletir.
      - difficulty kurgudaki gerçek riske göre: kolay 8-11, orta 12-15, zor 16-19.
      - Seçenekler karakterin envanterinden ve statü etkilerinden yararlanabilir; yeni eşya bu çağrıda verilmez.
      - Şifa eşyasını içmek seçenek olamaz; oyuncu eşyasını zaten dilediği an kullanabiliyor.

      Çıktı sözleşmesi — kesin uy:
      1) Önce tek bir ```json çitli blok. Yanıtın ilk karakteri bu bloğun açılışıdır; öncesinde hiçbir şey yazma:
      {
        "plan": "yalnız 1. sahnede: hikâyenin gizli iskeleti — asıl karşıt güç, ortada açığa çıkacak gerçek, finali belirleyecek koşul; 2-3 cümle. Sonraki sahnelerde null",
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

      - Senden FİNAL istendiğinde hikâyeyi kapat: "choices" boş liste olur, "finale" true, "outcome" "victory" ya da "defeat". Final ana soruyu tek sahnede, oyalanmadan kapatır.
    PROMPT
  end

  def outcome_prompt(roll)
    [ mission_block, character_block(roll.scene), used_items_block(roll), summary_block,
      recent_scenes_block, roll_block(roll), missing_healing_block(roll), "Bu sonucu çözümle." ].compact.join("\n\n")
  end

  def scene_prompt(scene)
    [ mission_block, outline_block, character_block(scene), summary_block,
      recent_scenes_block, repetition_block, wounded_block(scene), pacing_block(scene), action_block ].compact.join("\n\n")
  end

  def summary_prompt(scenes)
    <<~PROMPT
      Aşağıdaki önceki özeti ve yeni sahneleri, anlatıcının hatırlaması gereken olaylar ve durumlarla 5-6 cümlelik tek bir Türkçe özete birleştir:

      ÖNCEKİ ÖZET: #{@game_session.context_summary.presence || "yok"}

      YENİ SAHNELER:
      #{scenes.map { |scene| "#{scene.title}: #{scene.narration.to_s.truncate(600)}" }.join("\n")}
    PROMPT
  end

  private
    def persona
      <<~PROMPT
        Sen Rokapi'nin anlatıcısısın: Türkçe yazan, masaüstü rol yapma oyunu yöneten bir anlatıcı.

        Dil kuralları:
        - Anlatı ikinci tekil şahısla ("sen") ve -iyor'lu şimdiki zamanla akar: "kapı gıcırdıyor", "adam sana bakıyor". Geniş zamanla ("kapı gıcırdar", "adam bakar") anlatma.
        - Yalın ve somut yaz: kısa cümleler, gündelik sözcükler. Görüneni, duyulanı, kokuyu anlat; soyut şairanelik etme.
        - Noktalı virgül kullanma; cümleyi noktayla bitir. Benzetme paragraf başına en fazla bir kez.
        - Dünya kendini ciddiye alır: adlar, yerler ve tehditler inandırıcıdır; parodiye ve saçmaya kaçma.
        - Oyuncunun adını anlatıcı sesinle kullanma; ad ancak bir karakterin ağzından, ona seslenirken geçebilir.
        - Zar atmazsın ve sonuç uydurmazsın: sana verilen zar sonucunu hikâyeye işlersin.
        - Oyun mekaniği anlatıya sızmaz: can puanı, zar değeri, statü adı gibi sayılar anlatıda geçmez; etkileri kurguyla gösterilir.
        - Şiddet ve temalar PEGI-12 sınırında kalır.
      PROMPT
    end

    def mission_block
      brief = @game_session.adventure&.brief ||
        "Sürpriz macera: bilinmeyen, özgün bir dünya ve görev kur; ilk sahnede oyuncuyu hikâyenin ortasına bırak."
      "GÖREV ÇERÇEVESİ: #{brief}\nTON: #{TONE_DIRECTIVES.fetch(@game_session.tone)}"
    end

    def outline_block
      outline = @game_session.story_outline
      "HİKÂYE İSKELETİ (gizli plan — oyuncuya söylenmez, sahnelerle yaşatılır): #{outline}" if outline.present?
    end

    def repetition_block
      stats = @game_session.rolls.order(id: :desc).limit(3).pluck("choices.stat")
      return unless stats.size == 3 && stats.uniq.size == 1

      label = Character::STATS.fetch(stats.first)
      "TEKRAR: Oyuncu üst üste üç kez #{label} kullandı. Dünya buna uyum sağlar: bu sahnede #{label} yolunu ya kapat ya da belirgin biçimde zorlaştır."
    end

    def pacing_block(scene)
      [ "SAHNE: #{scene.position}/#{@game_session.scene_budget}", stage_directive(scene) ].compact.join("\n")
    end

    def stage_directive(scene)
      budget = @game_session.scene_budget

      if scene.active_player.character.hp.zero?
        "KARAKTER YIĞILDI: canı tükendi. Bu sahne FİNAL: yenilgiyi en fazla 2 kısa paragrafta ve 100 kelimede hikâyeye işle; finale=true, outcome=\"defeat\", seçenek üretme."
      elsif scene.position >= budget
        "Bu sahne FİNAL olmalı: hikâyeyi en fazla 2 kısa paragrafta ve 100 kelimede kapat; finale=true, outcome belirle, seçenek üretme."
      elsif scene.position == budget - 1
        "DORUK: asıl karşıt güçle yüzleşme bu sahnede yaşanır; bir sonraki sahne final."
      elsif scene.position == 1
        "GİRİŞ: dünyayı ve görevi kur, tehdidi göster; oyuncuya net bir hedef bırak."
      elsif scene.position == midpoint
        "ORTA NOKTA: asıl karşıt güç yüzünü gösterir ya da bilinen bir şey tersine döner; bundan sonrası geri dönüşsüzdür."
      elsif scene.position > midpoint
        "TIRMANIŞ: tempo yükselir, bedeller büyür; hikâyeyi doruğa yaklaştır."
      else
        "GELİŞME: yeni bir komplikasyon, bilgi ya da bedel getir; hedefe somut bir adım attır."
      end
    end

    def midpoint
      (@game_session.scene_budget / 2.0).ceil
    end

    def missing_healing_block(roll)
      scene = roll.scene
      character = scene.active_player.character
      return if scene.position < 2 || character.items.healing.any?
      return if character.sturdy? && scene.position < midpoint
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
      stats = Character::STAT_KEYS.map { |key| "#{Character::STATS.fetch(key)} #{character.stats[key]}" }.join(", ")
      [ "KARAKTER: #{player_name(scene.active_player)} — #{character.summary}. Can #{character.hp}/#{character.max_hp}. Statlar: #{stats}.",
        inventory_line(character), statuses_line(character) ].compact.join("\n")
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

    def player_name(player)
      player.user.name.to_s.gsub(/\s+/, " ").strip.truncate(40)
    end

    def summary_block
      "GEÇMİŞ ÖZETİ: #{@game_session.context_summary}" if @game_session.context_summary.present?
    end

    def recent_scenes_block
      recents = @game_session.scenes.played.chronological.last(Narrator::RECENT_SCENES)
      return if recents.none?

      "SON SAHNELER:\n" + recents.map { |scene| "#{scene.title} — #{scene.narration}" }.join("\n---\n")
    end

    def roll_block(roll)
      status = " #{format('%+d', roll.status_modifier)} (statü)" unless roll.status_modifier.zero?
      <<~TEXT
        ZAR SONUCU: "#{roll.choice.label}" seçildi.
        d20=#{roll.value} #{format('%+d', roll.modifier)}#{status} = #{roll.total}, hedef #{roll.target} → #{grade_label(roll)}.
      TEXT
    end

    def grade_label(roll)
      GRADES.fetch(roll.grade) % { margin: roll.margin.abs }
    end

    def action_block
      roll = @game_session.rolls.order(:id).last
      return "İlk sahneyi yaz." if roll.nil?

      "#{roll_block(roll)}ÇÖZÜMLEME: #{roll.resolution}\n\nBu çözümleme oyuncuya gösterildi: olanları yeniden sahneleme, devamını yaz."
    end
end
