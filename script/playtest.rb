ActiveJob::Base.queue_adapter = :inline
ActiveRecord::Base.logger = nil

def show_scene(scene)
  character = scene.active_player.character
  session = scene.game_session
  puts "\n=== SAHNE #{scene.position}/#{session.scene_budget} — #{scene.title} @ #{scene.location} #{"(FİNAL)" if scene.finale?} (#{scene.narration.to_s.split.size} kelime)"
  puts scene.narration
  puts "\nCAN #{character.hp}/#{character.max_hp} | EŞYA: #{character.items.carried.map(&:summary).join("; ").presence || "boş"} | STATÜ: #{character.status_effects.map(&:summary).join("; ").presence || "yok"}"

  if session.finished?
    puts "\n*** OYUN BİTTİ: #{session.outcome.upcase} *** maliyet $#{format('%.3f', session.llm_calls.sum(:cost_in_microdollars) / 1e6)}"
  else
    scene.choices.order(:id).each_with_index do |choice, index|
      puts "  #{index + 1}) [#{Character::STATS[choice.stat]} #{format('%+d', choice.modifier)} | #{choice.difficulty_label} hedef #{choice.difficulty}] #{choice.label} — #{choice.difficulty_reason}"
    end
  end
end

def show_roll(roll)
  status = " #{format('%+d', roll.status_modifier)} statü" unless roll.status_modifier.zero?
  puts "\nZAR: d20=#{roll.value} #{format('%+d', roll.modifier)}#{status} = #{roll.total} vs #{roll.target} → #{roll.grade.to_s.upcase}"
  puts "SONUÇ: #{roll.resolution}"
  effects = roll.effects.to_h.reject { |_, value| value.blank? || value == 0 }
  puts "ETKİ: #{effects.inspect}" if effects.any?
end

def timed(label)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = yield
  puts "(#{label}: #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)}s)"
  result
end

def allocate_stats(klass)
  stats = Character.base_stats_for(klass).dup
  Character::FREE_POINTS.times do
    key = stats.select { |_, value| value < Character::STAT_CAP }.max_by { |_, value| value }.first
    stats[key] += 1
  end
  stats
end

def start_game(adventure_title, tone, length, race, klass, background)
  user = User.find_or_create_by!(email: "playtest-#{ENV.fetch('BOT', 'a')}@rokapi.test") do |new_user|
    new_user.name = ENV.fetch("BOT_NAME", "Ege")
    new_user.terms_accepted_at = Time.current
  end
  Current.session = Session.new(user: user)
  adventure = adventure_title == "surprise" ? nil : Adventure.find_by!(title: adventure_title)
  game_session = GameSession.create!(mode: :solo, adventure: adventure, tone: tone, length: length, creator: user)
  timed("plan+sahne1") { game_session.players.first.ready_up(race: race, klass: klass, background: background, stats: allocate_stats(klass)) }
  game_session.reload
  puts "SESSION #{game_session.id} — #{game_session.title} (#{RubyLLM.config.default_model})"
  puts "KİTAP: #{JSON.pretty_generate(game_session.story_bible)}" if ENV["SHOW_BIBLE"]
  show_scene game_session.current_scene
  game_session
end

def take(game_session, choice)
  puts "\n>>> SEÇİM: #{choice.label}"
  choice.choose
  play_out game_session
end

def play_out(game_session)
  scene = game_session.current_scene
  roll = timed("çözümleme") { scene.roll_dice(by: scene.active_player) }
  show_roll roll.reload
  timed("sahne") { roll.acknowledge }
  show_scene game_session.reload.current_scene
end

def catch_up(game_session)
  scene = game_session.current_scene
  if scene.rolling?
    play_out game_session
  elsif !scene.choosing?
    timed("devam") { game_session.continue_narration }
    show_scene game_session.reload.current_scene
  end
end

def load_game(id)
  GameSession.find(id).tap { |game_session| Current.session = Session.new(user: game_session.creator) }
end

command = ARGV.shift
case command
when "new"
  start_game(*ARGV)
when "choose"
  game_session = load_game(ARGV[0])
  scene = game_session.current_scene
  abort "sahne seçim beklemiyor (#{scene.state})" unless scene.choosing?
  take game_session, scene.choices.order(:id)[ARGV[1].to_i - 1] || abort("seçenek yok")
when "drink"
  game_session = load_game(ARGV[0])
  character = game_session.players.first.character
  item = character.items.healing.first || abort("şifa eşyası yok")
  item.use
  puts "#{item.name} içildi → CAN #{character.reload.hp}/#{character.max_hp}"
when "resume"
  catch_up load_game(ARGV[0])
when "auto"
  strategy = ARGV.pop
  game_session = ENV["SESSION"].present? ? load_game(ENV["SESSION"]) : start_game(*ARGV)
  rng = Random.new(game_session.id)

  until game_session.finished?
    catch_up game_session
    game_session.reload
    break if game_session.finished?

    scene = game_session.current_scene
    character = scene.active_player.character
    if character.hp_percentage < 50 && (potion = character.items.healing.first)
      potion.use
      puts "\n>>> #{potion.name} içildi → CAN #{character.reload.hp}/#{character.max_hp}"
    end

    choices = scene.choices.order(:difficulty).to_a
    take game_session, case strategy
                       when "bold" then choices.last
                       when "safe" then choices.first
                       else choices[rng.rand(3)]
                       end
    game_session.reload
  end
else
  abort <<~USAGE
    kullanım: bin/rails runner script/playtest.rb <komut>
      new <macera|surprise> <fun|balanced|dark> <short|medium|long> <race> <klass> <background>
      choose <session_id> <1|2|3>
      drink <session_id>
      resume <session_id>
      auto <macera|surprise> <ton> <uzunluk> <race> <klass> <background> <mixed|bold|safe>
      SESSION=<id> auto <mixed|bold|safe>   (yarım kalan oturumu botla bitirir)
  USAGE
end
