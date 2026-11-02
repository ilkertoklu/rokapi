Pay.setup do |config|
  config.enabled_processors = [ :purchasekit ]
  config.automount_routes = false
  config.send_emails = false
end
