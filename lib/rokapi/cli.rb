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
      client.patch "/locale", locale: locale
      say "New games will be played in #{locale}."
    end

    desc "quests", "List quests, tones and lengths"
    def quests
      catalog = fetch("/game_sessions/solo/new.json")

      say "QUESTS (--quest)"
      catalog["quests"].each { |quest| say "  #{quest["key"]} — #{quest["title"]}: #{quest["hook"]}" }
      say "  surprise — the narrator invents one"
      say "TONES (--tone): #{catalog["tones"].map { |tone| tone["key"] }.join(", ")}"
      say "LENGTHS (--length): #{catalog["lengths"].map { |length| "#{length["key"]} (#{length["scenes"]} scenes)" }.join(", ")}"
    end

    desc "new", "Start a solo game"
    option :quest, default: "lost_caravan", desc: "Quest key or surprise"
    option :tone, default: "balanced"
    option :length, default: "medium"
    def new
      response = act(:post, "/game_sessions/solo.json",
        game_session: { quest: options[:quest] == "surprise" ? "" : options[:quest], tone: options[:tone], length: options[:length] })
      client.game_id = response.location[%r{/game_sessions/(\d+)}, 1].to_i

      say "Game #{client.game_id} created."
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
      catalog = character_catalog
      base = catalog["klasses"].find { |candidate| candidate["key"] == klass }&.fetch("base_stats") || raise(Thor::Error, "No such class: #{klass}")

      act :post, "#{game_path}/character.json", character: { race: race, klass: klass, background: background, stats: allocate(base, catalog) }
      settle
    end

    desc "show", "Show where the game stands and what to do next"
    def show
      present game
    end

    desc "story", "Show every scene so far"
    def story
      game = self.game
      return puts(JSON.pretty_generate(game)) if options[:json]

      game["scenes"].each do |scene|
        say_scene game, scene
        say_choice scene
        say_roll scene["roll"] if scene["roll"]&.fetch("resolved")
      end
      say_footer game
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

      def character_catalog
        response = authenticated { client.get("#{game_path}/character/new.json") }
        raise Thor::Error, "This game already has a character. Run: bin/rokapi show" if response.redirect?
        raise Thor::Error, failure(response) unless response.success?

        response.json
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

        if response.redirect? && response.location.to_s.end_with?("/welcome")
          login
          response = yield
        end

        response
      end

      def failure(response)
        case response.status
        when 403 then "It is not your turn."
        when 404 then "Not found. Check the game id or item."
        when 409 then "That does not fit where the game stands. Run: bin/rokapi show"
        when 422 then "Rejected: #{response.body}"
        when 429 then "Rate limited. Wait a few minutes."
        when 300..399 then "Redirected to #{response.location}."
        else "The server answered #{response.status}."
        end
      end

      def allocate(base, catalog)
        stats = base.dup

        if options[:stats]
          options[:stats].split(",").each do |pair|
            stat, value = pair.split("=")
            stats[stat.strip] = value.to_i
          end
        else
          catalog["free_points"].times do
            stat = stats.select { |_, value| value < catalog["stat_cap"] }.max_by { |_, value| value }.first
            stats[stat] += 1
          end
        end

        stats
      end

      def settle(narration: true)
        streamed = {}
        deadline = Time.now + options[:wait]

        loop do
          game = self.game
          stream game, streamed unless options[:json]
          return present(game, streamed: streamed, narration: narration) unless busy?(game)
          raise Thor::Error, "Still waiting after #{options[:wait]}s. Run: bin/rokapi show" if Time.now > deadline

          sleep POLL_INTERVAL
        end
      end

      def busy?(game)
        scene = current_scene(game)
        roll = scene&.fetch("roll")

        return false if game["finished"]
        return true if scene.nil?

        (scene["state"] == "narrating" && !scene["stalled"]) || (roll && !roll["resolved"] && !roll["stalled"])
      end

      def stream(game, streamed)
        scene = current_scene(game) or return
        narration = scene["narration"].to_s
        return if narration.empty?

        unless streamed.key?(scene["position"])
          say_scene_heading game, scene
          streamed[scene["position"]] = 0
        end

        print narration[streamed[scene["position"]]..]
        $stdout.flush
        streamed[scene["position"]] = narration.length
      end

      def present(game, streamed: {}, narration: true)
        return puts(JSON.pretty_generate(game)) if options[:json]

        scene = current_scene(game)
        if scene.nil?
          say "The game has no character yet."
          return next_step("heroes")
        end

        if streamed.key?(scene["position"])
          puts
        elsif narration
          say_scene game, scene
        else
          say_scene_heading game, scene
        end
        say_status game

        roll = scene["roll"]
        case
        when game["finished"]
          say_footer game
          next_step "new"
        when scene["stalled"] || roll&.fetch("stalled")
          say "\nThe narrator stalled."
          next_step "resume"
        when scene["state"] == "narrating"
          say "\nThe narrator is still writing."
          next_step "show"
        when scene["state"] == "choosing"
          say "\nCHOICES"
          scene["choices"].each_with_index do |choice, index|
            say "  #{index + 1}) [#{choice["stat"]} #{format("%+d", choice["modifier"])} | #{choice["difficulty"]}, target #{choice["target"]}] #{choice["label"]} — #{choice["difficulty_reason"]}"
          end
          next_step "choose 1|2|3#{usable_hint(game)}"
        when scene["state"] == "rolling"
          say_choice scene
          next_step "roll#{usable_hint(game)}"
        when roll && !roll["resolved"]
          say "\nThe narrator is resolving the roll."
          next_step "show"
        when roll && !roll["acknowledged"]
          say_choice scene
          say_roll roll
          next_step "continue#{usable_hint(game)}"
        end
      end

      def say_scene_heading(game, scene)
        finale = " (FINALE)" if scene["finale"]
        say "\n=== SCENE #{scene["position"]}/#{game["scene_budget"]} — #{scene["title"] || "…"} @ #{scene["location"] || "…"}#{finale}"
      end

      def say_scene(game, scene)
        say_scene_heading game, scene
        say scene["narration"].to_s
      end

      def say_status(game)
        character = game["character"]
        items = character["items"].map { |item| item["usable"] ? "#{item["summary"]} [use #{item["id"]}]" : item["summary"] }
        statuses = character["statuses"].map { |status| status["summary"] }

        say "\nHP #{character["hp"]}/#{character["max_hp"]} | ITEMS: #{items.join("; ").then { it.empty? ? "none" : it }} | STATUSES: #{statuses.join("; ").then { it.empty? ? "none" : it }}"
      end

      def say_choice(scene)
        choice = scene["choices"].find { |candidate| candidate["chosen"] } or return
        say "\n>>> CHOICE: #{choice["label"]} [#{choice["stat"]} #{format("%+d", choice["modifier"])} | #{choice["difficulty"]}, target #{choice["target"]}]"
      end

      def say_roll(roll)
        status = " #{format("%+d", roll["status_modifier"])} status" unless roll["status_modifier"].zero?
        say "ROLL: d20=#{roll["value"]} #{format("%+d", roll["modifier"])}#{status} = #{roll["total"]} vs #{roll["target"]} → #{roll["grade"].upcase}"
        say "RESULT: #{roll["resolution"]}"

        effects = roll["effects"].to_h.reject { |_, value| value.nil? || value == 0 || value == [] }
        say "EFFECTS: #{effects.to_json}" if effects.any?
      end

      def say_footer(game)
        return unless game["finished"]

        say "\n*** GAME OVER: #{game["outcome"].to_s.upcase} *** cost $#{format("%.3f", game["cost_in_microdollars"] / 1e6)}"
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
