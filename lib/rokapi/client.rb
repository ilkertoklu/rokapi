require "net/http"
require "json"
require "fileutils"
require "cgi"
require "mail"

module Rokapi
  class Client
    class Error < StandardError; end

    ROOT = File.expand_path("../..", __dir__)
    MAIL_WAIT = 15

    Response = Data.define(:status, :location, :content_type, :body) do
      def success? = status.between?(200, 299)
      def redirect? = status.between?(300, 399)
      def json? = content_type.to_s.start_with?("application/json")
      def json = JSON.parse(body)
    end

    attr_reader :email

    def initialize(url:, email:)
      @url = URI(url)
      @email = email
      @state_path = File.join(ROOT, "tmp/rokapi/#{email}.json")
      @state = File.exist?(@state_path) ? JSON.parse(File.read(@state_path)) : {}
    end

    def logged_in?
      cookies.key?("session_id")
    end

    def login(name:, code: nil)
      cookies.clear
      fetch_csrf_token "/login_codes/new"

      unless code
        clear_mail email
        request_login_code
        code = read_mail(email, /\b\d{6}\b/) || raise(Error, "No login code arrived in #{mailbox(email)}. Read it from the mail and run: bin/rokapi login --code CODE")
      end

      response = post("/session", code: code)
      raise Error, "The login code was not accepted." if response.location.to_s.end_with?("/session/new") || !logged_in?

      post "/signup/profile", name: name, terms: "1" if response.location.to_s.include?("/signup/profile")
      fetch_csrf_token "/"
    end

    def clear_mail(address)
      FileUtils.rm_f mailbox(address)
    end

    def game_id
      @state["game"]
    end

    def game_id=(id)
      @state["game"] = id
      save
    end

    def get(path)
      request Net::HTTP::Get, path
    end

    def post(path, params = {})
      request Net::HTTP::Post, path, params
    end

    def patch(path, params = {})
      request Net::HTTP::Patch, path, params
    end

    private
      def cookies
        @state["cookies"] ||= {}
      end

      def request(verb, path, params = nil, retried: false)
        request = verb.new(URI.join(@url, path))
        request["User-Agent"] = "rokapi-cli"
        request["Cookie"] = cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
        request["Accept"] = json?(path) ? "application/json" : "text/html"

        if params
          request["X-CSRF-Token"] = @state["csrf_token"] || fetch_csrf_token("/")
          if json?(path)
            request["Content-Type"] = "application/json"
            request.body = params.to_json
          else
            request.set_form_data params
          end
        end

        response = deliver(request)

        if response.status == 422 && !response.json?
          raise Error, "The server rejected the CSRF token." if retried

          fetch_csrf_token "/"
          request(verb, path, params, retried: true)
        else
          response
        end
      end

      def deliver(request)
        http = Net::HTTP.new(@url.host, @url.port)
        http.use_ssl = @url.scheme == "https"
        http.read_timeout = 60

        raw = http.request(request)
        remember_cookies raw.get_fields("Set-Cookie").to_a
        Response.new(status: raw.code.to_i, location: raw["Location"], content_type: raw["Content-Type"], body: raw.body.to_s)
      rescue Errno::ECONNREFUSED
        raise Error, "No server at #{@url}. Start it with bin/dev."
      end

      def remember_cookies(headers)
        headers.each do |header|
          name, value = header.split(";").first.split("=", 2)

          if value.to_s.empty? || header.match?(/max-age=0|expires=Thu, 01 Jan 1970/i)
            cookies.delete name
          else
            cookies[name] = value
          end
        end
        save
      end

      def fetch_csrf_token(path)
        5.times do
          response = get(path)
          if response.redirect?
            path = URI(response.location).path
          else
            @state["csrf_token"] = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1]
            save
            return @state["csrf_token"]
          end
        end

        raise Error, "Could not find a CSRF token at #{path}."
      end

      def request_login_code
        response = post("/login_codes", email: email)
        return if response.location.to_s.end_with?("/session/new")

        alert = get(URI(response.location.to_s).path).body[/class="flash flash--alert">([^<]+)</, 1]&.then { CGI.unescapeHTML(it) }
        raise Error, "No login code was sent: #{alert || "the server refused."}"
      end

      def mailbox(address)
        File.join(ROOT, "tmp/mails", address)
      end

      def read_mail(address, pattern)
        MAIL_WAIT.times do
          found = File.exist?(mailbox(address)) && Mail.read(mailbox(address)).text_part&.decoded.to_s[pattern]
          return found if found

          sleep 1
        end
        nil
      end

      def json?(path)
        path.end_with?(".json")
      end

      def save
        FileUtils.mkdir_p File.dirname(@state_path)
        File.write @state_path, JSON.pretty_generate(@state)
      end
  end
end
