if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
  Rack::MiniProfiler.config.html_container = "html"
  Rack::MiniProfiler.config.skip_paths.push "/cable", "/hotwire-spark", /\.(json|png|svg)\z/
  Rack::MiniProfiler.config.pre_authorize_cb = ->(env) { !env["HTTP_USER_AGENT"].to_s.match?(/(Turbo|Hotwire) Native/) }
end
