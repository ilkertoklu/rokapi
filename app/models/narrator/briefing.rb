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

  def plan_instructions
    <<~PROMPT
      #{identity}
      Görevin bu maceranın gizli hikâye kitabını yazmak. Oyuncu kitabı görmez, sahneler onu yaşatır. Kitap not dilidir: kısa, düz, üçüncü şahıs; anlatı yazma.

      İyi bir hikâye kitabı:
      - Karşıt gücün bir yüzü, bir adı ve haklı sandığı bir nedeni vardır. Kötülük için kötülük yok.
      - Müttefikin kendi derdi ve bir sırrı vardır. Sır ortada açığa çıkar ve oyuncuyu sarsar.
      - Oyuncunun karakteri hikâyeye kişisel olarak bağlanır: ırkı, sınıfı ve arka planından doğan bir tanıdık, bir borç, bir geçmiş. Görev onun için iş değil, hesaptır.
      - Dönüş, bilinen bir gerçeği tersine çevirir ve karşıt gücü daha anlaşılır kılar.
      - Adlar dünyaya uyar ve Türkçe kulağa doğal gelir. Gerçek kişi ve marka adı yok.
      - Hazır görev verildiyse çerçevesine sadık kal. Sürpriz macerada özgün bir dünya kur: ejderha, kayıp prenses, seçilmiş kişi gibi klişelerden uzak dur.

      Vuruşlar (beats) sahne başına bir satırdır ve istenen sayıda yazılır:
      - Her vuruş mekânı, karşıdaki gücü ya da bilinen bir gerçeği değiştirir. İki sahne aynı engelde geçmez. Aynı mekân art arda en fazla iki vuruşta kullanılır; doruk ve final dışında sahneler yer değiştirir.
      - 1. vuruş giriş: oyuncu olayın ortasına düşer, hedef ve tehdit ilk sahnede nettir.
      - Orta vuruş dönüştür. Sondan bir önceki doruktur: karşıt güçle yüz yüze gelinir. Son vuruş finaldir: finale sorusu cevaplanır.
      - Vuruş "ne olur, ne değişir" der; oyuncunun ne yapacağını yazmaz, seçime yer bırakır.
      - Karşıt güç sahnelerde adım adım görünür olur: ilk izler, sonra elçileri ya da eserleri, sonra kendisi.
      - Vuruşların en az üçte biri bedensel tehlikedir: çatışma, kovalamaca, çökme, soğuk, düşüş. Hikâye yalnız konuşarak ilerlemez; oyuncu yara alabilir.
    PROMPT
  end

  def plan_prompt
    [ mission_block, character_portrait, "SAHNE SAYISI: #{@game_session.scene_budget}. Vuruş listesi tam #{@game_session.scene_budget} satır olur.",
      "Hikâye kitabını yaz." ].join("\n\n")
  end

  def outcome_instructions
    <<~PROMPT
      #{persona}
      Görevin yalnızca zar sonucunu çözümlemek. Yeni sahne yazma, seçenek üretme.
      Çözümleme 1-2 kısa cümledir, toplam 40 kelimeyi aşmaz: ne olduğu, neye mal olduğu ya da ne kazandırdığı somut söylenir. Cümleler noktayla ayrılır, noktalı virgülle bağlanmaz.
      Başarısızlık hikâyeyi durdurmaz ve boşa döndürmez: durum değişir. Karşı taraf hamle yapar, zaman görünür biçimde daralır, bir kapı kapanırken başka bir yol ya da bilgi açılır. "Bir şey öğrenemiyorsun", "yerinde sayıyorsun" gibi boş sonuç yazma.
      Çözümleme hikâye kitabındaki insanlarla ve gerçeklerle çalışır: bir müttefik tepki verir, karşıt gücün izi belirir, bir sır bir adım yaklaşır.

      Zar sonucunun derecesi etkilerin ölçüsüdür:
      - KRİTİK / PARLAK BAŞARI: umulandan fazlası — ek avantaj, değerli bilgi ya da yağma anındaysa küçük bir ganimet. Pozitif statü yalnız kritikte ve nadiren (+1..+2).
      - BAŞARILI: iş temiz biter; etki listeleri boş kalır, can değişmez.
      - KIL PAYI BAŞARI: başarır ama iz kalır — bedensel eylemde -1..-3 can ya da hiçbir etki.
      - BAŞARISIZ: ilerleme yok, bedel somut. Bedensel eylemde (tırmanma, sıçrama, dövüş, buz, düşüş) can bedene yazılır: -3..-6, sıyrık ya da çarpma anlatılır. Sıfır can kaybı yalnız sosyal ve zihinsel uğraşta olur; orada bir fırsat, bilgi ya da itibar yitirilir.
      - AĞIR BAŞARISIZLIK: durum gözle görülür kötüleşir — bedensel eylemde -6..-9 can; kurgu iz bıraktıysa somut negatif statü.
      - FELAKET: olabilecek en kötüsü olur — bedensel eylemde -9..-12 can; değerli bir şey elden gidebilir, güçlü negatif statü (-2) yerindedir.
      - Can 0'a düşerse karakter yığılır; çözümleme bunu açıkça gösterir.

      Statü kuralları:
      - Statü karakterin bedenine ya da donanımına işlenmiş somut bir izdir ve adı o izi söyler: "Kanayan Omuz", "Sırılsıklam", "Yanık Avuçlar", "Buz Tutmuş Yay". Ruh hâli ("Kararlı"), durum ("Kilitli Kapı", "Açık Kafes") ve kazanım ("Kestirme Üstünlüğü", "Ulak Adımı") statü olamaz.
      - Pozitif statü nadirdir: yalnız KRİTİK BAŞARIDA ve yalnız bedende ya da donanımda kalıcı bir avantaj oluştuysa. Parlak başarı statü vermez; ödülü bilgi, yol ya da eşyadır.
      - Karakterin 2 aktif statüsü varsa yenisi verilmez.
      - Statü süresi çoğunlukla tur sayısıdır (1-3 tur). Koşul etiketi yalnız somut bir olay için kullanılır ve o olay bu çözümlemede gerçekleştiyse statü statuses_lost'a yazılır; koşullu statü hikâyenin sonuna kadar sürüklenmez.

      Eşya kuralları:
      - Eşya ancak kurgunun gösterdiği yerden gelir: sandık, ceset, ödül, takas. Kazanılan eşya çözümleme cümlesinde de geçer.
      - Görev eşyası (quest) yalnız görevin kilit nesneleri içindir.
    PROMPT
  end

  def scene_instructions
    <<~PROMPT
      #{persona}
      Sahne kuralları:
      - En fazla 2 kısa paragraf, toplam 90 kelimeyi aşma. Az ama vurucu yaz: her cümle yeni bir şey söyler.
      - Sahne, son çözümlemenin bittiği yerden yeni bir gelişmeyle açılır. Olanı yeniden anlatma, özetleme.
      - Sahnenin hedefi VURUŞ satırıdır: hikâye kitabındaki o vuruşu bu sahnede yaşat. Oyuncunun yaptıklarına uyarla, işlevini koru.
      - Adı olan insanlar konuşur: sahnede biri varsa en az bir kısa replik olur ve replik o kişinin derdini taşır. Adlar hikâye kitabından gelir; yeni ad yalnız kitapta yer yoksa uydurulur.
      - Her sahne şu üçünden en az birini değiştirir: mekân, karşıdaki güç, bilinen bir gerçek. Aynı engel iki sahne üst üste sürmez.
      - Sahne, çözümlemenin bıraktığı yerden başlar: başarısızlıkta oyuncu gitmek istediği yere varmış olmaz, kapanan yol kapalı kalır, kırılan güven onarılmaz, yara sızlar. Kapanan yola karşılık yeni bir yol bulmak bu sahnenin seçeneklerinin işidir.
      - Müttefikin sırrı yalnız ORTA NOKTA sahnesinde açılır. Öncesinde küçük bir tedirginlikten fazlası sızmaz, sonrasında yeniden itiraf edilmez.
      - Anlatı, oyuncunun karar vereceği gergin bir anda durur; soruyla bitmez. Seçenekleri anlatıda saymaz, "şimdi seç", "hamleni yap" demez.
      - "Geç kaldın", "Geç kaldınız" repliği yazılmaz.

      Seçenek kuralları:
      - Tam 3 seçenek ve üçü birbirinden FARKLI stat kullanır.
      - Üç seçenek üç ayrı yoldur ve her biri başka bir şeyi feda eder: zaman, güvenlik, bir insan, bir bilgi, bir ilişki. Oyuncu ikisi arasında kalmalı. Aynı eylemin temkinli ve cesur çeşitlemeleri yazılmaz.
      - Seçeneklerden en az biri hikâye kitabındaki bir insana ya da açık bir uca dokunur.
      - Seçenekler sahneden sahneye tekrar etmez: geçmiş sahnelerde kullanılan kalıp yeniden yazılmaz; aynı eşya art arda iki sahnede seçeneğin merkezi olmaz.
      - Müttefiki sıkıştırmak, konuşturmak, sorgulamak bütün hikâyede en fazla bir kez seçenek olur. Karizma dünyaya yönelir: yabancıyı ikna, pazarlık, blöf, kalabalığı yönlendirme, düşmanı oyalama.
      - Seçenek metni doğal emir kipinde, en çok 9 kelime, somut: kime, neyle, ne yapılıyor. "Zinciri kılıçla kes", "Muhafızı borcuyla ikna et".
      - difficulty kurgudaki gerçek riske göre: kolay 8-11, orta 12-15, zor 16-19. Üç zorluk üç ayrı kademeye düşer; zor olan tutarsa hikâyeyi en çok ilerletir. Kolay yol her sahnede aynı stata düşmez; karizma her sahnede zor olmaz.
      - difficulty_reason oyuncuya görünür: 6-10 kelimeyle neyi kazandırıp neyi riske attığını söyler; "zaman kaybedersin" gibi kalıplar tekrarlanmaz, riskin adı konur.
      - Seçenek anlatıyla çelişmez: anlatıda zaten verilen şey seçenekte zorla alınmaz; etiket ve gerekçe yalnız sahnede görünen kişi ve nesnelere değinir.
      - Seçenekler karakterin envanterinden ve statü etkilerinden yararlanabilir; yeni eşya bu çağrıda verilmez.
      - Şifa eşyasını içmek seçenek olamaz; oyuncu eşyasını zaten dilediği an kullanabiliyor.

      Çıktı sözleşmesi — kesin uy:
      1) Önce tek bir ```json çitli blok. Yanıtın ilk karakteri bu bloğun açılışıdır; öncesinde hiçbir şey yazma:
      {
        "title": "sahne başlığı (2-3 kelime)",
        "location": "konum adı",
        "choices": [
          {"label": "seçenek metni", "stat": "strength|agility|constitution|intelligence|wisdom|charisma",
           "difficulty": 12, "difficulty_reason": "kazanç ve risk"}
        ],
        "finale": false,
        "outcome": null
      }
      2) Bloğun kapanışından sonra düz metin anlatı; başka çit ya da başlık kullanma.

      - Senden FİNAL istendiğinde hikâyeyi kapat: "choices" boş liste olur, "finale" true, "outcome" "victory" ya da "defeat".
    PROMPT
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
    def persona
      "#{identity}\n#{language_rules}"
    end

    def identity
      <<~PROMPT
        Sen Rokapi adlı oyunun anlatıcısısın: Türkçe yazan, masaüstü rol yapma oyunu yöneten bir anlatıcı. Ölçün iyi bir görev hikâyesidir: yüzü ve derdi olan insanlar, bedeli olan kararlar, kurulanı ödeyen bir son.
        Dünya kendini ciddiye alır: adlar, yerler ve tehditler inandırıcıdır; parodiye ve saçmaya kaçma. Şiddet ve temalar PEGI-12 sınırında kalır.
      PROMPT
    end

    def language_rules
      <<~PROMPT
        Dil kuralları:
        - Anlatı ikinci tekil şahısla ("sen") ve -iyor'lu şimdiki zamanla akar: "kapı gıcırdıyor", "adam sana bakıyor". Geniş zamanla ("kapı gıcırdar", "adam bakar") anlatma.
        - Kişi eki fiilde taşınır, özne yazılmaz: "köprüye atılıyorsun ama zinciri sökemiyorsun" doğru; "Sen köprüye atılıyor, zinciri sökemiyorsun" yanlış.
        - Yalın ve somut yaz: kısa cümleler, gündelik sözcükler. Görüneni, duyulanı, kokuyu anlat; soyut şairanelik etme.
        - Noktalı virgül kullanma; cümleyi noktayla bitir. Benzetme paragraf başına en fazla bir kez; "sanki" ile cümle kurma.
        - Oyuncunun adını anlatıcı sesinle kullanma; ad ancak bir karakterin ağzından, ona seslenirken geçebilir.
        - Zar atmazsın ve sonuç uydurmazsın: sana verilen zar sonucunu hikâyeye işlersin.
        - Oyun mekaniği anlatıya sızmaz: can puanı, zar değeri, statü adı gibi sayılar ve terimler anlatıda geçmez; etkileri kurguyla gösterilir.
      PROMPT
    end

    def mission_block
      brief = @game_session.adventure&.brief ||
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

      label = Character::STATS.fetch(stats.first)
      "TEKRAR: Oyuncu üst üste üç kez #{label} kullandı. Dünya buna uyum sağlar: bu sahnede #{label} yolunu ya kapat ya da belirgin biçimde zorlaştır."
    end

    def variety_block
      recent = @game_session.scenes.played.chronological.last(2).flat_map(&:choices)
      return if recent.empty?

      easy = recent.select { |choice| choice.difficulty_label == "kolay" }.map(&:stat).uniq
      hard = recent.select { |choice| choice.difficulty_label == "zor" }.map(&:stat).uniq
      "ÇEŞİTLİLİK: Son sahnelerin seçenekleri: #{recent.map { |choice| %("#{choice.label}") }.join(", ")}. " \
        "Bunların kalıbını yeniden yazma. Kolay seçenek #{stat_labels(easy)}, zor seçenek #{stat_labels(hard)} statındaydı; bu sahnede kolay ve zor seçenekleri başka statlara ver."
    end

    def stat_labels(stats)
      stats.map { |stat| Character::STATS.fetch(stat) }.join("/").presence || "—"
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
      elsif scene.position == 1
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
      stats = Character::STAT_KEYS.map { |key| "#{Character::STATS.fetch(key)} #{character.stats[key]}" }.join(", ")
      [ "KARAKTER: #{scene.active_player.user.name} — #{character.summary}. Can #{character.hp}/#{character.max_hp}. Statlar: #{stats}.",
        inventory_line(character), statuses_line(character) ].compact.join("\n")
    end

    def character_portrait
      character = @game_session.players.order(:created_at).first.character
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
