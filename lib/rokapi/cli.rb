require "thor"
require_relative "client"

module Rokapi
  class CLI < Thor
    POLL_INTERVAL = 1

    class_option :as, default: ENV.fetch("ROKAPI_AS", "agent@rokapi.test"), desc: "Email to play as; each email keeps its own login and game"
    class_option :url, default: ENV.fetch("ROKAPI_URL", "http://localhost:3000"), desc: "Server to play against"
    class_option :game, type: :numeric, desc: "Game id (defaults to the last game started)"
    class_option :json, type: :boolean, desc: "Print the game as raw JSON"
    class_option :wait, type: :numeric, default: 300, desc: "Seconds to wait for the narrator"

    def self.exit_on_failure? = true

    desc "login", "Log in, reading the code from tmp/mails in development"
    option :name, desc: "Profile name for a new account"
    option :code, desc: "Login code, when it cannot be read from tmp/mails"
    def login
      client.login name: options[:name] || options[:as].split("@").first.capitalize, code: options[:code]
      say "Logged in as #{options[:as]}."
    end

    desc "locale LOCALE", "Play new games in en or tr"
    def locale(locale)
      raise Thor::Error, "Pick en or tr." unless %w[en tr].include?(locale)

      authenticated { client.patch "/locale", locale: locale }
      say "New games will be played in #{locale}."
    end

    desc "cards", "Show a sample hand of fate cards, the tones and the lengths"
    def cards
      catalog = fetch("/game_sessions/solo/new.json")

      say "CARDS (--card): every new game deals a fresh hand and plays the card at that position"
      catalog["cards"].each.with_index(1) { |card, position| say "  #{position} — #{describe(card)}" }
      say "  surprise — a card drawn face down"
      say "TONES (--tone): #{catalog["tones"].map { |tone| tone["key"] }.join(", ")}"
      say "LENGTHS (--length): #{catalog["lengths"].map { |length| "#{length["key"]} (#{length["scenes"]} scenes)" }.join(", ")}"
    end

    desc "new", "Start a solo game"
    option :card, default: "1", desc: "Position of the card to play from a fresh hand, or surprise"
    option :tone, default: "balanced"
    option :length, default: "medium"
    def new
      response = act(:post, "/game_sessions/solo.json", game_session: setup("solo"))
      client.game_id = response.location[%r{/game_sessions/(\d+)}, 1].to_i

      say "Game #{client.game_id} created."
      heroes
    end

    desc "multi", "Open a multiplayer room and print its code"
    option :card, default: "1", desc: "Position of the card to play from a fresh hand, or surprise"
    option :tone, default: "balanced"
    option :length, default: "medium"
    def multi
      room = act(:post, "/game_sessions/multi.json", game_session: setup("multi")).json
      client.game_id = room["id"]

      say "Room #{room["code"]} open as game #{room["id"]}. Friends join with: bin/rokapi join #{room["code"]} --as FRIEND"
      heroes
    end

    desc "join CODE", "Join a friend's room by its 4-digit code"
    def join(code)
      response = act(:post, "/game_sessions/join.json", code: code)
      client.game_id = response.location[%r{/game_sessions/(\d+)}, 1].to_i

      say "Joined room #{code} as game #{client.game_id}."
      heroes
    end

    desc "heroes", "List races, classes and backgrounds for the character"
    def heroes
      catalog = character_catalog

      say "RACES: #{catalog["races"].map { |race| race["key"] }.join(", ")}"
      say "CLASSES:"
      catalog["klasses"].each do |klass|
        say "  #{klass["key"]} — #{klass["base_hp"]} hp, #{klass["base_stats"].map { |stat, value| "#{stat} #{value}" }.join(", ")}"
      end
      say "BACKGROUNDS: #{catalog["backgrounds"].map { |background| background["key"] }.join(", ")}"
      say "Spend #{catalog["free_points"]} points on top of the class stats, #{catalog["stat_cap"]} at most per stat."
      next_step "character RACE CLASS BACKGROUND [--stats strength=16,constitution=15]"
    end

    desc "character RACE CLASS BACKGROUND", "Create the character and wait for the opening scene"
    option :stats, desc: "Final stat values, e.g. strength=16,constitution=15; unlisted stats stay at the class base. Points are spent automatically when omitted"
    def character(race, klass, background)
      chosen = character_catalog["klasses"].find { |candidate| candidate["key"] == klass } or raise Thor::Error, "No such class: #{klass}"

      act :post, "#{game_path}/character.json", character: { race: race, klass: klass, background: background, stats: stats_for(chosen) }
      settle
    end

    desc "start", "Start the multiplayer game as its host and wait for the opening scene"
    def start
      act :post, "#{game_path}/start.json"
      settle
    end

    desc "rematch", "After a party game, take everyone into a fresh lobby with the same settings"
    def rematch
      response = act(:post, "#{game_path}/rematch.json")
      client.game_id = response.location[%r{/game_sessions/(\d+)}, 1].to_i

      say "Game #{client.game_id} is the new lobby."
      present fetch("/game_sessions/#{client.game_id}.json")
    end

    desc "show", "Show where the game stands and what to do next; in a party game, wait for your turn"
    def show
      game = self.game
      watching?(game) && !options[:json] ? watch : present(game)
    end

    desc "story", "Show every scene so far"
    def story
      game = self.game
      return puts(JSON.pretty_generate(game)) if options[:json]

      game["scenes"].each do |scene|
        say_scene game, scene
        say "(#{scene["active_player"]}’s turn)" if game["multiplayer"]
        say_choice scene
        say_roll scene["roll"], ending: scene["finale"] if scene["roll"]&.fetch("resolved")
      end
      say_footer game
    end

    desc "adventures", "List your finished adventures, newest first"
    def adventures
      shelf = fetch("/my/adventures.json")
      return puts(JSON.pretty_generate(shelf)) if options[:json]
      return say("No finished adventures yet.") if shelf.empty?

      shelf.each do |adventure|
        say "#{adventure["id"]} — #{adventure["title"]} · #{adventure["outcome"]} · #{adventure["ended_at"].to_s[0, 10]} · #{adventure["hero"]}"
      end
      next_step "adventure ID"
    end

    desc "adventure [ID]", "Read a finished adventure from its first scene to its closing (defaults to the last game started)"
    def adventure(id = nil)
      id ||= options[:game] || client.game_id || raise(Thor::Error, "Pick an adventure: bin/rokapi adventures")
      adventure = fetch("/my/adventures/#{id}.json")
      return puts(JSON.pretty_generate(adventure)) if options[:json]

      say "#{adventure["title"]} · #{adventure["hero"]}"
      adventure["scenes"].each do |scene|
        say_scene adventure, scene
        next unless (choice = scene["choice"])

        say "\n>>> CHOICE#{" by #{choice["by"]}" if adventure["multiplayer"]}: #{choice["label"]} [#{choice["stat"]} #{format("%+d", choice["modifier"])} | #{choice["difficulty"]}, target #{choice["target"]}]"
        say_roll scene["roll"], ending: scene["finale"] if scene["roll"]
      end

      say "\n*** #{adventure["outcome"].to_s.upcase} ***"
      say "PARTY: #{adventure["party"].map { |player| "#{player["name"]}#{" (fallen)" unless player["alive"]}" }.join(", ")}" if adventure["multiplayer"]
    end

    desc "choose NUMBER", "Pick one of the scene's choices"
    def choose(number)
      choice = current_scene(game)["choices"][number.to_i - 1] || raise(Thor::Error, "No choice #{number}; pick 1, 2 or 3.")

      act :post, "#{game_path}/choices/#{choice["id"]}/selection.json"
      present game, narration: false
    end

    desc "roll", "Roll the die and wait for the outcome"
    def roll
      act :post, "#{game_path}/roll.json"
      settle narration: false
    end

    desc "continue", "Move on from the outcome and wait for the next scene"
    def continue
      act :post, "#{game_path}/acknowledgement.json"
      settle
    end

    desc "use ITEM", "Use an item by id or name, e.g. a healing potion"
    def use(item)
      character = game["character"]
      found = character["items"].find { |candidate| candidate["id"].to_s == item || candidate["name"].casecmp?(item) } ||
        raise(Thor::Error, "No item #{item}. Carried: #{character["items"].map { |candidate| "#{candidate["id"]} #{candidate["name"]}" }.join(", ")}")
      raise Thor::Error, "#{found["name"]} is not used on its own; it counts when a choice calls for it." unless found["usable"]

      act :post, "#{game_path}/items/#{found["id"]}/use.json"
      after = game["character"]
      say "#{found["name"]} used: HP #{character["hp"]} → #{after["hp"]}/#{after["max_hp"]}."
    end

    desc "resume", "Ask the narrator to retry a stalled scene or outcome"
    def resume
      act :post, "#{game_path}/narration.json"
      settle
    end

    private
      def client
        @client ||= Client.new(url: options[:url], email: options[:as])
      end

      def game_path
        id = options[:game] || client.game_id || raise(Thor::Error, "No game yet. Start one with: bin/rokapi new")
        "/game_sessions/#{id}"
      end

      def game
        fetch "#{game_path}.json"
      end

      def setup(mode)
        { card: card_key(mode), tone: options[:tone], length: options[:length] }
      end

      def card_key(mode)
        return "" if options[:card] == "surprise"

        hand = fetch("/game_sessions/#{mode}/new.json")["cards"]
        card = hand[options[:card].to_i - 1] if options[:card].to_i.positive?
        raise Thor::Error, "Pick a card from 1 to #{hand.size}, or surprise." unless card

        say "Card: #{describe(card)}"
        card["key"]
      end

      def describe(card)
        card.values_at("place", "trouble", "figure").join(" · ")
      end

      def character_catalog
        response = authenticated { client.get("#{game_path}/character/new.json") }
        raise Thor::Error, "This game already has a character. Run: bin/rokapi show" if response.redirect?
        raise Thor::Error, failure(response) unless response.success?

        response.json
      end

      def stats_for(klass)
        if options[:stats]
          options[:stats].split(",").each_with_object(klass["base_stats"].dup) do |pair, stats|
            stat, value = pair.split("=")
            stats[stat.strip] = value.to_i
          end
        else
          klass["suggested_stats"]
        end
      end

      def fetch(path)
        response = authenticated { client.get(path) }
        raise Thor::Error, failure(response) unless response.success?

        response.json
      end

      def act(verb, path, params = {})
        response = authenticated { client.public_send(verb, path, params) }
        raise Thor::Error, failure(response) unless response.success?

        response
      end

      def authenticated
        login unless client.logged_in?
        response = yield

        if response.unauthorized?
          login
          response = yield
        end

        response
      end

      def failure(response)
        case response.status
        when 402 then response.json["error"]
        when 403 then "It is not your turn."
        when 404 then "Not found. Check the game id or item."
        when 409 then "#{response.json? ? response.json["error"] : "That does not fit where the game stands."} Run: bin/rokapi show"
        when 422 then explanation(response)
        when 429 then "Rate limited. Wait a few minutes."
        when 300..399 then "Redirected to #{response.location}."
        else "The server answered #{response.status}."
        end
      end

      def explanation(response)
        return "Rejected: #{response.body}" unless response.json?

        response.json.map { |field, messages| messages.is_a?(Array) ? "#{field} #{messages.join(", ")}" : messages }.join("; ")
      end

      def settle(narration: true)
        streamed = {}
        deadline = Time.now + options[:wait]

        loop do
          game = self.game
          stream game, streamed if narration && !options[:json]
          return present(game, streamed: streamed, narration: narration) unless busy?(game)
          raise Thor::Error, "Still waiting after #{options[:wait]}s. Run: bin/rokapi show" if Time.now > deadline

          sleep POLL_INTERVAL
        end
      end

      def watch
        streamed = {}
        reported = []
        deadline = Time.now + options[:wait]

        loop do
          game = self.game
          stream game, streamed
          report game, reported
          return present(game, streamed: streamed) unless watching?(game) || busy?(game)
          raise Thor::Error, "Still not your turn after #{options[:wait]}s. Run: bin/rokapi show" if Time.now > deadline

          sleep POLL_INTERVAL
        end
      end

      def report(game, reported)
        return unless watching?(game)

        scene = current_scene(game)
        actor = scene["active_player"]
        choice = scene["choices"].find { |candidate| candidate["chosen"] }
        roll = scene["roll"]
        events = [ "#{actor}’s turn" ]
        events << "#{actor} chose: #{choice["label"]} [#{choice["stat"]} #{format("%+d", choice["modifier"])}, target #{choice["target"]}]" if choice
        if roll&.fetch("resolved")
          events << "#{actor} rolled d20=#{roll["value"]} → #{roll["total"]} vs #{roll["target"]}, #{roll["grade"].upcase}: #{roll["resolution"]}"
          roll["effects"]["items_gained"].each { |item| events << "Added to inventory: #{item["name"]} · found by #{actor}" }
        end

        events.each do |event|
          key = "#{scene["position"]}: #{event}"
          next if reported.include?(key)

          say "\n>>> #{event}"
          reported << key
        end
      end

      def watching?(game)
        game["step"] == "watching"
      end

      def busy?(game)
        %w[ opening writing resolving ].include?(game["step"])
      end

      def stream(game, streamed)
        scene = current_scene(game) or return
        narration = scene["narration"].to_s
        return if narration.empty?

        unless streamed.key?(scene["position"])
          say_scene_heading game, scene
          streamed[scene["position"]] = ""
        end

        shown = streamed[scene["position"]]
        print narration.start_with?(shown) ? narration.delete_prefix(shown) : "\n\n(rewritten)\n#{narration}"
        $stdout.flush
        streamed[scene["position"]] = narration
      end

      def present(game, streamed: {}, narration: true)
        return puts(JSON.pretty_generate(game)) if options[:json]

        case game["step"]
        when "lobby"
          say_lobby game
        when "character"
          say "The game has no character yet."
          next_step "heroes"
        when "opening"
          say "The narrator is getting the opening scene ready."
          next_step "show"
        else
          say_stage game, streamed: streamed, narration: narration
        end
      end

      def say_stage(game, streamed:, narration:)
        scene = current_scene(game)
        roll = scene["roll"]

        if streamed.key?(scene["position"])
          puts
        elsif narration
          say_scene game, scene
        else
          say_scene_heading game, scene
        end
        say_status game
        say_party game, scene if game["multiplayer"]

        case game["step"]
        when "finished"
          say_choice scene
          say_roll roll, ending: true if roll
          say_footer game
          next_step game["multiplayer"] ? "rematch" : "new"
        when "watching"
          say "\n#{scene["active_player"]}’s turn. You are watching."
          next_step "show (waits for your turn)"
        when "stalled"
          say "\nThe narrator stalled."
          next_step "resume"
        when "writing"
          say "\nThe narrator is still writing."
          next_step "show"
        when "choosing"
          say "\nCHOICES"
          scene["choices"].each_with_index do |choice, index|
            say "  #{index + 1}) [#{choice["stat"]} #{format("%+d", choice["modifier"])} | #{choice["difficulty"]}, target #{choice["target"]}] #{choice["label"]}"
          end
          next_step "choose #{(1..scene["choices"].size).to_a.join("|")}#{usable_hint(game)}"
        when "rolling"
          say_choice scene
          next_step "roll#{usable_hint(game)}"
        when "resolving"
          say "\nThe narrator is resolving the roll."
          next_step "show"
        when "outcome"
          say_choice scene
          say_roll roll
          next_step "continue#{usable_hint(game)}"
        end
      end

      def say_lobby(game)
        say "LOBBY: room #{game["code"]} · #{game["title"]} · #{game["players"].size}/#{game["max_players"]} players"
        game["players"].each do |player|
          badges = [ ("YOU" if player["you"]), ("HOST" if player["host"]) ].compact.join(" ")
          say "  #{player["ready"] ? "ready    " : "preparing"} #{player["name"]} #{badges} #{player["summary"]}".rstrip
        end

        if game["character"].nil?
          next_step "heroes"
        elsif game["host"] && game["everyone_ready"]
          next_step "start"
        else
          say "\nWaiting for #{game["host"] ? "everyone to make a character" : "the host to start"}."
          next_step "show"
        end
      end

      def say_scene_heading(game, scene)
        finale = " (FINALE)" if scene["finale"]
        say "\n=== SCENE #{scene["position"]}/#{game["scene_budget"]} — #{scene["title"] || "…"} @ #{scene["location"] || "…"}#{finale}"
      end

      def say_scene(game, scene)
        say_scene_heading game, scene
        say scene["narration"].to_s
        say_effects scene["effects"]
      end

      def say_status(game)
        character = game["character"]
        items = character["items"].map { |item| item["usable"] ? "#{item["summary"]} [use #{item["id"]}]" : item["summary"] }
        statuses = character["statuses"].map { |status| status["summary"] }

        say "\nHP #{character["hp"]}/#{character["max_hp"]} | ITEMS: #{items.join("; ").then { it.empty? ? "none" : it }} | STATUSES: #{statuses.join("; ").then { it.empty? ? "none" : it }}"
      end

      def say_party(game, scene)
        party = game["party"].map { |player| "#{player["name"]}#{" (you)" if player["you"]}#{" ◀ turn" if player["name"] == scene["active_player"]} — #{player["summary"]}" }
        say "PARTY: #{party.join(" | ")}"
      end

      def say_choice(scene)
        choice = scene["choices"].find { |candidate| candidate["chosen"] } or return
        say "\n>>> CHOICE: #{choice["label"]} [#{choice["stat"]} #{format("%+d", choice["modifier"])} | #{choice["difficulty"]}, target #{choice["target"]}]"
      end

      def say_roll(roll, ending: false)
        status = " #{format("%+d", roll["status_modifier"])} status" unless roll["status_modifier"].zero?
        say "ROLL: d20=#{roll["value"]} #{format("%+d", roll["modifier"])}#{status} = #{roll["total"]} vs #{roll["target"]} → #{roll["grade"].upcase}"
        say "#{ending ? "ENDING" : "RESULT"}: #{roll["resolution"]}"
        say_effects roll["effects"]
      end

      def say_effects(effects)
        effects = effects.to_h
        changes = []
        changes << "HP #{format("%+d", effects["hp"])}" if effects["hp"].to_i.nonzero?
        changes += Array(effects["items_gained"]).map { "Added to inventory: #{it["name"]}" }
        changes += Array(effects["items_lost"]).map { "Lost: #{it}" }
        changes += Array(effects["statuses_gained"]).map { "Status: #{it["name"]}" }
        changes += Array(effects["statuses_lost"]).map { "Status ended: #{it}" }
        say changes.join(" · ") if changes.any?
      end

      def say_footer(game)
        return unless game["finished"]

        say "\n*** GAME OVER: #{game["outcome"].to_s.upcase} *** cost #{game["cost"] ? format("$%.3f", game["cost"]) : "unknown"}"
        say "PARTY: #{game["party"].map { |player| "#{player["name"]}#{" (fallen)" unless player["alive"]}" }.join(", ")}" if game["multiplayer"]
      end

      def usable_hint(game)
        " (or use ITEM)" if game["character"]["items"].any? { |item| item["usable"] }
      end

      def next_step(command)
        say "\nNext: bin/rokapi #{command}"
      end

      def current_scene(game)
        game["scenes"].last
      end
  end
end
